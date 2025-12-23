#!/usr/bin/env elixir

# Update UK LRT amendment columns from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/update_uk_lrt_amending.exs [csv_path] [--limit N] [--dry-run]
#
# Examples:
#   mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv
#   mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100
#   mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run
#
# This script updates amendment-related columns in uk_lrt from the Airtable CSV export.
#
# Columns imported:
#   Array columns (comma-separated in CSV → text[] in DB):
#     - Amending → amending
#     - Amended_by → amended_by
#     - Revoking → rescinding
#     - Revoked_by → rescinded_by
#
#   Stats columns (emoji prefixed):
#     - 🔺_stats_affects_count → 🔺_stats_affects_count
#     - 🔺_stats_self_affects_count → 🔺🔻_stats_self_affects_count (merged)
#     - 🔺_stats_affected_laws_count → 🔺_stats_affected_laws_count
#     - 🔺_stats_affects_count_per_law → 🔺_stats_affects_count_per_law
#     - 🔺_stats_affects_count_per_law_detailed → 🔺_stats_affects_count_per_law_detailed
#     - 🔻_stats_affected_by_count → 🔻_stats_affected_by_count
#     - 🔻_stats_affected_by_laws_count → 🔻_stats_affected_by_laws_count
#     - 🔻_stats_affected_by_count_per_law → 🔻_stats_affected_by_count_per_law
#     - 🔻_stats_affected_by_count_per_law_detailed → 🔻_stats_affected_by_count_per_law_detailed
#     - 🔺_stats_revoking_laws_count → 🔺_stats_rescinding_laws_count
#     - 🔺_stats_revoking_count_per_law → 🔺_stats_rescinding_count_per_law
#     - 🔺_stats_revoking_count_per_law_detailed → 🔺_stats_rescinding_count_per_law_detailed
#     - 🔻_stats_revoked_by_laws_count → 🔻_stats_rescinded_by_laws_count
#     - 🔻_stats_revoked_by_count_per_law → 🔻_stats_rescinded_by_count_per_law
#     - 🔻_stats_revoked_by_count_per_law_detailed → 🔻_stats_rescinded_by_count_per_law_detailed
#
#   Change logs:
#     - amending_change_log → amending_change_log
#     - amended_by_change_log → amended_by_change_log

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtAmendingUpdater do
  @moduledoc """
  Updates UK LRT amendment columns from Airtable CSV export.
  """

  @batch_size 100
  @progress_interval 500

  # Column mappings: {csv_column_name, db_column_name, type}
  # type: :array (comma-separated → text[]), :integer, :text
  @column_mappings [
    # Array columns
    {"Amending", :amending, :array},
    {"Amended_by", :amended_by, :array},
    {"Revoking", :rescinding, :array},
    {"Revoked_by", :rescinded_by, :array},

    # Amending stats
    {"🔺_stats_affects_count", :"🔺_stats_affects_count", :integer},
    {"🔺_stats_self_affects_count", :"🔺🔻_stats_self_affects_count", :integer},
    {"🔺_stats_affected_laws_count", :"🔺_stats_affected_laws_count", :integer},
    {"🔺_stats_affects_count_per_law", :"🔺_stats_affects_count_per_law", :text},
    {"🔺_stats_affects_count_per_law_detailed", :"🔺_stats_affects_count_per_law_detailed", :text},

    # Amended_by stats
    {"🔻_stats_affected_by_count", :"🔻_stats_affected_by_count", :integer},
    {"🔻_stats_affected_by_laws_count", :"🔻_stats_affected_by_laws_count", :integer},
    {"🔻_stats_affected_by_count_per_law", :"🔻_stats_affected_by_count_per_law", :text},
    {"🔻_stats_affected_by_count_per_law_detailed", :"🔻_stats_affected_by_count_per_law_detailed", :text},

    # Rescinding stats (Airtable uses "revoking")
    {"🔺_stats_revoking_laws_count", :"🔺_stats_rescinding_laws_count", :integer},
    {"🔺_stats_revoking_count_per_law", :"🔺_stats_rescinding_count_per_law", :text},
    {"🔺_stats_revoking_count_per_law_detailed", :"🔺_stats_rescinding_count_per_law_detailed", :text},

    # Rescinded_by stats (Airtable uses "revoked_by")
    {"🔻_stats_revoked_by_laws_count", :"🔻_stats_rescinded_by_laws_count", :integer},
    {"🔻_stats_revoked_by_count_per_law", :"🔻_stats_rescinded_by_count_per_law", :text},
    {"🔻_stats_revoked_by_count_per_law_detailed", :"🔻_stats_rescinded_by_count_per_law_detailed", :text},

    # Change logs
    {"amending_change_log", :amending_change_log, :text},
    {"amended_by_change_log", :amended_by_change_log, :text}
  ]

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT Amendment Data Import from Airtable CSV")
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
    IO.puts("  Found #{map_size(column_indices)} amendment columns\n")

    # Show which columns were found
    IO.puts("  Column mappings:")
    Enum.each(@column_mappings, fn {csv_col, db_col, _type} ->
      case Map.get(column_indices, csv_col) do
        nil -> IO.puts("    ✗ #{csv_col} (not found in CSV)")
        idx -> IO.puts("    ✓ #{csv_col} [#{idx}] → #{db_col}")
      end
    end)
    IO.puts("")

    IO.puts("  Scanning CSV for records with amendment data...\n")

    # Count records with any amendment data
    {total_csv, with_amend_data} = count_csv_records(csv_path, column_indices)
    IO.puts("  CSV total records: #{total_csv}")
    IO.puts("  Records with amendment data: #{with_amend_data}")

    records_to_process =
      case limit do
        :all -> with_amend_data
        n when is_integer(n) -> min(n, with_amend_data)
      end

    IO.puts("  Processing #{records_to_process} records...\n")

    # Process updates
    start_time = System.monotonic_time(:millisecond)

    result =
      csv_path
      |> File.stream!()
      |> AirtableCSV.parse_stream(skip_headers: true)
      |> Stream.filter(fn row -> has_amend_data?(row, column_indices) end)
      |> Stream.take(records_to_process)
      |> Stream.with_index(1)
      |> Stream.chunk_every(@batch_size)
      |> Enum.reduce(
        %{updated: 0, skipped: 0, not_found: 0, errors: []},
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

    # Find indices for all amendment columns
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
      has_data = has_amend_data?(row, column_indices)
      {total + 1, if(has_data, do: with_data + 1, else: with_data)}
    end)
  end

  defp has_amend_data?(row, column_indices) do
    # Check if any of the amending columns have data
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
        updates = build_updates(row, column_indices)

        if map_size(updates) == 0 do
          %{acc | skipped: acc.skipped + 1}
        else
          if dry_run do
            %{acc | updated: acc.updated + 1}
          else
            case update_record(id, updates) do
              :ok ->
                %{acc | updated: acc.updated + 1}

              {:error, reason} ->
                %{acc | errors: [{name, reason} | acc.errors]}
            end
          end
        end
    end
  end

  defp build_updates(row, column_indices) do
    @column_mappings
    |> Enum.reduce(%{}, fn {csv_col, db_col, type}, acc ->
      case Map.get(column_indices, csv_col) do
        nil ->
          acc

        idx ->
          raw_value = get_field(row, idx)

          case parse_value(raw_value, type) do
            nil -> acc
            value -> Map.put(acc, db_col, value)
          end
      end
    end)
  end

  defp parse_value(nil, _type), do: nil
  defp parse_value("", _type), do: nil

  defp parse_value(value, :array) do
    # Parse comma-separated list into array
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> case do
      [] -> nil
      list -> list
    end
  end

  defp parse_value(value, :integer) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_value(value, :text), do: value

  defp update_record(id, updates) do
    import Ecto.Query

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
    IO.puts("  Updated:      #{result.updated}")
    IO.puts("  Skipped:      #{result.skipped} (missing name or no data)")
    IO.puts("  Not found:    #{result.not_found} (not in database)")
    IO.puts("  Errors:       #{length(result.errors)}")
    IO.puts("  Duration:     #{Float.round(duration_sec, 1)}s")
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
        IO.puts("Usage: mix run ../scripts/update_uk_lrt_amending.exs <csv_path> [--limit N] [--dry-run]")
        IO.puts("\nExamples:")
        IO.puts("  mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv")
        IO.puts("  mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100")
        IO.puts("  mix run ../scripts/update_uk_lrt_amending.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run")
        System.halt(1)
      end
  end

# Build options
update_opts = [
  limit: Keyword.get(opts, :limit, :all),
  dry_run: Keyword.get(opts, :dry_run, false)
]

# Run the updater
UkLrtAmendingUpdater.run(csv_path, update_opts)
