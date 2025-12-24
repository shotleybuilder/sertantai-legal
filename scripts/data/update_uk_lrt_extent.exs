#!/usr/bin/env elixir

# Update UK LRT extent columns from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/update_uk_lrt_extent.exs [csv_path] [--limit N] [--dry-run]
#
# Examples:
#   mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv
#   mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100
#   mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run
#
# This script updates extent columns in uk_lrt from the Airtable CSV export:
#
# CSV Column          -> DB Column
# -----------------   -----------
# Geo_Pan_Region      -> geo_extent (e.g., "UK", "GB", "E+W")
# Geo_Region          -> geo_region (e.g., "England, Wales, Scotland")
# Geo_Extent          -> geo_detail (section-by-section breakdown with emoji flags)
# md_restrict_extent  -> md_restrict_extent

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtExtentUpdater do
  @moduledoc """
  Updates UK LRT extent columns from Airtable CSV export.
  """

  @batch_size 100
  @progress_interval 500

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT Extent Update from Airtable CSV")
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
    column_indices = read_headers(csv_path)
    IO.puts("  Name column index: #{column_indices.name}")
    IO.puts("  Geo_Pan_Region column index: #{column_indices.geo_pan_region}")
    IO.puts("  Geo_Region column index: #{column_indices.geo_region}")
    IO.puts("  Geo_Extent column index: #{column_indices.geo_extent}")
    IO.puts("  md_restrict_extent column index: #{column_indices.md_restrict_extent}\n")

    IO.puts("  Scanning CSV for records with extent data...\n")

    # Count records with extent data
    {total_csv, with_extent} = count_csv_records(csv_path, column_indices)
    IO.puts("  CSV total records: #{total_csv}")
    IO.puts("  Records with any extent data: #{with_extent}")

    records_to_process =
      case limit do
        :all -> with_extent
        n when is_integer(n) -> min(n, with_extent)
      end

    IO.puts("  Processing #{records_to_process} records...\n")

    # Process updates
    start_time = System.monotonic_time(:millisecond)

    result =
      csv_path
      |> File.stream!()
      |> AirtableCSV.parse_stream(skip_headers: true)
      |> Stream.filter(fn row -> has_extent_data?(row, column_indices) end)
      |> Stream.take(records_to_process)
      |> Stream.with_index(1)
      |> Stream.chunk_every(@batch_size)
      |> Enum.reduce(
        %{updated: 0, skipped: 0, not_found: 0, errors: []},
        fn batch, acc ->
          process_batch(batch, name_to_id, column_indices, dry_run, acc)
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
    geo_pan_region_idx = Enum.find_index(headers, &(&1 == "Geo_Pan_Region"))
    geo_region_idx = Enum.find_index(headers, &(&1 == "Geo_Region"))
    geo_extent_idx = Enum.find_index(headers, &(&1 == "Geo_Extent"))
    md_restrict_extent_idx = Enum.find_index(headers, &(&1 == "md_restrict_extent"))

    unless name_idx do
      IO.puts("  ✗ Name column not found in CSV")
      System.halt(1)
    end

    %{
      name: name_idx,
      geo_pan_region: geo_pan_region_idx,
      geo_region: geo_region_idx,
      geo_extent: geo_extent_idx,
      md_restrict_extent: md_restrict_extent_idx
    }
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
    |> Enum.reduce({0, 0}, fn row, {total, with_extent} ->
      has_data = has_extent_data?(row, column_indices)
      {total + 1, if(has_data, do: with_extent + 1, else: with_extent)}
    end)
  end

  defp has_extent_data?(row, indices) do
    has_value?(row, indices.geo_pan_region) or
      has_value?(row, indices.geo_region) or
      has_value?(row, indices.geo_extent) or
      has_value?(row, indices.md_restrict_extent)
  end

  defp has_value?(_row, nil), do: false
  defp has_value?(row, idx) do
    val = get_field(row, idx)
    val != nil and val != ""
  end

  defp get_field(_row, nil), do: nil
  defp get_field(row, idx) when is_list(row) and is_integer(idx) do
    case Enum.at(row, idx) do
      nil -> nil
      "" -> nil
      v -> String.trim(v)
    end
  end

  defp process_batch(batch, name_to_id, column_indices, dry_run, acc) do
    # Show progress
    {_, last_index} = List.last(batch)
    if rem(last_index, @progress_interval) == 0 or last_index <= @batch_size do
      IO.write("\r  Processed: #{last_index} records...")
    end

    Enum.reduce(batch, acc, fn {row, _index}, acc ->
      process_row(row, name_to_id, column_indices, dry_run, acc)
    end)
  end

  defp process_row(row, name_to_id, indices, dry_run, acc) do
    name = get_field(row, indices.name)

    cond do
      is_nil(name) ->
        %{acc | skipped: acc.skipped + 1}

      not Map.has_key?(name_to_id, name) ->
        %{acc | not_found: acc.not_found + 1}

      true ->
        id = Map.get(name_to_id, name)

        # Get extent values from CSV
        geo_extent = get_field(row, indices.geo_pan_region)  # Geo_Pan_Region -> geo_extent
        geo_region = get_field(row, indices.geo_region)       # Geo_Region -> geo_region
        geo_detail = get_field(row, indices.geo_extent)       # Geo_Extent -> geo_detail
        md_restrict_extent = get_field(row, indices.md_restrict_extent)

        if dry_run do
          %{acc | updated: acc.updated + 1}
        else
          case update_record(id, geo_extent, geo_region, geo_detail, md_restrict_extent) do
            :ok ->
              %{acc | updated: acc.updated + 1}

            {:error, reason} ->
              %{acc | errors: [{name, reason} | acc.errors]}
          end
        end
    end
  end

  defp update_record(id, geo_extent, geo_region, geo_detail, md_restrict_extent) do
    import Ecto.Query

    query =
      from u in "uk_lrt",
        where: u.id == ^id,
        update: [
          set: [
            geo_extent: ^geo_extent,
            geo_region: ^geo_region,
            geo_detail: ^geo_detail,
            md_restrict_extent: ^md_restrict_extent
          ]
        ]

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
      IO.puts("  Update Complete!")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Updated:      #{result.updated}")
    IO.puts("  Skipped:      #{result.skipped} (missing name)")
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
        IO.puts("Usage: mix run ../scripts/update_uk_lrt_extent.exs <csv_path> [--limit N] [--dry-run]")
        IO.puts("\nExamples:")
        IO.puts("  mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv")
        IO.puts("  mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --limit 100")
        IO.puts("  mix run ../scripts/update_uk_lrt_extent.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run")
        System.halt(1)
      end
  end

# Build options
update_opts = [
  limit: Keyword.get(opts, :limit, :all),
  dry_run: Keyword.get(opts, :dry_run, false)
]

# Run the updater
UkLrtExtentUpdater.run(csv_path, update_opts)
