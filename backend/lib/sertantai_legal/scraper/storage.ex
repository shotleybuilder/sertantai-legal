defmodule SertantaiLegal.Scraper.Storage do
  @moduledoc """
  File storage operations for scraper JSON files.

  All files are stored under priv/scraper/{session_id}/:
  - raw.json: All fetched records
  - inc_w_si.json: Group 1 - SI code match
  - inc_wo_si.json: Group 2 - Term match only
  - exc.json: Group 3 - Excluded records
  - metadata.json: Session summary
  """

  @base_path "priv/scraper"

  @doc """
  Get the base scraper directory path.
  """
  @spec base_path() :: String.t()
  def base_path do
    Path.join(Application.app_dir(:sertantai_legal), @base_path)
  end

  @doc """
  Get the session directory path.
  """
  @spec session_path(String.t()) :: String.t()
  def session_path(session_id) do
    Path.join(base_path(), session_id)
  end

  @doc """
  Create the session directory.
  """
  @spec create_session_dir(String.t()) :: :ok | {:error, any()}
  def create_session_dir(session_id) do
    path = session_path(session_id)

    case File.mkdir_p(path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create directory #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  Get the full path for a file in a session directory.
  """
  @spec file_path(String.t(), atom()) :: String.t()
  def file_path(session_id, file_type) do
    filename =
      case file_type do
        :raw -> "raw.json"
        :group1 -> "inc_w_si.json"
        :group2 -> "inc_wo_si.json"
        :group3 -> "exc.json"
        :metadata -> "metadata.json"
        :affected_laws -> "affected_laws.json"
      end

    Path.join(session_path(session_id), filename)
  end

  @doc """
  Get the relative path (from priv/scraper/) for a file.
  Used for storing in database.
  """
  @spec relative_path(String.t(), atom()) :: String.t()
  def relative_path(session_id, file_type) do
    filename =
      case file_type do
        :raw -> "raw.json"
        :group1 -> "inc_w_si.json"
        :group2 -> "inc_wo_si.json"
        :group3 -> "exc.json"
        :metadata -> "metadata.json"
        :affected_laws -> "affected_laws.json"
      end

    Path.join(session_id, filename)
  end

  @doc """
  Save records to a JSON file.
  """
  @spec save_json(String.t(), atom(), list(map()) | map()) :: :ok | {:error, any()}
  def save_json(session_id, file_type, data) do
    path = file_path(session_id, file_type)

    with :ok <- create_session_dir(session_id),
         {:ok, json} <- encode_json(data),
         :ok <- File.write(path, json) do
      IO.puts("Saved #{Enum.count(listify(data))} records to #{path}")
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Read records from a JSON file.
  Returns list for raw/group1/group2, map for group3 (indexed).
  """
  @spec read_json(String.t(), atom()) :: {:ok, list(map()) | map()} | {:error, any()}
  def read_json(session_id, file_type) do
    path = file_path(session_id, file_type)

    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content, keys: :atoms) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "Failed to decode JSON: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read file #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  Check if a session directory exists.
  """
  @spec session_exists?(String.t()) :: boolean()
  def session_exists?(session_id) do
    File.dir?(session_path(session_id))
  end

  @doc """
  Check if a file exists in a session directory.
  """
  @spec file_exists?(String.t(), atom()) :: boolean()
  def file_exists?(session_id, file_type) do
    File.exists?(file_path(session_id, file_type))
  end

  @doc """
  Delete a session directory and all its files.
  """
  @spec delete_session(String.t()) :: :ok | {:error, any()}
  def delete_session(session_id) do
    path = session_path(session_id)

    case File.rm_rf(path) do
      {:ok, _} -> :ok
      {:error, reason, _} -> {:error, "Failed to delete #{path}: #{inspect(reason)}"}
    end
  end

  @doc """
  List all session directories.
  """
  @spec list_sessions() :: {:ok, list(String.t())} | {:error, any()}
  def list_sessions do
    path = base_path()

    case File.ls(path) do
      {:ok, entries} ->
        sessions =
          entries
          |> Enum.filter(fn entry ->
            File.dir?(Path.join(path, entry))
          end)
          |> Enum.sort(:desc)

        {:ok, sessions}

      {:error, :enoent} ->
        {:ok, []}

      {:error, reason} ->
        {:error, "Failed to list sessions: #{inspect(reason)}"}
    end
  end

  @doc """
  Save metadata summary for a session.
  """
  @spec save_metadata(String.t(), map()) :: :ok | {:error, any()}
  def save_metadata(session_id, metadata) do
    save_json(session_id, :metadata, metadata)
  end

  @doc """
  Index excluded records with numeric keys for easy reference.
  Matches the legl app pattern.
  """
  @spec index_records(list(map())) :: map()
  def index_records(records) do
    {indexed, _} =
      Enum.reduce(records, {%{}, 1}, fn record, {acc, counter} ->
        key = Integer.to_string(counter)
        {Map.put(acc, key, record), counter + 1}
      end)

    indexed
  end

  # Private helpers

  defp encode_json(data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to encode JSON: #{inspect(reason)}"}
    end
  end

  defp listify(data) when is_list(data), do: data
  defp listify(data) when is_map(data), do: Map.values(data)

  @doc """
  Update selection state for records in a group.

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3
  - names: List of record names to update (e.g., ["uksi/2025/1227", ...])
  - selected: Boolean to set for the selected field

  ## Returns
  `{:ok, count}` with the number of records updated, or `{:error, reason}`
  """
  @spec update_selection(String.t(), atom(), list(String.t()), boolean()) ::
          {:ok, integer()} | {:error, any()}
  def update_selection(session_id, group, names, selected) when is_list(names) do
    case read_json(session_id, group) do
      {:ok, records} ->
        names_set = MapSet.new(names)

        {updated_records, count} = update_records_selection(records, names_set, selected)

        case save_json(session_id, group, updated_records) do
          :ok -> {:ok, count}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get selected record names from a group.

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3

  ## Returns
  `{:ok, names}` with list of selected record names, or `{:error, reason}`
  """
  @spec get_selected(String.t(), atom()) :: {:ok, list(String.t())} | {:error, any()}
  def get_selected(session_id, group) do
    case read_json(session_id, group) do
      {:ok, records} ->
        selected_names = extract_selected_names(records)
        {:ok, selected_names}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get the count of selected records in a group.
  """
  @spec selected_count(String.t(), atom()) :: {:ok, integer()} | {:error, any()}
  def selected_count(session_id, group) do
    case get_selected(session_id, group) do
      {:ok, names} -> {:ok, length(names)}
      {:error, reason} -> {:error, reason}
    end
  end

  # Update selection for list format (groups 1 and 2)
  defp update_records_selection(records, names_set, selected) when is_list(records) do
    {updated, count} =
      Enum.map_reduce(records, 0, fn record, acc ->
        name = record[:name] || record["name"]

        if name && MapSet.member?(names_set, name) do
          {Map.put(record, :selected, selected), acc + 1}
        else
          {record, acc}
        end
      end)

    {updated, count}
  end

  # Update selection for indexed map format (group 3)
  defp update_records_selection(records, names_set, selected) when is_map(records) do
    {updated, count} =
      Enum.map_reduce(records, 0, fn {key, record}, acc ->
        name = record[:name] || record["name"]

        if name && MapSet.member?(names_set, name) do
          {{key, Map.put(record, :selected, selected)}, acc + 1}
        else
          {{key, record}, acc}
        end
      end)

    {Enum.into(updated, %{}), count}
  end

  # Extract selected names from list format
  defp extract_selected_names(records) when is_list(records) do
    records
    |> Enum.filter(fn record -> record[:selected] == true end)
    |> Enum.map(fn record -> record[:name] || record["name"] end)
    |> Enum.reject(&is_nil/1)
  end

  # Extract selected names from indexed map format
  defp extract_selected_names(records) when is_map(records) do
    records
    |> Map.values()
    |> extract_selected_names()
  end

  defp extract_selected_names(_), do: []

  # ============================================================================
  # Affected Laws Management (for Cascade Updates)
  # ============================================================================

  alias SertantaiLegal.Scraper.CascadeAffectedLaw

  @doc """
  Add affected laws from a persisted record to the cascade todo list.

  Writes to both DB (cascade_affected_laws table) and JSON (backwards compat).
  DB entries are deduplicated by affected_law - multiple source laws pointing
  to the same affected law result in one row with source_laws array.

  ## Parameters
  - session_id: Session identifier
  - source_law: The law that was persisted (name, e.g., "uksi/2024/123")
  - amending: List of law IDs this law amends (need reparse)
  - rescinding: List of law IDs this law rescinds (need reparse)
  - enacted_by: List of parent law IDs that enable this law (need enacting link update)

  ## Returns
  `:ok` or `{:error, reason}`
  """
  @spec add_affected_laws(
          String.t(),
          String.t(),
          list(String.t()),
          list(String.t()),
          list(String.t())
        ) ::
          :ok | {:error, any()}
  def add_affected_laws(session_id, source_law, amending, rescinding, enacted_by \\ []) do
    amending = amending || []
    rescinding = rescinding || []
    enacted_by = enacted_by || []

    # Skip if no affected laws
    if amending == [] and rescinding == [] and enacted_by == [] do
      :ok
    else
      # Write to DB (deduplicated by affected_law)
      add_affected_laws_to_db(session_id, source_law, amending, rescinding, enacted_by)

      # Also write to JSON for backwards compatibility
      add_affected_laws_to_json(session_id, source_law, amending, rescinding, enacted_by)
    end
  end

  # Add affected laws to DB with proper deduplication
  defp add_affected_laws_to_db(session_id, source_law, amending, rescinding, enacted_by) do
    alias SertantaiLegal.Scraper.IdField

    # Normalize source_law to DB format for comparison
    source_law_normalized = IdField.normalize_to_db_name(source_law)

    # Laws that need reparse (amending + rescinding)
    # Filter out self-references (defense-in-depth - should already be filtered upstream)
    reparse_laws =
      (amending ++ rescinding)
      |> Enum.uniq()
      |> Enum.reject(fn affected_law ->
        IdField.normalize_to_db_name(affected_law) == source_law_normalized
      end)

    Enum.each(reparse_laws, fn affected_law ->
      upsert_cascade_entry(session_id, affected_law, :reparse, source_law)
    end)

    # Laws that need enacting link update (also filter self-references)
    enacted_by_filtered =
      enacted_by
      |> Enum.reject(fn affected_law ->
        IdField.normalize_to_db_name(affected_law) == source_law_normalized
      end)

    Enum.each(enacted_by_filtered, fn affected_law ->
      # Only add as enacting_link if not already marked for reparse
      case CascadeAffectedLaw.by_session_and_law(session_id, affected_law) do
        {:ok, nil} ->
          upsert_cascade_entry(session_id, affected_law, :enacting_link, source_law)

        {:ok, existing} ->
          # Just append source_law, don't downgrade from reparse to enacting_link
          CascadeAffectedLaw.append_source_law(existing, %{source_law: source_law})

        {:error, _} ->
          upsert_cascade_entry(session_id, affected_law, :enacting_link, source_law)
      end
    end)

    :ok
  end

  # Upsert a cascade entry, appending source_law if exists
  defp upsert_cascade_entry(session_id, affected_law, update_type, source_law) do
    case CascadeAffectedLaw.by_session_and_law(session_id, affected_law) do
      {:ok, nil} ->
        # Create new entry
        CascadeAffectedLaw.create(%{
          session_id: session_id,
          affected_law: affected_law,
          update_type: update_type,
          status: :pending,
          source_laws: [source_law]
        })

      {:ok, existing} ->
        # Append source_law and possibly upgrade update_type
        CascadeAffectedLaw.append_source_law(existing, %{source_law: source_law})

        # Upgrade to reparse if needed
        if update_type == :reparse and existing.update_type == :enacting_link do
          CascadeAffectedLaw.upgrade_to_reparse(existing)
        end

      {:error, _reason} ->
        # Try to create anyway
        CascadeAffectedLaw.create(%{
          session_id: session_id,
          affected_law: affected_law,
          update_type: update_type,
          status: :pending,
          source_laws: [source_law]
        })
    end
  end

  # Add affected laws to JSON (backwards compatibility)
  defp add_affected_laws_to_json(session_id, source_law, amending, rescinding, enacted_by) do
    # Read existing affected laws or initialize
    existing = read_affected_laws_json(session_id)

    # Build new entry
    new_entry = %{
      source_law: source_law,
      amending: amending,
      rescinding: rescinding,
      enacted_by: enacted_by,
      added_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Filter out any existing entry for this source_law to prevent duplicates
    filtered_entries =
      (existing[:entries] || [])
      |> Enum.reject(fn entry ->
        entry[:source_law] == source_law or entry["source_law"] == source_law
      end)

    # Merge: append new entry (replacing any previous), collect unique affected laws
    updated = %{
      entries: filtered_entries ++ [new_entry],
      all_amending: Enum.uniq((existing[:all_amending] || []) ++ amending),
      all_rescinding: Enum.uniq((existing[:all_rescinding] || []) ++ rescinding),
      all_enacting_parents: Enum.uniq((existing[:all_enacting_parents] || []) ++ enacted_by),
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    save_json(session_id, :affected_laws, updated)
  end

  @doc """
  Read affected laws from a session (tries DB first, falls back to JSON).

  ## Returns
  Map with :entries, :all_amending, :all_rescinding, :all_enacting_parents keys,
  or empty map if not found.
  """
  @spec read_affected_laws(String.t()) :: map()
  def read_affected_laws(session_id) do
    case CascadeAffectedLaw.by_session(session_id) do
      {:ok, db_entries} when db_entries != [] ->
        # Convert DB entries to the expected format
        reparse_laws =
          db_entries
          |> Enum.filter(&(&1.update_type == :reparse))
          |> Enum.map(& &1.affected_law)

        enacting_parents =
          db_entries
          |> Enum.filter(&(&1.update_type == :enacting_link))
          |> Enum.map(& &1.affected_law)

        # Build entries list from DB data
        entries =
          db_entries
          |> Enum.flat_map(fn entry ->
            Enum.map(entry.source_laws, fn source_law ->
              %{source_law: source_law, affected_law: entry.affected_law}
            end)
          end)
          |> Enum.uniq_by(& &1.source_law)

        %{
          entries: entries,
          all_amending: reparse_laws,
          all_rescinding: [],
          all_enacting_parents: enacting_parents
        }

      _ ->
        # Fall back to JSON
        read_affected_laws_json(session_id)
    end
  end

  # Read affected laws from JSON file only
  defp read_affected_laws_json(session_id) do
    case read_json(session_id, :affected_laws) do
      {:ok, data} ->
        data

      {:error, _} ->
        %{entries: [], all_amending: [], all_rescinding: [], all_enacting_parents: []}
    end
  end

  @doc """
  Get summary of affected laws for cascade update UI.

  Reads from DB first, falls back to JSON.

  ## Returns
  Map with counts and lists of affected laws.
  """
  @spec get_affected_laws_summary(String.t()) :: map()
  def get_affected_laws_summary(session_id) do
    # First check if any DB entries exist for this session (including processed)
    case CascadeAffectedLaw.by_session(session_id) do
      {:ok, db_entries} when db_entries != [] ->
        get_affected_laws_summary_from_db(db_entries)

      _ ->
        get_affected_laws_summary_from_json(session_id)
    end
  end

  defp get_affected_laws_summary_from_db(db_entries) do
    # Split by status first
    {pending_entries, processed_entries} =
      Enum.split_with(db_entries, &(&1.status == :pending))

    # Only pending entries appear in active lists
    {reparse_entries, enacting_entries} =
      Enum.split_with(pending_entries, &(&1.update_type == :reparse))

    reparse_laws = Enum.map(reparse_entries, & &1.affected_law)
    enacting_parents = Enum.map(enacting_entries, & &1.affected_law)

    # Collect source laws from ALL entries (including processed) for context
    source_laws =
      db_entries
      |> Enum.flat_map(& &1.source_laws)
      |> Enum.uniq()

    %{
      source_laws: source_laws,
      source_count: length(source_laws),
      # Only pending reparse laws in active lists
      amending: reparse_laws,
      amending_count: length(reparse_laws),
      rescinding: [],
      rescinding_count: 0,
      all_affected: reparse_laws,
      all_affected_count: length(reparse_laws),
      enacting_parents: enacting_parents,
      enacting_parents_count: length(enacting_parents),
      # Status counts for UI
      pending_count: length(pending_entries),
      processed_count: length(processed_entries)
    }
  end

  defp get_affected_laws_summary_from_json(session_id) do
    data = read_affected_laws_json(session_id)

    # Laws that need re-parsing (amending/rescinding relationships)
    all_affected =
      Enum.uniq((data[:all_amending] || []) ++ (data[:all_rescinding] || []))

    # Parent laws that need direct enacting array update
    enacting_parents = data[:all_enacting_parents] || []

    # JSON doesn't track status, so treat all as pending
    total_count = length(all_affected) + length(enacting_parents)

    %{
      source_laws: Enum.map(data[:entries] || [], & &1[:source_law]),
      source_count: length(data[:entries] || []),
      amending: data[:all_amending] || [],
      amending_count: length(data[:all_amending] || []),
      rescinding: data[:all_rescinding] || [],
      rescinding_count: length(data[:all_rescinding] || []),
      all_affected: all_affected,
      all_affected_count: length(all_affected),
      enacting_parents: enacting_parents,
      enacting_parents_count: length(enacting_parents),
      # JSON doesn't track status - treat all as pending
      pending_count: total_count,
      processed_count: 0
    }
  end

  @doc """
  Clear affected laws for a session (after cascade update is complete).

  Deletes from both DB and JSON file.
  """
  @spec clear_affected_laws(String.t()) :: :ok | {:error, any()}
  def clear_affected_laws(session_id) do
    # Delete from DB
    case CascadeAffectedLaw.by_session(session_id) do
      {:ok, entries} ->
        Enum.each(entries, fn entry ->
          CascadeAffectedLaw.destroy(entry)
        end)

      {:error, _} ->
        :ok
    end

    # Delete JSON file
    path = file_path(session_id, :affected_laws)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, "Failed to clear affected laws: #{inspect(reason)}"}
    end
  end

  @doc """
  Get a map of law_name => metadata for cascade entries that have cached metadata.
  """
  @spec get_cascade_metadata_map(String.t()) :: map()
  def get_cascade_metadata_map(session_id) do
    case CascadeAffectedLaw.by_session(session_id) do
      {:ok, entries} ->
        entries
        |> Enum.filter(& &1.metadata)
        |> Map.new(&{&1.affected_law, &1.metadata})

      _ ->
        %{}
    end
  end

  @doc """
  Mark a cascade entry as processed.
  """
  @spec mark_cascade_processed(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def mark_cascade_processed(session_id, affected_law) do
    case CascadeAffectedLaw.by_session_and_law(session_id, affected_law) do
      {:ok, nil} ->
        {:error, "Cascade entry not found"}

      {:ok, entry} ->
        CascadeAffectedLaw.mark_processed(entry)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get pending cascade entries for a session, partitioned by update_type.

  ## Returns
  Map with :reparse and :enacting_link lists
  """
  @spec get_pending_cascade_entries(String.t()) :: map()
  def get_pending_cascade_entries(session_id) do
    case CascadeAffectedLaw.pending_for_session(session_id) do
      {:ok, entries} ->
        {reparse, enacting} = Enum.split_with(entries, &(&1.update_type == :reparse))

        %{
          reparse: Enum.map(reparse, & &1.affected_law),
          enacting_link: Enum.map(enacting, & &1.affected_law)
        }

      {:error, _} ->
        %{reparse: [], enacting_link: []}
    end
  end

  # ============================================================================
  # DB-Backed Session Records (replaces JSON group files)
  # ============================================================================

  alias SertantaiLegal.Scraper.ScrapeSessionRecord

  @doc """
  Save a single session record to the database.

  Uses upsert to handle re-categorization without duplicates.

  ## Parameters
  - session_id: Session identifier
  - record: Map with at least :name key
  - group: :group1, :group2, or :group3

  ## Returns
  `{:ok, record}` or `{:error, reason}`
  """
  @spec save_session_record(String.t(), map(), atom()) ::
          {:ok, ScrapeSessionRecord.t()} | {:error, any()}
  def save_session_record(session_id, record, group) do
    law_name = record[:name] || record["name"]

    if is_nil(law_name) do
      {:error, "Record missing :name field"}
    else
      # Store full record data in parsed_data (scrape metadata)
      # This gets added to during subsequent parse stages
      parsed_data = record_to_parsed_data(record)

      ScrapeSessionRecord.create(%{
        session_id: session_id,
        law_name: law_name,
        group: group,
        status: :pending,
        selected: false,
        parsed_data: parsed_data
      })
    end
  end

  # Convert record map to parsed_data format for DB storage
  # Strips out transient fields, keeps all scrape metadata
  defp record_to_parsed_data(record) do
    record
    |> atomize_keys()
    |> Map.drop([:selected, :status, :parse_count])
    |> Enum.reject(fn {_k, v} -> is_nil(v) or v == "" or v == [] end)
    |> Enum.into(%{})
  end

  @doc """
  Save multiple session records to the database.

  ## Parameters
  - session_id: Session identifier
  - records: List of record maps
  - group: :group1, :group2, or :group3

  ## Returns
  `{:ok, count}` with number of records saved, or `{:error, reason}`
  """
  @spec save_session_records(String.t(), list(map()), atom()) ::
          {:ok, integer()} | {:error, any()}
  def save_session_records(session_id, records, group) do
    results =
      Enum.map(records, fn record ->
        save_session_record(session_id, record, group)
      end)

    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.empty?(errors) do
      {:ok, length(results)}
    else
      {:error, "Failed to save #{length(errors)} records: #{inspect(Enum.take(errors, 3))}"}
    end
  end

  @doc """
  Read session records from database for a group.

  Returns records in same format as JSON (list of maps with atom keys).
  Falls back to JSON file if no DB records found (backwards compatibility).

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3

  ## Returns
  `{:ok, records}` or `{:error, reason}`
  """
  @spec read_session_records(String.t(), atom()) :: {:ok, list(map())} | {:error, any()}
  def read_session_records(session_id, group) do
    case read_session_records_with_source(session_id, group) do
      {:ok, records, _source} -> {:ok, records}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Read session records for a specific group, returning both records and data source.

  Tries DB first, falls back to JSON for backwards compatibility.

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3

  ## Returns
  `{:ok, records, source}` where source is "db" or "json", or `{:error, reason}`
  """
  @spec read_session_records_with_source(String.t(), atom()) ::
          {:ok, list(map()), String.t()} | {:error, any()}
  def read_session_records_with_source(session_id, group) do
    case ScrapeSessionRecord.by_session_and_group(session_id, group) do
      {:ok, db_records} when db_records != [] ->
        # Convert DB records to map format for compatibility
        records = Enum.map(db_records, &session_record_to_map/1)
        {:ok, records, "db"}

      {:ok, []} ->
        # Fall back to JSON file for backwards compatibility
        case read_json(session_id, group) do
          {:ok, records} -> {:ok, records, "json"}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get a specific session record by session and law name.

  ## Returns
  `{:ok, record}` or `{:ok, nil}` if not found
  """
  @spec get_session_record(String.t(), String.t()) ::
          {:ok, ScrapeSessionRecord.t() | nil} | {:error, any()}
  def get_session_record(session_id, law_name) do
    ScrapeSessionRecord.by_session_and_name(session_id, law_name)
  end

  @doc """
  Update parsed data for a session record.

  ## Parameters
  - session_id: Session identifier
  - law_name: Law name
  - parsed_data: Full ParsedLaw output as map

  ## Returns
  `{:ok, record}` or `{:error, reason}`
  """
  @spec update_session_record_parsed(String.t(), String.t(), map()) ::
          {:ok, ScrapeSessionRecord.t()} | {:error, any()}
  def update_session_record_parsed(session_id, law_name, parsed_data) do
    case get_session_record(session_id, law_name) do
      {:ok, nil} ->
        {:error, "Record not found: #{law_name}"}

      {:ok, record} ->
        ScrapeSessionRecord.mark_parsed(record, %{parsed_data: parsed_data})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Mark a session record as confirmed (persisted to uk_lrt).

  ## Returns
  `{:ok, record}` or `{:error, reason}`
  """
  @spec confirm_session_record(String.t(), String.t()) ::
          {:ok, ScrapeSessionRecord.t()} | {:error, any()}
  def confirm_session_record(session_id, law_name) do
    case get_session_record(session_id, law_name) do
      {:ok, nil} ->
        {:error, "Record not found: #{law_name}"}

      {:ok, record} ->
        ScrapeSessionRecord.mark_confirmed(record)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Update selection state for records in DB.

  ## Parameters
  - session_id: Session identifier
  - group: :group1, :group2, or :group3
  - names: List of law names to update
  - selected: Boolean selection state

  ## Returns
  `{:ok, count}` with number updated, or `{:error, reason}`
  """
  @spec update_selection_db(String.t(), atom(), list(String.t()), boolean()) ::
          {:ok, integer()} | {:error, any()}
  def update_selection_db(session_id, group, names, selected) do
    # Get records matching the names in this group
    case ScrapeSessionRecord.by_session_and_group(session_id, group) do
      {:ok, records} ->
        names_set = MapSet.new(names)

        updates =
          records
          |> Enum.filter(fn r -> MapSet.member?(names_set, r.law_name) end)
          |> Enum.map(fn r -> ScrapeSessionRecord.set_selected(r, %{selected: selected}) end)

        errors = Enum.filter(updates, &match?({:error, _}, &1))

        if Enum.empty?(errors) do
          {:ok, length(updates)}
        else
          {:error, "Failed to update some records"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get selected record names from DB.

  ## Returns
  `{:ok, names}` list of selected law names
  """
  @spec get_selected_db(String.t(), atom()) :: {:ok, list(String.t())} | {:error, any()}
  def get_selected_db(session_id, group) do
    case ScrapeSessionRecord.selected_in_group(session_id, group) do
      {:ok, records} ->
        {:ok, Enum.map(records, & &1.law_name)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get count of records per status for a session.

  ## Returns
  Map with status counts: %{pending: n, parsed: n, confirmed: n, skipped: n}
  """
  @spec session_record_counts(String.t()) :: map()
  def session_record_counts(session_id) do
    case ScrapeSessionRecord.by_session(session_id) do
      {:ok, records} ->
        records
        |> Enum.group_by(& &1.status)
        |> Enum.map(fn {status, recs} -> {status, length(recs)} end)
        |> Enum.into(%{pending: 0, parsed: 0, confirmed: 0, skipped: 0})

      {:error, _} ->
        %{pending: 0, parsed: 0, confirmed: 0, skipped: 0}
    end
  end

  # Convert a ScrapeSessionRecord to a map format compatible with existing code
  defp session_record_to_map(%ScrapeSessionRecord{} = record) do
    base = %{
      name: record.law_name,
      selected: record.selected,
      status: record.status,
      parse_count: record.parse_count
    }

    # Merge in parsed_data if present
    if record.parsed_data do
      Map.merge(base, atomize_keys(record.parsed_data))
    else
      base
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end
end
