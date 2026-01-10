#!/usr/bin/env elixir
# Migration script to convert legacy text-based change logs to JSONB format
#
# Usage:
#   cd backend
#   mix run scripts/migrate_change_logs.exs
#
# This script:
# 1. Reads all records with amending_change_log or amended_by_change_log
# 2. Parses the text format into structured entries
# 3. Merges them into the new record_change_log JSONB column
# 4. Preserves the original text columns (no deletion)

alias SertantaiLegal.Legal.UkLrt
require Ash.Query

defmodule LegacyLogParser do
  @moduledoc """
  Parses legacy text-based change log format into structured entries.

  Legacy format example:
  ```
  1/12/2024
  🔺_stats_affected_laws_count
  nil -> 0
  🔺_stats_self_affects_count
  nil -> 0
  Amended_by
  UK_uksi_2024_1160
  ```
  """

  @doc """
  Parse a legacy change log text into a list of structured entries.
  """
  def parse(nil), do: []
  def parse(""), do: []

  def parse(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> parse_lines([])
    |> Enum.reverse()
  end

  # Parse lines into entries, grouping by date
  defp parse_lines([], entries), do: entries

  defp parse_lines([line | rest], entries) do
    if is_date_line?(line) do
      # Start a new entry
      {changes, remaining} = collect_changes(rest, %{})
      entry = build_entry(line, changes)
      parse_lines(remaining, [entry | entries])
    else
      # Skip orphaned lines (shouldn't happen in well-formed data)
      parse_lines(rest, entries)
    end
  end

  # Collect field changes until the next date line
  defp collect_changes([], changes), do: {changes, []}

  defp collect_changes([line | rest] = lines, changes) do
    cond do
      is_date_line?(line) ->
        # Hit next entry, return what we have
        {changes, lines}

      is_field_name?(line) ->
        # Get the value on the next line
        case rest do
          [value_line | remaining] ->
            {old_val, new_val} = parse_value_line(value_line)
            field_name = normalize_field_name(line)

            change_entry =
              if old_val do
                %{"old" => old_val, "new" => new_val}
              else
                %{"old" => nil, "new" => new_val}
              end

            collect_changes(remaining, Map.put(changes, field_name, change_entry))

          [] ->
            {changes, []}
        end

      true ->
        # Skip unrecognized lines
        collect_changes(rest, changes)
    end
  end

  defp is_date_line?(line) do
    # Match D/M/YYYY or DD/MM/YYYY format
    Regex.match?(~r/^\d{1,2}\/\d{1,2}\/\d{4}$/, line)
  end

  defp is_field_name?(line) do
    # Field names start with emoji indicators or are known field names
    String.starts_with?(line, "🔺") or
      String.starts_with?(line, "🔻") or
      line in ["Amended_by", "Amending", "Rescinded_by", "Rescinding"]
  end

  defp parse_value_line(line) do
    if String.contains?(line, " -> ") do
      [old, new] = String.split(line, " -> ", parts: 2)
      {parse_value(old), parse_value(new)}
    else
      # Single value (no old value shown) - treat as new value with nil old
      {nil, parse_value(line)}
    end
  end

  defp parse_value("nil"), do: nil
  defp parse_value(""), do: nil

  defp parse_value(val) do
    # Try to parse as integer
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> val
    end
  end

  defp normalize_field_name(name) do
    # Convert emoji-prefixed stat names to readable format
    name
    |> String.replace("🔺_stats_", "amending_stats_")
    |> String.replace("🔻_stats_", "amended_by_stats_")
    |> String.downcase()
  end

  defp build_entry(date_line, changes) do
    # Parse date from D/M/YYYY format
    [day, month, year] = String.split(date_line, "/")
    date_str = "#{year}-#{String.pad_leading(month, 2, "0")}-#{String.pad_leading(day, 2, "0")}"

    %{
      "timestamp" => "#{date_str}T00:00:00Z",
      "source" => "legacy_import",
      "changed_by" => "airtable_sync",
      "summary" => build_summary(changes),
      "changes" => changes
    }
  end

  defp build_summary(changes) when map_size(changes) == 0, do: "No changes"

  defp build_summary(changes) do
    field_names = changes |> Map.keys() |> Enum.sort() |> Enum.join(", ")
    count = map_size(changes)
    plural = if count == 1, do: "field", else: "fields"
    "Updated #{count} #{plural}: #{field_names}"
  end
end

defmodule MigrateChangeLogs do
  def run do
    IO.puts("\n=== Migrating Legacy Change Logs to record_change_log ===\n")

    # Find all records with legacy change log data
    {:ok, records} =
      UkLrt
      |> Ash.Query.filter(not is_nil(amending_change_log) or not is_nil(amended_by_change_log))
      |> Ash.read()

    total = length(records)
    IO.puts("Found #{total} records with legacy change log data\n")

    if total == 0 do
      IO.puts("Nothing to migrate.")
      :ok
    else
      results =
        records
        |> Enum.with_index(1)
        |> Enum.map(fn {record, idx} ->
          migrate_record(record, idx, total)
        end)

      successful = Enum.count(results, fn r -> r == :ok end)
      failed = Enum.count(results, fn r -> r != :ok end)

      IO.puts("\n=== Migration Complete ===")
      IO.puts("Successful: #{successful}")
      IO.puts("Failed: #{failed}")

      if failed > 0 do
        {:error, "#{failed} records failed to migrate"}
      else
        :ok
      end
    end
  end

  defp migrate_record(record, idx, total) do
    name = record.name

    # Parse legacy logs
    amending_entries = LegacyLogParser.parse(record.amending_change_log)
    amended_by_entries = LegacyLogParser.parse(record.amended_by_change_log)

    # Merge with existing record_change_log (if any)
    existing_log = record.record_change_log || []

    # Combine all entries (legacy first, then existing)
    # Tag legacy entries to distinguish their origin
    amending_tagged =
      Enum.map(amending_entries, fn entry ->
        Map.put(entry, "legacy_source", "amending_change_log")
      end)

    amended_by_tagged =
      Enum.map(amended_by_entries, fn entry ->
        Map.put(entry, "legacy_source", "amended_by_change_log")
      end)

    # Combine and sort by timestamp
    combined_log =
      (amending_tagged ++ amended_by_tagged ++ existing_log)
      |> Enum.sort_by(fn entry -> entry["timestamp"] end)

    if combined_log == existing_log do
      IO.puts("[#{idx}/#{total}] #{name} - No new entries to migrate")
      :ok
    else
      # Update the record
      case record
           |> Ash.Changeset.for_update(:update, %{record_change_log: combined_log})
           |> Ash.update() do
        {:ok, _} ->
          new_count = length(combined_log) - length(existing_log)
          IO.puts("[#{idx}/#{total}] #{name} - Migrated #{new_count} entries")
          :ok

        {:error, error} ->
          IO.puts("[#{idx}/#{total}] #{name} - ERROR: #{inspect(error)}")
          {:error, error}
      end
    end
  end
end

# Run the migration
MigrateChangeLogs.run()
