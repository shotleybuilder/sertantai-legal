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

  @doc """
  Add affected laws from a persisted record to the session's affected_laws.json.

  Collects laws from `amending` and `rescinding` fields and deduplicates.

  ## Parameters
  - session_id: Session identifier
  - source_law: The law that was persisted (name, e.g., "uksi/2024/123")
  - amending: List of law IDs this law amends
  - rescinding: List of law IDs this law rescinds

  ## Returns
  `:ok` or `{:error, reason}`
  """
  @spec add_affected_laws(String.t(), String.t(), list(String.t()), list(String.t())) ::
          :ok | {:error, any()}
  def add_affected_laws(session_id, source_law, amending, rescinding) do
    amending = amending || []
    rescinding = rescinding || []

    # Skip if no affected laws
    if amending == [] and rescinding == [] do
      :ok
    else
      # Read existing affected laws or initialize
      existing = read_affected_laws(session_id)

      # Build new entry
      new_entry = %{
        source_law: source_law,
        amending: amending,
        rescinding: rescinding,
        added_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      # Merge: append new entry, collect unique affected laws
      updated = %{
        entries: (existing[:entries] || []) ++ [new_entry],
        all_amending: Enum.uniq((existing[:all_amending] || []) ++ amending),
        all_rescinding: Enum.uniq((existing[:all_rescinding] || []) ++ rescinding),
        updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      save_json(session_id, :affected_laws, updated)
    end
  end

  @doc """
  Read affected laws from a session.

  ## Returns
  Map with :entries, :all_amending, :all_rescinding keys, or empty map if not found.
  """
  @spec read_affected_laws(String.t()) :: map()
  def read_affected_laws(session_id) do
    case read_json(session_id, :affected_laws) do
      {:ok, data} -> data
      {:error, _} -> %{entries: [], all_amending: [], all_rescinding: []}
    end
  end

  @doc """
  Get summary of affected laws for cascade update UI.

  ## Returns
  Map with counts and lists of affected laws.
  """
  @spec get_affected_laws_summary(String.t()) :: map()
  def get_affected_laws_summary(session_id) do
    data = read_affected_laws(session_id)

    all_affected =
      Enum.uniq((data[:all_amending] || []) ++ (data[:all_rescinding] || []))

    %{
      source_laws: Enum.map(data[:entries] || [], & &1[:source_law]),
      source_count: length(data[:entries] || []),
      amending: data[:all_amending] || [],
      amending_count: length(data[:all_amending] || []),
      rescinding: data[:all_rescinding] || [],
      rescinding_count: length(data[:all_rescinding] || []),
      all_affected: all_affected,
      all_affected_count: length(all_affected)
    }
  end

  @doc """
  Clear affected laws for a session (after cascade update is complete).
  """
  @spec clear_affected_laws(String.t()) :: :ok | {:error, any()}
  def clear_affected_laws(session_id) do
    path = file_path(session_id, :affected_laws)

    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, "Failed to clear affected laws: #{inspect(reason)}"}
    end
  end
end
