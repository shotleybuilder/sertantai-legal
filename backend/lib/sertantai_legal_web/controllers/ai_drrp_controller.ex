defmodule SertantaiLegalWeb.AiDrrpController do
  @moduledoc """
  AI service endpoints for DRRP clause processing.

  Serves the queue of DRRP entries that need AI clause refinement.
  The AI service pulls work items from `GET /api/ai/drrp/clause/queue`
  and we pull completed results from the AI service (Phase 2).
  """

  use SertantaiLegalWeb, :controller

  @default_limit 100
  @max_limit 500
  @default_threshold 0.7

  @drrp_columns ~w(duties responsibilities rights powers)

  # Build the UNION ALL subquery at compile time from @drrp_columns
  @union_sql Enum.map_join(@drrp_columns, "\nUNION ALL\n", fn col ->
               """
               SELECT u.id, u.name, u.updated_at, '#{col}' AS drrp_column,
                 e.ordinality AS entry_index,
                 e.val->>'article' AS article,
                 e.val->>'duty_type' AS duty_type,
                 e.val->>'holder' AS holder,
                 e.val->>'clause' AS clause,
                 (e.val->>'regex_clause_confidence')::float AS confidence,
                 e.val->>'ai_clause' AS ai_clause
               FROM uk_lrt u,
                 LATERAL jsonb_array_elements(u.#{col}->'entries')
                   WITH ORDINALITY AS e(val, ordinality)
               WHERE u.#{col} IS NOT NULL
                 AND jsonb_array_length(u.#{col}->'entries') > 0
               """
             end)

  @queue_sql """
  WITH drrp_entries AS (
    #{@union_sql}
  )
  SELECT
    id::text AS law_id, name AS law_name, article AS provision,
    LOWER(duty_type) AS drrp_type, holder, clause AS regex_clause,
    confidence, drrp_column, entry_index::integer,
    updated_at AS scraped_at
  FROM drrp_entries
  WHERE (confidence IS NULL OR confidence < $1) AND ai_clause IS NULL
  ORDER BY name, drrp_column, entry_index
  LIMIT $2 OFFSET $3
  """

  @count_sql """
  WITH drrp_entries AS (
    #{@union_sql}
  )
  SELECT COUNT(*) FROM drrp_entries
  WHERE (confidence IS NULL OR confidence < $1) AND ai_clause IS NULL
  """

  def queue(conn, params) do
    limit = min(parse_integer(params["limit"], @default_limit), @max_limit)
    offset = parse_integer(params["offset"], 0)
    threshold = parse_float(params["threshold"], @default_threshold)

    with {:ok, %{rows: rows, columns: columns}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, @queue_sql, [threshold, limit, offset]),
         {:ok, %{rows: [[total_count]]}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, @count_sql, [threshold]) do
      items =
        Enum.map(rows, fn row ->
          columns |> Enum.zip(row) |> Map.new() |> entry_to_json()
        end)

      json(conn, %{
        items: items,
        count: length(items),
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: offset + limit < total_count,
        threshold: threshold
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Query failed", reason: inspect(reason)})
    end
  end

  defp entry_to_json(row) do
    %{
      law_id: row["law_id"],
      law_name: row["law_name"],
      provision: row["provision"],
      drrp_type: row["drrp_type"],
      holder: row["holder"],
      regex_clause: row["regex_clause"],
      confidence: row["confidence"],
      drrp_column: row["drrp_column"],
      entry_index: row["entry_index"],
      scraped_at: format_datetime(row["scraped_at"])
    }
  end

  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(nil), do: nil
  defp format_datetime(dt), do: to_string(dt)

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 -> int
      _ -> default
    end
  end

  defp parse_integer(value, _default) when is_integer(value) and value >= 0, do: value
  defp parse_integer(_, default), do: default

  defp parse_float(nil, default), do: default

  defp parse_float(value, default) when is_binary(value) do
    case Float.parse(value) do
      {f, ""} when f >= 0.0 and f <= 1.0 -> f
      _ -> default
    end
  end

  defp parse_float(value, _default) when is_float(value) and value >= 0.0 and value <= 1.0,
    do: value

  defp parse_float(_, default), do: default
end
