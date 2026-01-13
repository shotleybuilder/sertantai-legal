#!/usr/bin/env elixir

# Update UK LRT Taxa columns from Airtable CSV export
#
# Usage:
#   cd backend && mix run ../scripts/data/update_uk_lrt_taxa.exs [csv_path] [--limit N] [--dry-run]
#
# Examples:
#   mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv
#   mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv --limit 100
#   mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv --dry-run
#
# Taxa columns imported:
#   - role (from actor) - text[] - SKIPPED if already has data
#   - role_gvt (from actor_gvt) - jsonb
#   - duty_type - text
#   - duty_type_article - text
#   - article_duty_type - text
#   - duty_holder - jsonb
#   - duty_holder_article - text
#   - duty_holder_article_clause - text
#   - article_duty_holder - text
#   - article_duty_holder_clause - text
#   - rights_holder - jsonb
#   - rights_holder_article - text
#   - rights_holder_article_clause - text
#   - article_rights_holder - text
#   - article_rights_holder_clause - text
#   - responsibility_holder - jsonb
#   - responsibility_holder_article - text
#   - responsibility_holder_article_clause - text
#   - article_responsibility_holder - text
#   - article_responsibility_holder_clause - text
#   - power_holder - jsonb
#   - power_holder_article - text
#   - power_holder_article_clause - text
#   - article_power_holder - text
#   - article_power_holder_clause - text
#   - popimar - jsonb
#   - popimar_article - text
#   - popimar_article_clause - text
#   - article_popimar - text
#   - article_popimar_clause - text

require Logger

# Define CSV parser
NimbleCSV.define(AirtableCSV, separator: ",", escape: "\"")

