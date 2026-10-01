defmodule SertantaiLegal.Zenoh.LatChanges do
  @moduledoc """
  Payloads for the per-row LAT change log queryables (#167, L8.5):
      fractalaw/@{tenant}/data/legislation/lat-changes/{law_name}
      fractalaw/@{tenant}/data/legislation/lat-changes/*
      …?since=<ISO-8601>   (optional; created_at strictly after)
  Rows from `lat_changes`, oldest first: `id` (stable entry id; fractalaw
  keys provision_versions on it, #167 D5), `law_name, op_key, section_id,
  old_section_id, change` (text_changed | inserted | removed | renamed |
  status_changed), `cause` (per row: legislative | parser | scope |
  correction | unattributed), `change_ids` (the evidencing notes), plus the
  parse's `op_cause` and `source_hash` (from its `parsed` lat_event), and
  `created_at`. Kept indefinitely. Fractalaw versions only `legislative` rows.
  Arrow IPC by default, JSON with `?format=json`, as for `LatRenames`.
  """

  alias SertantaiLegal.Repo

  @doc "Parse the key suffix after `lat-changes/`."
  @spec target(String.t()) :: :all | {:law, String.t()}
  def target(suffix) when suffix in ["*", "**"], do: :all
  def target(law_name), do: {:law, law_name}

  @doc "The `since` timestamp from Zenoh query parameters, if present and valid."
  @spec parse_since(String.t() | nil) :: DateTime.t() | nil
  def parse_since(params) when is_binary(params) do
    with %{"since" => ts} <- URI.decode_query(params),
         {:ok, dt, _} <- DateTime.from_iso8601(ts) do
      dt
    else
      _ -> nil
    end
  end

  def parse_since(_), do: nil

  @doc "Change-log payload for a target in `:json` or `:arrow`."
  @spec fetch(:all | {:law, String.t()}, :json | :arrow, DateTime.t() | nil) ::
          {:ok, binary()} | {:error, term()}
  def fetch(target, format, since) do
    {where, params} = conditions(target, since)

    %{rows: rows} =
      Repo.query!(
        """
        SELECT c.id, c.law_name, c.op_key, c.section_id, c.old_section_id, c.change, c.cause,
               c.change_ids, e.cause, e.source_hash, c.created_at
        FROM lat_changes c
        LEFT JOIN lat_events e ON e.op_key = c.op_key AND e.event = 'parsed' AND e.law_name = c.law_name
        #{where}
        ORDER BY c.created_at, c.id
        """,
        params
      )

    entries =
      Enum.map(rows, fn [id, law, op, sid, old, change, cause, ids, op_cause, hash, at] ->
        %{
          id: id,
          law_name: law,
          op_key: op,
          section_id: sid,
          old_section_id: old,
          change: change,
          cause: cause,
          change_ids: ids,
          op_cause: op_cause,
          source_hash: hash,
          created_at: at
        }
      end)

    encode(entries, format)
  end

  defp conditions(target, since) do
    {clauses, params} =
      case target do
        {:law, law} -> {["c.law_name = $1"], [law]}
        :all -> {[], []}
      end

    {clauses, params} =
      if since,
        do: {clauses ++ ["c.created_at > $#{length(params) + 1}"], params ++ [since]},
        else: {clauses, params}

    where = if clauses == [], do: "", else: "WHERE " <> Enum.join(clauses, " AND ")
    {where, params}
  end

  defp encode(entries, :json), do: {:ok, Jason.encode!(entries)}
  defp encode([], :arrow), do: {:ok, <<>>}

  defp encode(entries, :arrow) do
    ~w(id law_name op_key section_id old_section_id change cause change_ids op_cause source_hash created_at)a
    |> Map.new(fn col -> {col, Enum.map(entries, &Map.fetch!(&1, col))} end)
    |> Explorer.DataFrame.new()
    |> Explorer.DataFrame.dump_ipc_stream()
  end
end
