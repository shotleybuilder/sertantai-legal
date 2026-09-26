defmodule SertantaiLegal.Zenoh.LatRenames do
  @moduledoc """
  Payloads for the section_id rename map queryables (fractalatai #62):

      fractalaw/@{tenant}/data/legislation/lat-renames/{law_name}
      fractalaw/@{tenant}/data/legislation/lat-renames/*
      …?since=<ISO-8601>   (optional; created_at strictly after)

  Rows from `lat_section_id_renames`, oldest first: `law_name,
  old_section_id, new_section_id` (nil unless renamed), `status` (renamed |
  ambiguous | dropped), `match` (unique_text | ordered_text), `reparse_id`,
  `created_at`. Kept indefinitely. Fractalaw applies these before its own
  text matching when a law's `lat_hash` changes.

  Arrow IPC by default, JSON with `?format=json`, as for `LatManifest`.
  """

  alias SertantaiLegal.Repo

  @doc "Parse the key suffix after `lat-renames/`."
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

  @doc "Rename-map payload for a target in `:json` or `:arrow`."
  @spec fetch(:all | {:law, String.t()}, :json | :arrow, DateTime.t() | nil) ::
          {:ok, binary()} | {:error, term()}
  def fetch(target, format, since) do
    {where, params} = conditions(target, since)

    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, old_section_id, new_section_id, status, match, reparse_id::text, created_at
        FROM lat_section_id_renames #{where}
        ORDER BY created_at, id
        """,
        params
      )

    entries =
      Enum.map(rows, fn [law, old, new, status, match, reparse, at] ->
        %{
          law_name: law,
          old_section_id: old,
          new_section_id: new,
          status: status,
          match: match,
          reparse_id: reparse,
          created_at: at
        }
      end)

    encode(entries, format)
  end

  defp conditions(target, since) do
    {clauses, params} =
      case target do
        {:law, law} -> {["law_name = $1"], [law]}
        :all -> {[], []}
      end

    {clauses, params} =
      if since,
        do: {clauses ++ ["created_at > $#{length(params) + 1}"], params ++ [since]},
        else: {clauses, params}

    where = if clauses == [], do: "", else: "WHERE " <> Enum.join(clauses, " AND ")
    {where, params}
  end

  defp encode(entries, :json), do: {:ok, Jason.encode!(entries)}
  defp encode([], :arrow), do: {:ok, <<>>}

  defp encode(entries, :arrow) do
    ~w(law_name old_section_id new_section_id status match reparse_id created_at)a
    |> Map.new(fn col -> {col, Enum.map(entries, &Map.fetch!(&1, col))} end)
    |> Explorer.DataFrame.new()
    |> Explorer.DataFrame.dump_ipc_stream()
  end
end
