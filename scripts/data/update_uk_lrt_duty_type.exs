#!/usr/bin/env elixir

# Update UK LRT duty_type column from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/data/update_uk_lrt_duty_type.exs [csv_path] [--limit N] [--dry-run]
#
# Converts duty_type from CSV text to JSONB {"values": [...]} format

require Logger

NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtDutyTypeUpdater do
  @moduledoc """
  Updates UK LRT duty_type column from Airtable CSV export.
  Stores as JSONB {"values": ["Duty", "Right", ...]} format.
  """

  @batch_size 100
  @progress_interval 500

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT duty_type Update from Airtable CSV")
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
    {name_idx, duty_type_idx} = read_headers(csv_path)
    IO.puts("  Found Name at column #{name_idx}, duty_type at column #{duty_type_idx}\n")

    # Count total records
    IO.puts("  Counting CSV records...")
    total_csv = count_csv_records(csv_path)
    IO.puts("  CSV total records: #{total_csv}")

    records_to_process =
      case limit do
        :all -> total_csv
        n when is_integer(n) -> min(n, total_csv)
      end

    IO.puts("  Processing #{records_to_process} records...\n")

    # Process updates
    start_time = System.monotonic_time(:millisecond)

    result =
      csv_path
      |> File.stream!()
      |> AirtableCSV.parse_stream(skip_headers: true)
      |> Stream.take(records_to_process)
      |> Stream.with_index(1)
      |> Stream.chunk_every(@batch_size)
      |> Enum.reduce(
        %{updated: 0, skipped: 0, not_found: 0, no_data: 0, errors: [], samples: []},
        fn batch, acc ->
          process_batch(batch, name_to_id, name_idx, duty_type_idx, dry_run, acc)
        end
      )

    end_time = System.monotonic_time(:millisecond)
    duration_sec = (end_time - start_time) / 1000

    print_summary(result, duration_sec, dry_run)
  end

  defp read_headers(csv_path) do
    headers =
      csv_path
      |> File.stream!()
      |> Enum.take(1)
      |> hd()
      |> AirtableCSV.parse_string(skip_headers: false)
      |> hd()
      |> Enum.map(fn h ->
        h |> String.replace("\uFEFF", "") |> String.trim()
      end)

    name_idx = Enum.find_index(headers, &(&1 == "Name"))
    duty_type_idx = Enum.find_index(headers, &(&1 == "duty_type"))

    unless name_idx do
      IO.puts("  ✗ Name column not found in CSV")
      System.halt(1)
    end

    unless duty_type_idx do
      IO.puts("  ✗ duty_type column not found in CSV")
      System.halt(1)
    end

    {name_idx, duty_type_idx}
  end

  defp load_name_to_id_map do
    import Ecto.Query

    SertantaiLegal.Repo.all(
      from(u in "uk_lrt",
        where: not is_nil(u.name),
        select: {u.name, u.id}
      )
    )
    |> Map.new()
  end

  defp count_csv_records(csv_path) do
    csv_path
    |> File.stream!()
    |> AirtableCSV.parse_stream(skip_headers: true)
    |> Enum.count()
  end

  defp get_field(row, idx) when is_list(row) and is_integer(idx) do
    case Enum.at(row, idx) do
      nil -> nil
      "" -> nil
      v -> String.trim(v)
    end
  end

  defp process_batch(batch, name_to_id, name_idx, duty_type_idx, dry_run, acc) do
    {_, last_index} = List.last(batch)

    if rem(last_index, @progress_interval) == 0 or last_index <= @batch_size do
      IO.write("\r  Processed: #{last_index} records...")
    end

    Enum.reduce(batch, acc, fn {row, _index}, acc ->
      process_row(row, name_to_id, name_idx, duty_type_idx, dry_run, acc)
    end)
  end

  defp process_row(row, name_to_id, name_idx, duty_type_idx, dry_run, acc) do
    name = get_field(row, name_idx)
    raw_duty_type = get_field(row, duty_type_idx)

    cond do
      is_nil(name) ->
        %{acc | skipped: acc.skipped + 1}

      not Map.has_key?(name_to_id, name) ->
        %{acc | not_found: acc.not_found + 1}

      is_nil(raw_duty_type) ->
        %{acc | no_data: acc.no_data + 1}

      true ->
        id = Map.get(name_to_id, name)
        parsed = parse_duty_type(raw_duty_type)

        # Collect samples for verification
        samples =
          if length(acc.samples) < 5 do
            [{name, raw_duty_type, parsed} | acc.samples]
          else
            acc.samples
          end

        if dry_run do
          %{acc | updated: acc.updated + 1, samples: samples}
        else
          case update_record(id, parsed) do
            :ok ->
              %{acc | updated: acc.updated + 1, samples: samples}

            {:error, reason} ->
              %{acc | errors: [{name, reason} | acc.errors], samples: samples}
          end
        end
    end
  end

  defp parse_duty_type(raw) do
    # Parse CSV values respecting quoted strings
    # "Interpretation, Definition",Amendment becomes ["Interpretation, Definition", "Amendment"]
    values = parse_csv_values(raw)

    case values do
      [] -> nil
      arr -> %{"values" => arr}
    end
  end

  # Parse CSV values respecting quoted strings
  defp parse_csv_values(str) do
    # Use regex to match either quoted or unquoted values
    ~r/"([^"]*(?:""[^"]*)*)"|([^,]+)/
    |> Regex.scan(str)
    |> Enum.map(fn
      [_, quoted, ""] ->
        quoted
        |> String.trim()
        # Handle escaped quotes
        |> String.replace("\"\"", "\"")

      [_, "", unquoted] ->
        String.trim(unquoted)

      [_, quoted] when quoted != "" ->
        quoted
        |> String.trim()
        |> String.replace("\"\"", "\"")

      _ ->
        nil
    end)
    |> Enum.filter(&(&1 != nil and &1 != ""))
  end

  defp update_record(id, duty_type) do
    import Ecto.Query

    query =
      from(u in "uk_lrt",
        where: u.id == ^id,
        update: [set: [duty_type: ^duty_type]]
      )

    case SertantaiLegal.Repo.update_all(query, []) do
      {1, _} -> :ok
      {0, _} -> {:error, "Record not found during update"}
      error -> {:error, inspect(error)}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp print_summary(result, duration_sec, dry_run) do
    IO.puts("\n\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if dry_run do
      IO.puts("  DRY RUN Complete (no changes made)")
    else
      IO.puts("  Update Complete!")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Updated:      #{result.updated}")
    IO.puts("  No data:      #{result.no_data} (no duty_type)")
    IO.puts("  Skipped:      #{result.skipped} (missing name)")
    IO.puts("  Not found:    #{result.not_found} (not in database)")
    IO.puts("  Errors:       #{length(result.errors)}")
    IO.puts("  Duration:     #{Float.round(duration_sec, 1)}s")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Show sample conversions
    if length(result.samples) > 0 do
      IO.puts("\n  Sample conversions:")

      Enum.each(Enum.reverse(result.samples), fn {name, raw, parsed} ->
        IO.puts("    #{name}:")
        IO.puts("      Raw:    #{String.slice(raw, 0, 80)}")
        IO.puts("      Parsed: #{inspect(parsed)}")
      end)
    end

    if length(result.errors) > 0 do
      IO.puts("\n  Sample errors (first 5):")

      Enum.each(Enum.take(result.errors, 5), fn {name, reason} ->
        IO.puts("    #{name}: #{String.slice(inspect(reason), 0, 200)}")
      end)
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
        IO.puts(
          "Usage: mix run ../scripts/data/update_uk_lrt_duty_type.exs <csv_path> [--limit N] [--dry-run]"
        )

        System.halt(1)
      end
  end

# Build options
update_opts = [
  limit: Keyword.get(opts, :limit, :all),
  dry_run: Keyword.get(opts, :dry_run, false)
]

# Run the updater
UkLrtDutyTypeUpdater.run(csv_path, update_opts)
