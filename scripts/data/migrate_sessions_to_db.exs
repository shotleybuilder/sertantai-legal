#!/usr/bin/env elixir
# Migration script to migrate existing scrape sessions from JSON files to DB tables.
#
# This script reads the JSON files from priv/scraper/<session_id>/ and populates:
# - scrape_session_records table (from inc_w_si.json, inc_wo_si.json, exc.json)
# - cascade_affected_laws table (from affected_laws.json)
#
# Usage:
#   cd backend
#   mix run ../scripts/data/migrate_sessions_to_db.exs
#
# Options:
#   --dry-run    Show what would be migrated without making changes
#   --session    Migrate a specific session (e.g., --session 2025-05-01-to-31)

defmodule SessionMigrator do
  alias SertantaiLegal.Scraper.{ScrapeSessionRecord, CascadeAffectedLaw}

  @scraper_path "priv/scraper"

  def run(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, false)
    specific_session = Keyword.get(opts, :session, nil)

    sessions = list_sessions(specific_session)

    IO.puts("\n=== Session Migration to DB ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}")
    IO.puts("Sessions to migrate: #{length(sessions)}\n")

    results =
      Enum.map(sessions, fn session_id ->
        migrate_session(session_id, dry_run)
      end)

    print_summary(results)
  end

  defp list_sessions(nil) do
    case File.ls(@scraper_path) do
      {:ok, entries} ->
        entries
        |> Enum.filter(fn entry ->
          path = Path.join(@scraper_path, entry)
          File.dir?(path) and not String.starts_with?(entry, ".")
        end)
        |> Enum.sort()

      {:error, reason} ->
        IO.puts("Error listing sessions: #{inspect(reason)}")
        []
    end
  end

  defp list_sessions(session_id), do: [session_id]

  defp migrate_session(session_id, dry_run) do
    IO.puts("--- Migrating: #{session_id} ---")

    session_path = Path.join(@scraper_path, session_id)

    # Check if session directory exists
    unless File.dir?(session_path) do
      IO.puts("  [SKIP] Session directory not found")
      return_result(session_id, :skipped, "Directory not found")
    end

    # Migrate session records (groups 1, 2, 3)
    records_result = migrate_session_records(session_id, session_path, dry_run)

    # Migrate cascade affected laws
    affected_result = migrate_affected_laws(session_id, session_path, dry_run)

    IO.puts("")

    %{
      session_id: session_id,
      records: records_result,
      affected_laws: affected_result
    }
  end

  defp migrate_session_records(session_id, session_path, dry_run) do
    groups = [
      {:group1, "inc_w_si.json"},
      {:group2, "inc_wo_si.json"},
      {:group3, "exc.json"}
    ]

    # Check if records already exist in DB
    case ScrapeSessionRecord.by_session(session_id) do
      {:ok, [_ | _] = existing} ->
        IO.puts("  [SKIP] Session records: #{length(existing)} already in DB")
        {:skipped, length(existing)}

      _ ->
        results =
          Enum.map(groups, fn {group, filename} ->
            file_path = Path.join(session_path, filename)
            migrate_group(session_id, group, file_path, dry_run)
          end)

        total = Enum.sum(Enum.map(results, fn {_, count} -> count end))
        {:migrated, total}
    end
  end

  defp migrate_group(session_id, group, file_path, dry_run) do
    case File.read(file_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, records} when is_list(records) ->
            count = length(records)

            if dry_run do
              IO.puts("  [DRY] Would migrate #{count} #{group} records")
            else
              migrate_records_to_db(session_id, group, records)
              IO.puts("  [OK] Migrated #{count} #{group} records")
            end

            {group, count}

          {:ok, records} when is_map(records) ->
            # Handle indexed format (map with numeric keys)
            record_list = Map.values(records)
            count = length(record_list)

            if dry_run do
              IO.puts("  [DRY] Would migrate #{count} #{group} records (indexed format)")
            else
              migrate_records_to_db(session_id, group, record_list)
              IO.puts("  [OK] Migrated #{count} #{group} records")
            end

            {group, count}

          {:error, reason} ->
            IO.puts("  [ERR] Failed to parse #{group}: #{inspect(reason)}")
            {group, 0}
        end

      {:error, :enoent} ->
        IO.puts("  [SKIP] #{group}: file not found")
        {group, 0}

      {:error, reason} ->
        IO.puts("  [ERR] Failed to read #{group}: #{inspect(reason)}")
        {group, 0}
    end
  end

  defp migrate_records_to_db(session_id, group, records) do
    Enum.each(records, fn record ->
      # Extract law_name from record
      law_name = record["name"] || record[:name]

      unless law_name do
        IO.puts("    [WARN] Record missing name field, skipping")
      else
        # Determine status based on presence of parsed data or reviewed flag
        status =
          cond do
            record["reviewed"] == true or record[:reviewed] == true -> :confirmed
            record["parsed_data"] || record[:parsed_data] -> :parsed
            true -> :pending
          end

        # Store the ENTIRE record as parsed_data (all scrape metadata)
        # Strip transient fields that don't belong in parsed_data
        parsed_data = record_to_parsed_data(record)

        # Note: parse_count is not accepted by create action, uses default of 1
        attrs = %{
          session_id: session_id,
          law_name: law_name,
          group: group,
          status: status,
          selected: record["selected"] || record[:selected] || false,
          parsed_data: parsed_data
        }

        case ScrapeSessionRecord.create(attrs) do
          {:ok, _} ->
            :ok

          {:error, %Ash.Error.Invalid{} = error} ->
            # Check if it's a uniqueness error (already exists)
            if String.contains?(inspect(error), "unique") do
              :ok
            else
              IO.puts("    [ERR] Failed to create record #{law_name}: #{inspect(error)}")
            end

          {:error, reason} ->
            IO.puts("    [ERR] Failed to create record #{law_name}: #{inspect(reason)}")
        end
      end
    end)
  end

  # Convert record map to parsed_data format for DB storage
  # Strips out transient fields, keeps all scrape metadata
  defp record_to_parsed_data(record) do
    # Keys to exclude from parsed_data (transient/session-specific fields)
    exclude_keys = ["selected", "status", "parse_count", :selected, :status, :parse_count]

    record
    |> Enum.reject(fn {k, v} ->
      k in exclude_keys or is_nil(v) or v == "" or v == []
    end)
    |> Enum.into(%{})
  end

  defp migrate_affected_laws(session_id, session_path, dry_run) do
    file_path = Path.join(session_path, "affected_laws.json")

    # Check if affected laws already exist in DB
    case CascadeAffectedLaw.by_session(session_id) do
      {:ok, [_ | _] = existing} ->
        IO.puts("  [SKIP] Affected laws: #{length(existing)} already in DB")
        {:skipped, length(existing)}

      _ ->
        case File.read(file_path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, data} ->
                entries = data["entries"] || []
                count = length(entries)

                if dry_run do
                  IO.puts("  [DRY] Would migrate #{count} affected law entries")
                  {:dry_run, count}
                else
                  migrate_affected_entries_to_db(session_id, entries)
                  # Count actual DB entries (deduplicated)
                  {:ok, db_entries} = CascadeAffectedLaw.by_session(session_id)

                  IO.puts(
                    "  [OK] Migrated #{count} entries -> #{length(db_entries)} DB rows (deduplicated)"
                  )

                  {:migrated, length(db_entries)}
                end

              {:error, reason} ->
                IO.puts("  [ERR] Failed to parse affected_laws.json: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, :enoent} ->
            IO.puts("  [SKIP] affected_laws.json: file not found")
            {:skipped, 0}

          {:error, reason} ->
            IO.puts("  [ERR] Failed to read affected_laws.json: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end

  defp migrate_affected_entries_to_db(session_id, entries) do
    Enum.each(entries, fn entry ->
      source_law = entry["source_law"]
      amending = entry["amending"] || []
      rescinding = entry["rescinding"] || []
      enacted_by = entry["enacted_by"] || []

      # Create reparse entries for amending + rescinding
      reparse_laws = Enum.uniq(amending ++ rescinding)

      Enum.each(reparse_laws, fn affected_law ->
        upsert_cascade_entry(session_id, affected_law, :reparse, source_law)
      end)

      # Create enacting_link entries for enacted_by
      Enum.each(enacted_by, fn affected_law ->
        # Only add as enacting_link if not already marked for reparse
        case CascadeAffectedLaw.by_session_and_law(session_id, affected_law) do
          {:ok, nil} ->
            upsert_cascade_entry(session_id, affected_law, :enacting_link, source_law)

          {:ok, existing} ->
            # Just append source_law, don't downgrade from reparse
            CascadeAffectedLaw.append_source_law(existing, %{source_law: source_law})

          {:error, _} ->
            upsert_cascade_entry(session_id, affected_law, :enacting_link, source_law)
        end
      end)
    end)
  end

  defp upsert_cascade_entry(session_id, affected_law, update_type, source_law) do
    case CascadeAffectedLaw.by_session_and_law(session_id, affected_law) do
      {:ok, nil} ->
        CascadeAffectedLaw.create(%{
          session_id: session_id,
          affected_law: affected_law,
          update_type: update_type,
          status: :pending,
          source_laws: [source_law]
        })

      {:ok, existing} ->
        CascadeAffectedLaw.append_source_law(existing, %{source_law: source_law})

        # Upgrade to reparse if needed
        if update_type == :reparse and existing.update_type == :enacting_link do
          CascadeAffectedLaw.upgrade_to_reparse(existing)
        end

      {:error, _} ->
        CascadeAffectedLaw.create(%{
          session_id: session_id,
          affected_law: affected_law,
          update_type: update_type,
          status: :pending,
          source_laws: [source_law]
        })
    end
  end

  defp return_result(session_id, status, message) do
    %{session_id: session_id, status: status, message: message}
  end

  defp print_summary(results) do
    IO.puts("\n=== Migration Summary ===")

    total_records =
      results
      |> Enum.map(fn r ->
        case r.records do
          {:migrated, count} -> count
          {:skipped, _} -> 0
          _ -> 0
        end
      end)
      |> Enum.sum()

    total_affected =
      results
      |> Enum.map(fn r ->
        case r.affected_laws do
          {:migrated, count} -> count
          {:skipped, _} -> 0
          _ -> 0
        end
      end)
      |> Enum.sum()

    IO.puts("Sessions processed: #{length(results)}")
    IO.puts("Session records migrated: #{total_records}")
    IO.puts("Cascade entries migrated: #{total_affected}")
    IO.puts("=========================\n")
  end
end

# Parse command line arguments
args = System.argv()

opts =
  Enum.reduce(args, [], fn arg, acc ->
    cond do
      arg == "--dry-run" ->
        [{:dry_run, true} | acc]

      String.starts_with?(arg, "--session=") ->
        session = String.replace_prefix(arg, "--session=", "")
        [{:session, session} | acc]

      true ->
        acc
    end
  end)

# Run the migration
SessionMigrator.run(opts)
