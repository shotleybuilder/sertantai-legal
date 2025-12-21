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
end
