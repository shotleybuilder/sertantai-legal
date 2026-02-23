defmodule SertantaiLegalWeb.LatAdminController do
  @moduledoc """
  Admin endpoints for browsing LAT (Legal Articles Table) data and
  amendment annotations, plus triggering re-parses.

  ## Endpoints

    - `GET /api/lat/stats` — Aggregate statistics
    - `GET /api/lat/queue` — LRT records needing LAT parsing (missing or stale)
    - `GET /api/lat/laws` — List laws with LAT/annotation counts
    - `GET /api/lat/laws/:law_name` — LAT rows for a specific law
    - `GET /api/lat/laws/:law_name/annotations` — Annotations for a specific law
    - `POST /api/lat/laws/:law_name/reparse` — Trigger LAT + commentary re-parse
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatReparser

  @default_limit 500
  @max_limit 5000

  # ── Stats ──────────────────────────────────────────────────────────

  @stats_sql """
  SELECT
    (SELECT COUNT(*) FROM lat) AS total_lat_rows,
    (SELECT COUNT(DISTINCT law_name) FROM lat) AS laws_with_lat,
    (SELECT COUNT(*) FROM amendment_annotations) AS total_annotations,
    (SELECT COUNT(DISTINCT law_name) FROM amendment_annotations) AS laws_with_annotations
  """

  @section_type_counts_sql """
  SELECT section_type, COUNT(*) AS count
  FROM lat
  GROUP BY section_type
  ORDER BY count DESC
  """

  @code_type_counts_sql """
  SELECT code_type, COUNT(*) AS count
  FROM amendment_annotations
  GROUP BY code_type
  ORDER BY count DESC
  """

  def stats(conn, _params) do
    {:ok, %{columns: cols, rows: [row]}} = Repo.query(@stats_sql)
    stats = Enum.zip(cols, row) |> Map.new()

    {:ok, %{rows: section_rows}} = Repo.query(@section_type_counts_sql)
    section_type_counts = Map.new(section_rows, fn [type, count] -> {type, count} end)

    {:ok, %{rows: code_rows}} = Repo.query(@code_type_counts_sql)
    code_type_counts = Map.new(code_rows, fn [type, count] -> {type, count} end)

    json(conn, %{
      total_lat_rows: stats["total_lat_rows"],
      laws_with_lat: stats["laws_with_lat"],
      total_annotations: stats["total_annotations"],
      laws_with_annotations: stats["laws_with_annotations"],
      section_type_counts: section_type_counts,
      code_type_counts: code_type_counts
    })
  end

  # ── Queue — LRT records needing LAT parsing ─────────────────────────

  @queue_base_select """
  SELECT
    u.id::text AS law_id, u.name AS law_name, u.title_en, u.year,
    u.type_code, u.updated_at AS lrt_updated_at,
    COALESCE(lat_agg.lat_count, 0) AS lat_count,
    lat_agg.latest_lat_updated_at,
    CASE WHEN COALESCE(lat_agg.lat_count, 0) = 0 THEN 'missing'
         ELSE 'stale' END AS queue_reason
  FROM uk_lrt u
  LEFT JOIN (
    SELECT law_id, COUNT(*) AS lat_count, MAX(updated_at) AS latest_lat_updated_at
    FROM lat GROUP BY law_id
  ) lat_agg ON lat_agg.law_id = u.id
  """

  @queue_sql @queue_base_select <>
               """
               WHERE u.is_making = true
                 AND (COALESCE(lat_agg.lat_count, 0) = 0
                      OR u.updated_at > lat_agg.latest_lat_updated_at + INTERVAL '6 months')
               ORDER BY u.updated_at ASC
               LIMIT $1 OFFSET $2
               """

  @queue_missing_sql @queue_base_select <>
                       """
                       WHERE u.is_making = true
                         AND COALESCE(lat_agg.lat_count, 0) = 0
                       ORDER BY u.updated_at ASC
                       LIMIT $1 OFFSET $2
                       """

  @queue_stale_sql @queue_base_select <>
                     """
                     WHERE u.is_making = true
                       AND lat_agg.lat_count > 0
                       AND u.updated_at > lat_agg.latest_lat_updated_at + INTERVAL '6 months'
                     ORDER BY u.updated_at ASC
                     LIMIT $1 OFFSET $2
                     """

  @queue_count_sql """
  SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE COALESCE(lat_agg.lat_count, 0) = 0) AS missing_count,
    COUNT(*) FILTER (WHERE lat_agg.lat_count > 0
      AND u.updated_at > lat_agg.latest_lat_updated_at + INTERVAL '6 months') AS stale_count
  FROM uk_lrt u
  LEFT JOIN (
    SELECT law_id, COUNT(*) AS lat_count, MAX(updated_at) AS latest_lat_updated_at
    FROM lat GROUP BY law_id
  ) lat_agg ON lat_agg.law_id = u.id
  WHERE u.is_making = true
    AND (COALESCE(lat_agg.lat_count, 0) = 0
         OR u.updated_at > lat_agg.latest_lat_updated_at + INTERVAL '6 months')
  """

  def queue(conn, params) do
    limit = parse_limit(params["limit"])
    offset = parse_offset(params["offset"])
    reason = params["reason"]

    # Always fetch unfiltered counts for the stats bar
    {:ok, %{columns: count_cols, rows: [count_row]}} = Repo.query(@queue_count_sql)
    counts = Enum.zip(count_cols, count_row) |> Map.new()

    # Fetch paginated items, optionally filtered by reason
    {sql, args} =
      case reason do
        "missing" -> {@queue_missing_sql, [limit, offset]}
        "stale" -> {@queue_stale_sql, [limit, offset]}
        _ -> {@queue_sql, [limit, offset]}
      end

    {:ok, %{columns: cols, rows: rows}} = Repo.query(sql, args)

    items =
      Enum.map(rows, fn row ->
        Enum.zip(cols, row)
        |> Map.new()
        |> maybe_format_timestamp("lrt_updated_at")
        |> maybe_format_timestamp("latest_lat_updated_at")
      end)

    filtered_total =
      case reason do
        "missing" -> counts["missing_count"]
        "stale" -> counts["stale_count"]
        _ -> counts["total"]
      end

    json(conn, %{
      items: items,
      count: length(items),
      total: counts["total"],
      missing_count: counts["missing_count"],
      stale_count: counts["stale_count"],
      filtered_total: filtered_total,
      limit: limit,
      offset: offset,
      has_more: offset + limit < filtered_total
    })
  end

  # ── Laws list ──────────────────────────────────────────────────────

  @laws_sql """
  SELECT
    l.law_name,
    u.id::text AS law_id,
    u.title_en,
    u.year,
    u.type_code,
    COUNT(l.section_id) AS lat_count,
    COALESCE(a.annotation_count, 0) AS annotation_count
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  LEFT JOIN (
    SELECT law_name, COUNT(*) AS annotation_count
    FROM amendment_annotations
    GROUP BY law_name
  ) a ON a.law_name = l.law_name
  GROUP BY l.law_name, u.id, u.title_en, u.year, u.type_code, a.annotation_count
  ORDER BY u.year DESC, u.title_en ASC
  """

  @laws_search_sql """
  SELECT
    l.law_name,
    u.id::text AS law_id,
    u.title_en,
    u.year,
    u.type_code,
    COUNT(l.section_id) AS lat_count,
    COALESCE(a.annotation_count, 0) AS annotation_count
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  LEFT JOIN (
    SELECT law_name, COUNT(*) AS annotation_count
    FROM amendment_annotations
    GROUP BY law_name
  ) a ON a.law_name = l.law_name
  WHERE (u.title_en ILIKE $1 OR l.law_name ILIKE $1)
  GROUP BY l.law_name, u.id, u.title_en, u.year, u.type_code, a.annotation_count
  ORDER BY u.year DESC, u.title_en ASC
  """

  @laws_type_sql """
  SELECT
    l.law_name,
    u.id::text AS law_id,
    u.title_en,
    u.year,
    u.type_code,
    COUNT(l.section_id) AS lat_count,
    COALESCE(a.annotation_count, 0) AS annotation_count
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  LEFT JOIN (
    SELECT law_name, COUNT(*) AS annotation_count
    FROM amendment_annotations
    GROUP BY law_name
  ) a ON a.law_name = l.law_name
  WHERE u.type_code = $1
  GROUP BY l.law_name, u.id, u.title_en, u.year, u.type_code, a.annotation_count
  ORDER BY u.year DESC, u.title_en ASC
  """

  @laws_search_type_sql """
  SELECT
    l.law_name,
    u.id::text AS law_id,
    u.title_en,
    u.year,
    u.type_code,
    COUNT(l.section_id) AS lat_count,
    COALESCE(a.annotation_count, 0) AS annotation_count
  FROM lat l
  JOIN uk_lrt u ON u.id = l.law_id
  LEFT JOIN (
    SELECT law_name, COUNT(*) AS annotation_count
    FROM amendment_annotations
    GROUP BY law_name
  ) a ON a.law_name = l.law_name
  WHERE (u.title_en ILIKE $1 OR l.law_name ILIKE $1) AND u.type_code = $2
  GROUP BY l.law_name, u.id, u.title_en, u.year, u.type_code, a.annotation_count
  ORDER BY u.year DESC, u.title_en ASC
  """

  def laws(conn, params) do
    search = params["search"]
    type_code = params["type_code"]

    {sql, args} =
      case {search, type_code} do
        {nil, nil} ->
          {@laws_sql, []}

        {s, nil} when is_binary(s) and s != "" ->
          {@laws_search_sql, ["%#{s}%"]}

        {nil, t} when is_binary(t) and t != "" ->
          {@laws_type_sql, [t]}

        {s, t} when is_binary(s) and s != "" and is_binary(t) and t != "" ->
          {@laws_search_type_sql, ["%#{s}%", t]}

        _ ->
          {@laws_sql, []}
      end

    {:ok, %{columns: cols, rows: rows}} = Repo.query(sql, args)

    laws =
      Enum.map(rows, fn row ->
        Enum.zip(cols, row) |> Map.new()
      end)

    json(conn, %{laws: laws, count: length(laws)})
  end

  # ── LAT rows for a specific law ────────────────────────────────────

  @show_sql """
  SELECT
    l.section_id, l.law_name, l.law_id::text,
    l.section_type, l.sort_key, l.position, l.depth,
    l.part, l.chapter, l.heading_group, l.provision,
    l.paragraph, l.sub_paragraph, l.schedule,
    l.text, l.language, l.extent_code, l.hierarchy_path,
    l.amendment_count, l.modification_count,
    l.commencement_count, l.extent_count, l.editorial_count,
    l.created_at, l.updated_at
  FROM lat l
  WHERE l.law_name = $1
  ORDER BY l.sort_key ASC
  LIMIT $2 OFFSET $3
  """

  @show_count_sql """
  SELECT COUNT(*) FROM lat WHERE law_name = $1
  """

  def show(conn, %{"law_name" => law_name} = params) do
    limit = parse_limit(params["limit"])
    offset = parse_offset(params["offset"])

    {:ok, %{columns: cols, rows: rows}} = Repo.query(@show_sql, [law_name, limit, offset])
    {:ok, %{rows: [[total_count]]}} = Repo.query(@show_count_sql, [law_name])

    lat_rows =
      Enum.map(rows, fn row ->
        Enum.zip(cols, row)
        |> Map.new()
        |> format_timestamps()
      end)

    json(conn, %{
      law_name: law_name,
      rows: lat_rows,
      count: length(lat_rows),
      total_count: total_count,
      limit: limit,
      offset: offset,
      has_more: offset + limit < total_count
    })
  end

  # ── Annotations for a specific law ─────────────────────────────────

  @annotations_sql """
  SELECT
    a.id, a.law_name, a.law_id::text,
    a.code, a.code_type, a.source, a.text,
    a.affected_sections,
    a.created_at, a.updated_at
  FROM amendment_annotations a
  WHERE a.law_name = $1
  ORDER BY a.code_type ASC, a.id ASC
  """

  def annotations(conn, %{"law_name" => law_name}) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@annotations_sql, [law_name])

    annotations =
      Enum.map(rows, fn row ->
        Enum.zip(cols, row)
        |> Map.new()
        |> format_timestamps()
      end)

    json(conn, %{
      law_name: law_name,
      annotations: annotations,
      count: length(annotations)
    })
  end

  # ── Re-parse ───────────────────────────────────────────────────────

  def reparse(conn, %{"law_name" => law_name}) do
    case LatReparser.reparse(law_name) do
      {:ok, result} ->
        json(conn, %{
          law_name: law_name,
          lat: result.lat,
          annotations: result.annotations,
          duration_ms: result.duration_ms
        })

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{error: reason})
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────

  defp parse_limit(nil), do: @default_limit

  defp parse_limit(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> min(max(n, 1), @max_limit)
      :error -> @default_limit
    end
  end

  defp parse_limit(_), do: @default_limit

  defp parse_offset(nil), do: 0

  defp parse_offset(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> max(n, 0)
      :error -> 0
    end
  end

  defp parse_offset(_), do: 0

  defp format_timestamps(row) do
    row
    |> maybe_format_timestamp("created_at")
    |> maybe_format_timestamp("updated_at")
  end

  defp maybe_format_timestamp(row, key) do
    case Map.get(row, key) do
      %NaiveDateTime{} = dt -> Map.put(row, key, NaiveDateTime.to_iso8601(dt))
      %DateTime{} = dt -> Map.put(row, key, DateTime.to_iso8601(dt))
      _ -> row
    end
  end
end
