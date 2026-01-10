#!/usr/bin/env elixir

# Update UK LRT md_modified column from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/data/update_uk_lrt_md_modified.exs [csv_path] [--limit N] [--dry-run]
#
# Examples:
#   mix run ../scripts/data/update_uk_lrt_md_modified.exs ~/Documents/sertantai_data/UK-EXPORT.csv
#   mix run ../scripts/data/update_uk_lrt_md_modified.exs ~/Documents/sertantai_data/UK-EXPORT.csv --limit 100
#   mix run ../scripts/data/update_uk_lrt_md_modified.exs ~/Documents/sertantai_data/UK-EXPORT.csv --dry-run

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtMdModifiedUpdater do
  @moduledoc """
  Updates UK LRT md_modified column from Airtable CSV export.
  """

  @batch_size 100
  @progress_interval 500

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT md_modified Update from Airtable CSV")
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
    {_headers, name_idx, md_modified_idx} = read_headers(csv_path)
    IO.puts("  Name column index: #{name_idx}")
    IO.puts("  md_modified column index: #{md_modified_idx}\n")

    IO.puts("  Scanning CSV for records with md_modified data...\n")

    # Count records with md_modified data
    {total_csv, with_md_modified} = count_csv_records(csv_path, md_modified_idx)
    IO.puts("  CSV total records: #{total_csv}")
    IO.puts("  Records with md_modified: #{with_md_modified}")

    records_to_process =
      case limit do
        :all -> with_md_modified
        n when is_integer(n) -> min(n, with_md_modified)
      end

    IO.puts("  Processing #{records_to_process} records...\n")

    # Process updates
    stats = process_updates(csv_path, name_idx, md_modified_idx, name_to_id, limit, dry_run)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Results")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  ✓ Updated: #{stats.updated}")
    IO.puts("  ○ Skipped (empty): #{stats.skipped}")
    IO.puts("  ○ Not in DB: #{stats.not_found}")
    IO.puts("  ✗ Errors: #{stats.errors}")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
  end

  defp load_name_to_id_map do
    alias SertantaiLegal.Legal.UkLrt
    require Ash.Query

    {:ok, records} = UkLrt |> Ash.Query.select([:id, :name]) |> Ash.read()

    records
    |> Enum.map(fn r -> {r.name, r.id} end)
    |> Map.new()
  end

  defp read_headers(csv_path) do
    [headers | _] =
      csv_path
      |> File.stream!([:trim_bom])
      |> Stream.take(1)
      |> AirtableCSV.parse_stream(skip_headers: false)
      |> Enum.to_list()

    # Also strip any remaining BOM or whitespace from first header
    headers =
      case headers do
        [first | rest] -> [String.trim(first, "\uFEFF") | rest]
        other -> other
      end

    name_idx = Enum.find_index(headers, &(&1 == "Name"))
    md_modified_idx = Enum.find_index(headers, &(&1 == "md_modified"))

    if is_nil(name_idx) or is_nil(md_modified_idx) do
      IO.puts("  ✗ Could not find required columns (Name, md_modified)")
      System.halt(1)
    end

    {headers, name_idx, md_modified_idx}
  end

  defp count_csv_records(csv_path, md_modified_idx) do
    csv_path
    |> File.stream!([:trim_bom])
    |> AirtableCSV.parse_stream()
    |> Enum.reduce({0, 0}, fn row, {total, with_data} ->
      md_modified = Enum.at(row, md_modified_idx, "") |> String.trim()
      has_data = md_modified != "" and is_valid_date?(md_modified)
      {total + 1, if(has_data, do: with_data + 1, else: with_data)}
    end)
  end

  defp is_valid_date?(str) do
    # Check if it looks like a date (YYYY-MM-DD format)
    Regex.match?(~r/^\d{4}-\d{2}-\d{2}$/, str)
  end

  defp process_updates(csv_path, name_idx, md_modified_idx, name_to_id, limit, dry_run) do
    alias SertantaiLegal.Legal.UkLrt
    require Ash.Query

    initial_stats = %{updated: 0, skipped: 0, not_found: 0, errors: 0, processed: 0}

    csv_path
    |> File.stream!([:trim_bom])
    |> AirtableCSV.parse_stream()
    |> Stream.take(if limit == :all, do: 999_999_999, else: limit)
    |> Enum.reduce(initial_stats, fn row, stats ->
      name = Enum.at(row, name_idx, "") |> String.trim()
      md_modified_str = Enum.at(row, md_modified_idx, "") |> String.trim()

      stats = %{stats | processed: stats.processed + 1}

      # Progress indicator
      if rem(stats.processed, @progress_interval) == 0 do
        IO.puts("  Processed #{stats.processed} rows, updated #{stats.updated}...")
      end

      cond do
        name == "" or md_modified_str == "" ->
          %{stats | skipped: stats.skipped + 1}

        not is_valid_date?(md_modified_str) ->
          %{stats | skipped: stats.skipped + 1}

        true ->
          case Map.get(name_to_id, name) do
            nil ->
              %{stats | not_found: stats.not_found + 1}

            record_id ->
              if dry_run do
                %{stats | updated: stats.updated + 1}
              else
                case parse_and_update(record_id, md_modified_str) do
                  :ok -> %{stats | updated: stats.updated + 1}
                  :error -> %{stats | errors: stats.errors + 1}
                end
              end
          end
      end
    end)
  end

  defp parse_and_update(record_id, md_modified_str) do
    alias SertantaiLegal.Legal.UkLrt
    require Ash.Query

    case Date.from_iso8601(md_modified_str) do
      {:ok, date} ->
        case UkLrt |> Ash.Query.filter(id == ^record_id) |> Ash.read() do
          {:ok, [record]} ->
            case Ash.update(record, %{md_modified: date}, action: :update) do
              {:ok, _} -> :ok
              {:error, _} -> :error
            end

          _ ->
            :error
        end

      {:error, _} ->
        :error
    end
  end
end

# Parse command line args
{opts, args, _} = OptionParser.parse(System.argv(), strict: [limit: :integer, dry_run: :boolean])

csv_path =
  case args do
    [path | _] ->
      path

    [] ->
      IO.puts(
        "Usage: mix run ../scripts/data/update_uk_lrt_md_modified.exs <csv_path> [--limit N] [--dry-run]"
      )

      System.halt(1)
  end

UkLrtMdModifiedUpdater.run(csv_path, opts)
