#!/usr/bin/env elixir

# Update UK LRT domain column from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/data/update_uk_lrt_domain.exs [csv_path] [--dry-run]
#
# Examples:
#   mix run ../scripts/data/update_uk_lrt_domain.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv
#   mix run ../scripts/data/update_uk_lrt_domain.exs ~/Documents/Airtable_Exports/UK-EXPORT.csv --dry-run
#
# Maps CSV "Class" column values to domain array:
#   ENV -> ["environment"]
#   H&S -> ["health_safety"]
#   HR  -> ["human_resources"]
#   Multiple values (comma-separated) -> array of mapped values

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtDomainUpdater do
  @moduledoc """
  Updates UK LRT domain column from Airtable CSV export.
  """

  @domain_map %{
    "ENV" => "environment",
    "H&S" => "health_safety",
    "HR" => "human_resources"
  }

  def run(csv_path, opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT domain Update from Airtable CSV")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  File: #{csv_path}")
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
    {name_idx, class_idx} = read_headers(csv_path)
    IO.puts("  Name column index: #{name_idx}")
    IO.puts("  Class column index: #{class_idx}\n")

    # Process updates
    IO.puts("  Processing CSV records...")
    start_time = System.monotonic_time(:millisecond)

    result =
      csv_path
      |> File.stream!()
      |> AirtableCSV.parse_stream(skip_headers: true)
      |> Enum.reduce(
        %{updated: 0, skipped: 0, not_found: 0, no_data: 0, errors: [], domain_counts: %{}},
        fn row, acc ->
          process_row(row, name_idx, class_idx, name_to_id, dry_run, acc)
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
    class_idx = Enum.find_index(headers, &(&1 == "Class"))

    unless name_idx do
      IO.puts("  ✗ Name column not found in CSV")
      System.halt(1)
    end

    unless class_idx do
      IO.puts("  ✗ Class column not found in CSV")
      System.halt(1)
    end

    {name_idx, class_idx}
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

  defp get_field(row, idx) when is_list(row) and is_integer(idx) do
    case Enum.at(row, idx) do
      nil -> nil
      "" -> nil
      v -> String.trim(v)
    end
  end

  defp parse_domain(nil), do: nil
  defp parse_domain(""), do: nil

  defp parse_domain(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&Map.get(@domain_map, &1, &1))
    |> Enum.filter(&(&1 != nil and &1 != ""))
    |> case do
      [] -> nil
      domains -> Enum.uniq(domains)
    end
  end

  defp process_row(row, name_idx, class_idx, name_to_id, dry_run, acc) do
    name = get_field(row, name_idx)
    class_value = get_field(row, class_idx)
    domains = parse_domain(class_value)

    cond do
      is_nil(name) ->
        %{acc | skipped: acc.skipped + 1}

      is_nil(domains) ->
        %{acc | no_data: acc.no_data + 1}

      not Map.has_key?(name_to_id, name) ->
        %{acc | not_found: acc.not_found + 1}

      true ->
        id = Map.get(name_to_id, name)

        # Track domain counts
        domain_counts =
          Enum.reduce(domains, acc.domain_counts, fn d, counts ->
            Map.update(counts, d, 1, &(&1 + 1))
          end)

        if dry_run do
          %{acc | updated: acc.updated + 1, domain_counts: domain_counts}
        else
          case update_record(id, domains) do
            :ok ->
              %{acc | updated: acc.updated + 1, domain_counts: domain_counts}

            {:error, reason} ->
              %{acc | errors: [{name, reason} | acc.errors], domain_counts: domain_counts}
          end
        end
    end
  end

  defp update_record(id, domains) do
    import Ecto.Query

    query =
      from(u in "uk_lrt",
        where: u.id == ^id,
        update: [set: [domain: ^domains]]
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
    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if dry_run do
      IO.puts("  DRY RUN Complete (no changes made)")
    else
      IO.puts("  Update Complete!")
    end

    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  Updated:      #{result.updated}")
    IO.puts("  No data:      #{result.no_data} (empty Class)")
    IO.puts("  Skipped:      #{result.skipped} (missing name)")
    IO.puts("  Not found:    #{result.not_found} (not in database)")
    IO.puts("  Errors:       #{length(result.errors)}")
    IO.puts("  Duration:     #{Float.round(duration_sec, 1)}s")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if map_size(result.domain_counts) > 0 do
      IO.puts("\n  Domain counts:")

      result.domain_counts
      |> Enum.sort_by(fn {_k, v} -> -v end)
      |> Enum.each(fn {domain, count} ->
        IO.puts("    #{domain}: #{count}")
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
    strict: [dry_run: :boolean],
    aliases: [n: :dry_run]
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
        IO.puts("Usage: mix run ../scripts/data/update_uk_lrt_domain.exs <csv_path> [--dry-run]")
        System.halt(1)
      end
  end

# Build options
update_opts = [
  dry_run: Keyword.get(opts, :dry_run, false)
]

# Run the updater
UkLrtDomainUpdater.run(csv_path, update_opts)
