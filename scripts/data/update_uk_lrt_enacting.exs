#!/usr/bin/env elixir

# Update UK LRT enacted_by and enacting columns from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/data/update_uk_lrt_enacting.exs [csv_path] [--limit N] [--dry-run]
#
# Examples:
#   mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv
#   mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100
#   mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run
#
# This script updates enacting-related columns in uk_lrt from the Airtable CSV export.
#
# Columns imported:
#   - Enacted_by → enacted_by (array: parent enabling laws)
#   - Enacting (from LRT) → enacting (array: child laws this enables)
#
# Note:
#   - enacted_by: Secondary law → Parent Acts (e.g., SI enacted by an Act)
#   - enacting: Parent law → Child laws (e.g., Act enables multiple SIs)
#   - is_enacting flag set when enacting array is populated

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtEnactingUpdater do
  @moduledoc """
  Updates UK LRT enacted_by and enacting columns from Airtable CSV export.
  """

  @batch_size 100
  @progress_interval 500

  # Column mappings: {csv_column_name, db_column_name, type}
  @column_mappings [
    {"Enacted_by", :enacted_by, :array},
    {"Enacting (from LRT)", :enacting, :array}
  ]

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT Enacting Data Import from Airtable CSV")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  File: #{csv_path}")
    IO.puts("  Limit: #{if limit == :all, do: "No limit", else: limit}")
    IO.puts("  Mode: #{if dry_run, do: "DRY RUN (no changes)", else: "LIVE"}")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

    unless File.exists?(csv_path) do
      IO.puts("  ✗ File not found: #{csv_path}")
      System.halt(1)
    end

    # Pre-load all uk_lrt names to IDs for fast lookup
    IO.puts("  Loading UK LRT records from database...")
    name_to_id = load_name_to_id_map()
    IO.puts("  Found #{map_size(name_to_id)} records in database\n")

    # Read headers and find column indices
    IO.puts("  Reading CSV headers...")
    {headers, name_idx, column_indices} = read_headers(csv_path)
    IO.puts("  Name column index: #{name_idx}")
    IO.puts("  Found #{map_size(column_indices)} enacting columns\n")

    # Show which columns were found
    IO.puts("  Column mappings:")
    Enum.each(@column_mappings, fn {csv_col, db_col, _type} ->
      case Map.get(column_indices, csv_col) do
        nil -> IO.puts("    ✗ #{csv_col} (not found in CSV)")
        idx -> IO.puts("    ✓ #{csv_col} [#{idx}] → #{db_col}")
      end
    end)
    IO.puts("")

    IO.puts("  Scanning CSV for records with enacting data...\n")

    # Count records with any enacting data
    {total_csv, with_enact_data} = count_csv_records(csv_path, column_indices)
    IO.puts("  CSV total records: #{total_csv}")
    IO.puts("  Records with enacting data: #{with_enact_data}")

    records_to_process =
      case limit do
        :all -> with_enact_data
        n when is_integer(n) -> min(n, with_enact_data)
      end

    IO.puts("  Processing #{records_to_process} records...\n")

    # Process updates
    start_time = System.monotonic_time(:millisecond)

    result =
      csv_path
      |> File.stream!()
      |> AirtableCSV.parse_stream(skip_headers: true)
      |> Stream.filter(fn row -> has_enact_data?(row, column_indices) end)
      |> Stream.take(records_to_process)
      |> Stream.with_index(1)
      |> Stream.chunk_every(@batch_size)
      |> Enum.reduce(
        %{updated: 0, skipped: 0, not_found: 0, errors: [], enacted_by_count: 0, enacting_count: 0},
        fn batch, acc ->
          process_batch(batch, name_to_id, name_idx, column_indices, dry_run, acc)
        end
      )

    end_time = System.monotonic_time(:millisecond)
    duration_sec = (end_time - start_time) / 1000

    print_summary(result, duration_sec, dry_run)
  end

  defp read_headers(csv_path) do
    # Read first line to get headers
    headers =
      csv_path
      |> File.stream!()
      |> Enum.take(1)
      |> hd()
      |> AirtableCSV.parse_string(skip_headers: false)
      |> hd()
      |> Enum.map(fn h ->
        # Remove BOM if present
        h |> String.replace("\uFEFF", "") |> String.trim()
      end)

    name_idx = Enum.find_index(headers, &(&1 == "Name"))

    unless name_idx do
      IO.puts("  ✗ Name column not found in CSV")
      System.halt(1)
    end

    # Find indices for all enacting columns
    column_indices =
      @column_mappings
      |> Enum.map(fn {csv_col, _db_col, _type} ->
        {csv_col, Enum.find_index(headers, &(&1 == csv_col))}
      end)
      |> Enum.filter(fn {_csv_col, idx} -> idx != nil end)
      |> Map.new()

    {headers, name_idx, column_indices}
  end

  defp load_name_to_id_map do
    import Ecto.Query

    SertantaiLegal.Repo.all(
      from u in "uk_lrt",
        where: not is_nil(u.name),
        select: {u.name, u.id}
    )
    |> Map.new()
  end

  defp count_csv_records(csv_path, column_indices) do
    csv_path
    |> File.stream!()
    |> AirtableCSV.parse_stream(skip_headers: true)
    |> Enum.reduce({0, 0}, fn row, {total, with_data} ->
      has_data = has_enact_data?(row, column_indices)
      {total + 1, if(has_data, do: with_data + 1, else: with_data)}
    end)
  end

  defp has_enact_data?(row, column_indices) do
    # Check if any of the enacting columns have data
    Enum.any?(column_indices, fn {_csv_col, idx} ->
      val = get_field(row, idx)
      val != nil and val != ""
    end)
  end

  defp get_field(row, idx) when is_list(row) and is_integer(idx) do
    case Enum.at(row, idx) do
      nil -> nil
      "" -> nil
      v -> String.trim(v)
    end
  end

  defp get_field(_, _), do: nil

  defp process_batch(batch, name_to_id, name_idx, column_indices, dry_run, acc) do
    # Show progress
    {_, last_index} = List.last(batch)
    if rem(last_index, @progress_interval) == 0 or last_index <= @batch_size do
      IO.write("\r  Processed: #{last_index} records...")
    end

    Enum.reduce(batch, acc, fn {row, _index}, acc ->
      process_row(row, name_to_id, name_idx, column_indices, dry_run, acc)
    end)
  end

  defp process_row(row, name_to_id, name_idx, column_indices, dry_run, acc) do
    name = get_field(row, name_idx)

    cond do
      is_nil(name) ->
        %{acc | skipped: acc.skipped + 1}

      not Map.has_key?(name_to_id, name) ->
        %{acc | not_found: acc.not_found + 1}

      true ->
        id = Map.get(name_to_id, name)
        {updates, has_enacted_by, has_enacting} = build_updates(row, column_indices)

        if map_size(updates) == 0 do
          %{acc | skipped: acc.skipped + 1}
        else
          if dry_run do
            acc
            |> Map.update!(:updated, &(&1 + 1))
            |> Map.update!(:enacted_by_count, &(&1 + if(has_enacted_by, do: 1, else: 0)))
            |> Map.update!(:enacting_count, &(&1 + if(has_enacting, do: 1, else: 0)))
          else
            case update_record(id, updates, has_enacting) do
              :ok ->
                acc
                |> Map.update!(:updated, &(&1 + 1))
                |> Map.update!(:enacted_by_count, &(&1 + if(has_enacted_by, do: 1, else: 0)))
                |> Map.update!(:enacting_count, &(&1 + if(has_enacting, do: 1, else: 0)))

              {:error, reason} ->
                %{acc | errors: [{name, reason} | acc.errors]}
            end
          end
        end
    end
  end

  defp build_updates(row, column_indices) do
    {updates, has_enacted_by, has_enacting} =
      @column_mappings
      |> Enum.reduce({%{}, false, false}, fn {csv_col, db_col, type}, {acc, enacted_by, enacting} ->
        case Map.get(column_indices, csv_col) do
          nil ->
            {acc, enacted_by, enacting}

          idx ->
            raw_value = get_field(row, idx)

            case parse_value(raw_value, type) do
              nil ->
                {acc, enacted_by, enacting}

              value ->
                new_acc = Map.put(acc, db_col, value)
                # Track which fields we're updating
                new_enacted_by = enacted_by or db_col == :enacted_by
                new_enacting = enacting or db_col == :enacting
                {new_acc, new_enacted_by, new_enacting}
            end
        end
      end)

    {updates, has_enacted_by, has_enacting}
  end

  defp parse_value(nil, _type), do: nil
  defp parse_value("", _type), do: nil

  defp parse_value(value, :array) do
    # Parse comma-separated list into array
    # Handle Airtable format: "UK_uksi_2024_123" -> "uksi/2024/123"
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&normalize_law_name/1)
    |> Enum.filter(&(&1 != ""))
    |> case do
      [] -> nil
      list -> list
    end
  end

  # Convert Airtable format to standard format
  # "UK_uksi_2024_123" -> "uksi/2024/123"
  defp normalize_law_name(name) do
    case Regex.run(~r/^UK_([a-z]+)_(\d{4})_(\d+)$/i, name) do
      [_, type, year, number] ->
        "#{String.downcase(type)}/#{year}/#{number}"
      _ ->
        # Already in correct format or unknown format
        name
    end
  end

  defp update_record(id, updates, has_enacting) do
    import Ecto.Query

    # If we're setting enacting, also set is_enacting flag
    updates =
      if has_enacting do
        Map.put(updates, :is_enacting, true)
      else
        updates
      end

    # Build the SET clause dynamically
    set_clause =
      updates
      |> Enum.map(fn {col, val} -> {col, val} end)

    query =
      from u in "uk_lrt",
        where: u.id == ^id,
        update: [set: ^set_clause]

    case SertantaiLegal.Repo.update_all(query, []) do
      {1, _} -> :ok
      {0, _} -> {:error, "Record not found during update"}
      error -> {:error, inspect(error)}
    end
  end

  defp print_summary(result, duration_sec, dry_run) do
    IO.puts("\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if dry_run do
      IO.puts("  DRY RUN Complete (no changes made)")
    else
      IO.puts("  Import Complete!")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Updated:        #{result.updated}")
    IO.puts("    enacted_by:   #{result.enacted_by_count}")
    IO.puts("    enacting:     #{result.enacting_count}")
    IO.puts("  Skipped:        #{result.skipped} (missing name or no data)")
    IO.puts("  Not found:      #{result.not_found} (not in database)")
    IO.puts("  Errors:         #{length(result.errors)}")
    IO.puts("  Duration:       #{Float.round(duration_sec, 1)}s")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if length(result.errors) > 0 and length(result.errors) <= 20 do
      IO.puts("\n  Errors:")

      Enum.each(Enum.take(result.errors, 20), fn {name, reason} ->
        IO.puts("    #{name}: #{reason}")
      end)

      if length(result.errors) > 20 do
        IO.puts("    ... and #{length(result.errors) - 20} more errors")
      end
    end

    IO.puts("")
  end
end

# Parse command line arguments
{opts, args, _} =
  OptionParser.parse(System.argv(),
    strict: [limit: :integer, dry_run: :boolean],
    aliases: [l: :limit, n: :dry_run]
  )

# Get CSV path
csv_path =
  case args do
    [path | _] ->
      Path.expand(path)

    [] ->
      default_path = Path.expand("~/Documents/Airtable_Exports/UK-EXPORT.csv")

      if File.exists?(default_path) do
        default_path
      else
        IO.puts("Usage: mix run ../scripts/data/update_uk_lrt_enacting.exs <csv_path> [--limit N] [--dry-run]")
        IO.puts("\nExamples:")
        IO.puts("  mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv")
        IO.puts("  mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100")
        IO.puts("  mix run ../scripts/data/update_uk_lrt_enacting.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run")
        System.halt(1)
      end
  end

# Build options
update_opts = [
  limit: Keyword.get(opts, :limit, :all),
  dry_run: Keyword.get(opts, :dry_run, false)
]

# Run the updater
UkLrtEnactingUpdater.run(csv_path, update_opts)