defmodule UkLrtTaxaUpdater do
  @moduledoc """
  Updates UK LRT Taxa columns from Airtable CSV export.
  """

  @batch_size 100
  @progress_interval 500

  # Map CSV column names to DB column names
  # Format: {csv_column, db_column, type}
  # Types: :text, :text_array, :jsonb
  @column_mappings [
    # Role (actor in CSV)
    {"actor", "role", :text_array},
    {"actor_gvt", "role_gvt", :jsonb},
    # Duty Type
    {"duty_type", "duty_type", :text},
    {"duty_type_article", "duty_type_article", :text},
    {"article_duty_type", "article_duty_type", :text},
    # Duty Holder
    {"duty_holder", "duty_holder", :jsonb},
    {"duty_holder_article", "duty_holder_article", :text},
    {"duty_holder_article_clause", "duty_holder_article_clause", :text},
    {"article_duty_holder", "article_duty_holder", :text},
    {"article_duty_holder_clause", "article_duty_holder_clause", :text},
    # Rights Holder
    {"rights_holder", "rights_holder", :jsonb},
    {"rights_holder_article", "rights_holder_article", :text},
    {"rights_holder_article_clause", "rights_holder_article_clause", :text},
    {"article_rights_holder", "article_rights_holder", :text},
    {"article_rights_holder_clause", "article_rights_holder_clause", :text},
    # Responsibility Holder
    {"responsibility_holder", "responsibility_holder", :jsonb},
    {"responsibility_holder_article", "responsibility_holder_article", :text},
    {"responsibility_holder_article_clause", "responsibility_holder_article_clause", :text},
    {"article_responsibility_holder", "article_responsibility_holder", :text},
    {"article_responsibility_holder_clause", "article_responsibility_holder_clause", :text},
    # Power Holder
    {"power_holder", "power_holder", :jsonb},
    {"power_holder_article", "power_holder_article", :text},
    {"power_holder_article_clause", "power_holder_article_clause", :text},
    {"article_power_holder", "article_power_holder", :text},
    {"article_power_holder_clause", "article_power_holder_clause", :text},
    # Popimar
    {"popimar", "popimar", :jsonb},
    {"popimar_article", "popimar_article", :text},
    {"popimar_article_clause", "popimar_article_clause", :text},
    {"article_popimar", "article_popimar", :text},
    {"article_popimar_clause", "article_popimar_clause", :text}
  ]

  def run(csv_path, opts \\ []) do
    limit = Keyword.get(opts, :limit, :all)
    dry_run = Keyword.get(opts, :dry_run, false)

    IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    IO.puts("  UK LRT Taxa Update from Airtable CSV")
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

    # Read headers and build column index map
    IO.puts("  Reading CSV headers...")
    {headers, column_indices} = read_headers(csv_path)
    IO.puts("  Found #{map_size(column_indices)} Taxa columns in CSV\n")

    # Show which columns were found
    found_columns = Map.keys(column_indices) |> Enum.sort()
    IO.puts("  Taxa columns found: #{Enum.join(found_columns, ", ")}\n")

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
        %{updated: 0, skipped: 0, not_found: 0, no_data: 0, errors: [], column_counts: %{}},
        fn batch, acc ->
          process_batch(batch, name_to_id, column_indices, dry_run, acc)
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

    # Find Name column index
    name_idx = Enum.find_index(headers, &(&1 == "Name"))

    unless name_idx do
      IO.puts("  ✗ Name column not found in CSV")
      System.halt(1)
    end

    # Build index map for Taxa columns
    column_indices =
      @column_mappings
      |> Enum.reduce(%{name: name_idx}, fn {csv_col, db_col, type}, acc ->
        case Enum.find_index(headers, &(&1 == csv_col)) do
          nil -> acc
          idx -> Map.put(acc, db_col, {idx, type})
        end
      end)

    {headers, column_indices}
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

  defp process_batch(batch, name_to_id, column_indices, dry_run, acc) do
    {_, last_index} = List.last(batch)

    if rem(last_index, @progress_interval) == 0 or last_index <= @batch_size do
      IO.write("\r  Processed: #{last_index} records...")
    end

    Enum.reduce(batch, acc, fn {row, _index}, acc ->
      process_row(row, name_to_id, column_indices, dry_run, acc)
    end)
  end

  defp process_row(row, name_to_id, column_indices, dry_run, acc) do
    name = get_field(row, column_indices.name)

    cond do
      is_nil(name) ->
        %{acc | skipped: acc.skipped + 1}

      not Map.has_key?(name_to_id, name) ->
        %{acc | not_found: acc.not_found + 1}

      true ->
        id = Map.get(name_to_id, name)

        # Build update map from CSV values
        {updates, column_counts} = build_updates(row, column_indices, acc.column_counts)

        if map_size(updates) == 0 do
          %{acc | no_data: acc.no_data + 1, column_counts: column_counts}
        else
          if dry_run do
            %{acc | updated: acc.updated + 1, column_counts: column_counts}
          else
            case update_record(id, updates) do
              :ok ->
                %{acc | updated: acc.updated + 1, column_counts: column_counts}

              {:error, reason} ->
                %{acc | errors: [{name, reason} | acc.errors], column_counts: column_counts}
            end
          end
        end
    end
  end

  defp build_updates(row, column_indices, column_counts) do
    # Skip :name key, process all Taxa columns
    taxa_columns = Map.delete(column_indices, :name)

    Enum.reduce(taxa_columns, {%{}, column_counts}, fn {db_col, {idx, type}}, {updates, counts} ->
      raw_value = get_field(row, idx)

      case parse_value(raw_value, type) do
        nil ->
          {updates, counts}

        value ->
          new_counts = Map.update(counts, db_col, 1, &(&1 + 1))
          {Map.put(updates, db_col, value), new_counts}
      end
    end)
  end

  defp parse_value(nil, _type), do: nil
  defp parse_value("", _type), do: nil

  defp parse_value(value, :text), do: value

  defp parse_value(value, :text_array) do
    # Parse comma-separated values into array
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> case do
      [] -> nil
      arr -> arr
    end
  end

  defp parse_value(value, :jsonb_values) do
    # Parse comma-separated values into JSONB {"values": [...]} format
    # Handles quoted values with commas inside (e.g., "Interpretation, Definition")
    value
    |> parse_csv_values()
    |> case do
      [] -> nil
      arr -> %{"values" => arr}
    end
  end

  # Parse CSV values respecting quoted strings
  defp parse_csv_values(str) do
    # Use regex to split on commas not inside quotes
    ~r/(?:^|,)("(?:[^"]*(?:""[^"]*)*)"|[^,]*)/
    |> Regex.scan(str)
    |> Enum.map(fn
      [_, quoted] when is_binary(quoted) ->
        quoted
        |> String.trim()
        |> String.trim("\"")
        # Handle escaped quotes
        |> String.replace("\"\"", "\"")

      _ ->
        nil
    end)
    |> Enum.filter(&(&1 != nil and &1 != ""))
  end

  defp parse_value(value, :jsonb) do
    # For jsonb holder columns, the CSV has a specific format
    # Try to parse as JSON first, otherwise treat as comma-separated keys
    case Jason.decode(value) do
      {:ok, parsed} when is_map(parsed) ->
        parsed

      _ ->
        # Treat as comma-separated list of values, convert to map with true values
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> case do
          [] -> nil
          items -> Enum.reduce(items, %{}, fn item, acc -> Map.put(acc, item, true) end)
        end
    end
  end

  defp update_record(id, updates) do
    import Ecto.Query

    # Convert string keys to atoms for the set clause
    set_list =
      updates
      |> Enum.map(fn {col, val} ->
        atom_col = String.to_atom(col)
        {atom_col, val}
      end)

    query =
      from(u in "uk_lrt",
        where: u.id == ^id,
        update: [set: ^set_list]
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
    IO.puts("  No data:      #{result.no_data} (no Taxa fields)")
    IO.puts("  Skipped:      #{result.skipped} (missing name)")
    IO.puts("  Not found:    #{result.not_found} (not in database)")
    IO.puts("  Errors:       #{length(result.errors)}")
    IO.puts("  Duration:     #{Float.round(duration_sec, 1)}s")
    IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Show column update counts
    if map_size(result.column_counts) > 0 do
      IO.puts("\n  Records updated per column:")

      result.column_counts
      |> Enum.sort_by(fn {_col, count} -> -count end)
      |> Enum.each(fn {col, count} ->
        IO.puts("    #{col}: #{count}")
      end)
    end

    if length(result.errors) > 0 do
      IO.puts("\n  Sample errors (first 5):")

      Enum.each(Enum.take(result.errors, 5), fn {name, reason} ->
        IO.puts("    #{name}: #{String.slice(inspect(reason), 0, 200)}")
      end)

      if length(result.errors) > 5 do
        IO.puts("    ... and #{length(result.errors) - 5} more errors")
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
      default_path = Path.expand("~/Documents/sertantai_data/UK-EXPORT.csv")

      if File.exists?(default_path) do
        default_path
      else
        IO.puts(
          "Usage: mix run ../scripts/data/update_uk_lrt_taxa.exs <csv_path> [--limit N] [--dry-run]"
        )

        IO.puts("\nExamples:")

        IO.puts(
          "  mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv"
        )

        IO.puts(
          "  mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv --limit 100"
        )

        IO.puts(
          "  mix run ../scripts/data/update_uk_lrt_taxa.exs ~/Documents/sertantai_data/UK-EXPORT.csv --dry-run"
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
UkLrtTaxaUpdater.run(csv_path, update_opts)
