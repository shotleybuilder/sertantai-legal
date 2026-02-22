defmodule SertantaiLegalWeb.AiSyncController do
  @moduledoc """
  AI service sync endpoints for LAT and AmendmentAnnotation data.

  Pull-based incremental sync — the AI service periodically polls these
  endpoints with a `since` timestamp to get new/changed records for
  embedding generation in LanceDB.

  ## Endpoints

    - `GET /api/ai/sync/lat` — Legal Articles Table rows
    - `GET /api/ai/sync/annotations` — Amendment annotation rows

  ## Authentication

  Machine-to-machine via `X-API-Key` header (same as DRRP clause queue).
  """

  use SertantaiLegalWeb, :controller

  @default_limit 500
  @max_limit 2000
  @default_days 30

  # ── LAT Sync ─────────────────────────────────────────────────────

  @lat_sql """
  SELECT
    l.section_id, l.law_name, l.law_id::text,
    u.title_en AS law_title, u.type_code AS law_type_code, u.year AS law_year,
    l.section_type, l.part, l.chapter, l.heading_group, l.provision,
    l.paragraph, l.sub_paragraph, l.schedule,
    l.text, l.language, l.extent_code,
    l.sort_key, l.position, l.depth, l.hierarchy_path,
    l.amendment_count, l.modification_count, l.commencement_count,
    l.extent_count, l.editorial_count,
    l.created_at, l.updated_at
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  WHERE l.updated_at >= $1
  ORDER BY l.updated_at ASC, l.section_id ASC
  LIMIT $2 OFFSET $3
  """

  @lat_count_sql """
  SELECT COUNT(*)
  FROM lat l
  WHERE l.updated_at >= $1
  """

  @lat_sql_by_law """
  SELECT
    l.section_id, l.law_name, l.law_id::text,
    u.title_en AS law_title, u.type_code AS law_type_code, u.year AS law_year,
    l.section_type, l.part, l.chapter, l.heading_group, l.provision,
    l.paragraph, l.sub_paragraph, l.schedule,
    l.text, l.language, l.extent_code,
    l.sort_key, l.position, l.depth, l.hierarchy_path,
    l.amendment_count, l.modification_count, l.commencement_count,
    l.extent_count, l.editorial_count,
    l.created_at, l.updated_at
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  WHERE l.updated_at >= $1 AND l.law_name = ANY($4)
  ORDER BY l.updated_at ASC, l.section_id ASC
  LIMIT $2 OFFSET $3
  """

  @lat_count_sql_by_law """
  SELECT COUNT(*)
  FROM lat l
  WHERE l.updated_at >= $1 AND l.law_name = ANY($2)
  """

  def lat(conn, params) do
    limit = min(parse_integer(params["limit"], @default_limit), @max_limit)
    offset = parse_integer(params["offset"], 0)
    since = parse_datetime(params["since"])
    law_names = parse_law_names(params)

    {sql, count_sql, query_params, count_params} =
      if law_names == [] do
        {@lat_sql, @lat_count_sql, [since, limit, offset], [since]}
      else
        {@lat_sql_by_law, @lat_count_sql_by_law, [since, limit, offset, law_names],
         [since, law_names]}
      end

    with {:ok, %{rows: rows, columns: columns}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, sql, query_params),
         {:ok, %{rows: [[total_count]]}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, count_sql, count_params) do
      items =
        Enum.map(rows, fn row ->
          columns |> Enum.zip(row) |> Map.new() |> lat_to_json()
        end)

      json(conn, %{
        items: items,
        count: length(items),
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: offset + limit < total_count,
        since: format_datetime(since),
        sync_timestamp: format_datetime(DateTime.utc_now())
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Query failed", reason: inspect(reason)})
    end
  end

  # ── Annotations Sync ─────────────────────────────────────────────

  @ann_sql """
  SELECT
    a.id, a.law_name, a.law_id::text, u.title_en AS law_title,
    a.code, a.code_type, a.source, a.text, a.affected_sections,
    a.created_at, a.updated_at
  FROM amendment_annotations a
  JOIN uk_lrt u ON u.id = a.law_id
  WHERE a.updated_at >= $1
  ORDER BY a.updated_at ASC, a.id ASC
  LIMIT $2 OFFSET $3
  """

  @ann_count_sql """
  SELECT COUNT(*)
  FROM amendment_annotations a
  WHERE a.updated_at >= $1
  """

  @ann_sql_by_law """
  SELECT
    a.id, a.law_name, a.law_id::text, u.title_en AS law_title,
    a.code, a.code_type, a.source, a.text, a.affected_sections,
    a.created_at, a.updated_at
  FROM amendment_annotations a
  JOIN uk_lrt u ON u.id = a.law_id
  WHERE a.updated_at >= $1 AND a.law_name = ANY($4)
  ORDER BY a.updated_at ASC, a.id ASC
  LIMIT $2 OFFSET $3
  """

  @ann_count_sql_by_law """
  SELECT COUNT(*)
  FROM amendment_annotations a
  WHERE a.updated_at >= $1 AND a.law_name = ANY($2)
  """

  def annotations(conn, params) do
    limit = min(parse_integer(params["limit"], @default_limit), @max_limit)
    offset = parse_integer(params["offset"], 0)
    since = parse_datetime(params["since"])
    law_names = parse_law_names(params)

    {sql, count_sql, query_params, count_params} =
      if law_names == [] do
        {@ann_sql, @ann_count_sql, [since, limit, offset], [since]}
      else
        {@ann_sql_by_law, @ann_count_sql_by_law, [since, limit, offset, law_names],
         [since, law_names]}
      end

    with {:ok, %{rows: rows, columns: columns}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, sql, query_params),
         {:ok, %{rows: [[total_count]]}} <-
           Ecto.Adapters.SQL.query(SertantaiLegal.Repo, count_sql, count_params) do
      items =
        Enum.map(rows, fn row ->
          columns |> Enum.zip(row) |> Map.new() |> annotation_to_json()
        end)

      json(conn, %{
        items: items,
        count: length(items),
        total_count: total_count,
        limit: limit,
        offset: offset,
        has_more: offset + limit < total_count,
        since: format_datetime(since),
        sync_timestamp: format_datetime(DateTime.utc_now())
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Query failed", reason: inspect(reason)})
    end
  end

  # ── JSON Mappers ─────────────────────────────────────────────────

  defp lat_to_json(row) do
    %{
      section_id: row["section_id"],
      law_name: row["law_name"],
      law_id: row["law_id"],
      law_title: row["law_title"],
      law_type_code: row["law_type_code"],
      law_year: row["law_year"],
      section_type: row["section_type"],
      part: row["part"],
      chapter: row["chapter"],
      heading_group: row["heading_group"],
      provision: row["provision"],
      paragraph: row["paragraph"],
      sub_paragraph: row["sub_paragraph"],
      schedule: row["schedule"],
      text: row["text"],
      language: row["language"],
      extent_code: row["extent_code"],
      sort_key: row["sort_key"],
      position: row["position"],
      depth: row["depth"],
      hierarchy_path: row["hierarchy_path"],
      amendment_count: row["amendment_count"],
      modification_count: row["modification_count"],
      commencement_count: row["commencement_count"],
      extent_count: row["extent_count"],
      editorial_count: row["editorial_count"],
      created_at: format_datetime(row["created_at"]),
      updated_at: format_datetime(row["updated_at"])
    }
  end

  defp annotation_to_json(row) do
    %{
      id: row["id"],
      law_name: row["law_name"],
      law_id: row["law_id"],
      law_title: row["law_title"],
      code: row["code"],
      code_type: row["code_type"],
      source: row["source"],
      text: row["text"],
      affected_sections: row["affected_sections"],
      created_at: format_datetime(row["created_at"]),
      updated_at: format_datetime(row["updated_at"])
    }
  end

  # ── Helpers ──────────────────────────────────────────────────────

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

  defp parse_datetime(nil), do: default_since()
  defp parse_datetime(""), do: default_since()

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        dt

      {:error, _} ->
        # Try NaiveDateTime (no timezone)
        case NaiveDateTime.from_iso8601(value) do
          {:ok, ndt} -> DateTime.from_naive!(ndt, "Etc/UTC")
          {:error, _} -> default_since()
        end
    end
  end

  defp parse_datetime(_), do: default_since()

  defp default_since do
    DateTime.utc_now() |> DateTime.add(-@default_days * 86_400, :second)
  end

  defp parse_law_names(params) do
    case params do
      %{"law_name" => names} when is_list(names) ->
        names |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

      %{"law_name" => name} when is_binary(name) and name != "" ->
        [String.trim(name)]

      _ ->
        []
    end
  end
end
