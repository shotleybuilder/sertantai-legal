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
  alias SertantaiLegal.Scraper.{LatReparser, LatSessionManager, LatStagedParser, Storage}
  alias SertantaiLegal.Scraper.{ScrapeSession, ScrapeSessionRecord}

  require Logger

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
    u.type_code, u.family, u.live,
    (SELECT jsonb_agg(k) FROM jsonb_object_keys(u.function) AS k) AS function,
    u.updated_at AS lrt_updated_at,
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

  @queue_exclusions """
  AND u.title_en IS NOT NULL
  AND u.family IS NOT NULL
  AND u.family NOT IN ('_todo', '🖤 X: No Family')
  """

  @queue_sql @queue_base_select <>
               """
               WHERE u.is_making = true #{@queue_exclusions}
                 AND (COALESCE(lat_agg.lat_count, 0) = 0
                      OR u.updated_at > lat_agg.latest_lat_updated_at + INTERVAL '6 months')
               ORDER BY u.updated_at ASC
               LIMIT $1 OFFSET $2
               """

  @queue_missing_sql @queue_base_select <>
                       """
                       WHERE u.is_making = true #{@queue_exclusions}
                         AND COALESCE(lat_agg.lat_count, 0) = 0
                       ORDER BY u.updated_at ASC
                       LIMIT $1 OFFSET $2
                       """

  @queue_stale_sql @queue_base_select <>
                     """
                     WHERE u.is_making = true #{@queue_exclusions}
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
  WHERE u.is_making = true #{@queue_exclusions}
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

  # ── LAT Session endpoints ──────────────────────────────────────────

  @doc "POST /api/lat/sessions/preview — Preview count of records matching filters."
  def lat_session_preview(conn, params) do
    case LatSessionManager.preview(params) do
      {:ok, result} -> json(conn, result)
      {:error, reason} -> conn |> put_status(:bad_request) |> json(%{error: reason})
    end
  end

  @doc "POST /api/lat/sessions — Create a LAT parse session from filters."
  def create_lat_session(conn, params) do
    case LatSessionManager.create(params) do
      {:ok, session} ->
        json(conn, %{
          session_id: session.session_id,
          session_type: session.session_type,
          status: session.status,
          group1_count: session.group1_count
        })

      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: reason})
    end
  end

  @doc "GET /api/lat/sessions — List recent LAT parse sessions."
  def lat_sessions(conn, _params) do
    case ScrapeSession.recent_by_type("lat_parse") do
      {:ok, sessions} ->
        json(conn, %{sessions: Enum.map(sessions, &session_to_json/1)})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  @doc "GET /api/lat/sessions/:id — Get a single LAT session by session_id."
  def lat_session_show(conn, %{"id" => session_id}) do
    case ScrapeSession.by_session_id(session_id) do
      {:ok, session} ->
        json(conn, session_to_json(session))

      {:error, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Session not found"})
    end
  end

  @doc "GET /api/lat/sessions/:id/records — Get records for a LAT session."
  def lat_session_records(conn, %{"id" => session_id}) do
    case Storage.read_session_records(session_id, :group1) do
      {:ok, records} ->
        enriched =
          Enum.map(records, fn record ->
            # Merge DB record fields (status, lat results) with stored data
            case Storage.get_session_record(session_id, record["name"] || record[:name]) do
              {:ok, db_record} when not is_nil(db_record) ->
                %{
                  law_name: db_record.law_name,
                  title_en: record["Title_EN"] || record[:Title_EN] || "",
                  type_code: record["type_code"] || record[:type_code] || "",
                  year: record["Year"] || record[:Year],
                  family: record["family"] || record[:family] || "",
                  status: db_record.status,
                  selected: db_record.selected,
                  lat_inserted: db_record.lat_inserted,
                  lat_deleted: db_record.lat_deleted,
                  annotations_inserted: db_record.annotations_inserted,
                  parse_duration_ms: db_record.parse_duration_ms,
                  parse_error: db_record.parse_error,
                  parse_count: db_record.parse_count
                }

              _ ->
                %{
                  law_name: record["name"] || record[:name],
                  title_en: record["Title_EN"] || record[:Title_EN] || "",
                  type_code: record["type_code"] || record[:type_code] || "",
                  year: record["Year"] || record[:Year],
                  family: record["family"] || record[:family] || "",
                  status: :pending,
                  selected: false,
                  lat_inserted: nil,
                  lat_deleted: nil,
                  annotations_inserted: nil,
                  parse_duration_ms: nil,
                  parse_error: nil,
                  parse_count: 0
                }
            end
          end)

        json(conn, %{records: enriched, count: length(enriched)})

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  @doc "PATCH /api/lat/sessions/:id/records/select — Bulk update selection state."
  def lat_select(conn, %{"id" => session_id, "names" => names, "selected" => selected}) do
    case Storage.update_selection_db(session_id, :group1, names, selected) do
      {:ok, count} -> json(conn, %{updated: count})
      {:error, reason} -> conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  @doc "POST /api/lat/sessions/:id/confirm — Mark a record as confirmed after parsing."
  def lat_confirm(conn, %{"id" => session_id, "law_name" => law_name}) do
    case Storage.get_session_record(session_id, law_name) do
      {:ok, record} when not is_nil(record) ->
        case ScrapeSessionRecord.mark_confirmed(record, %{}) do
          {:ok, _} ->
            # Update session totals
            update_session_lat_totals(session_id)

            json(conn, %{
              law_name: law_name,
              status: :confirmed,
              lat_inserted: record.lat_inserted,
              annotations_inserted: record.annotations_inserted
            })

          {:error, reason} ->
            conn |> put_status(500) |> json(%{error: inspect(reason)})
        end

      _ ->
        conn |> put_status(:not_found) |> json(%{error: "Record not found"})
    end
  end

  @doc "DELETE /api/lat/sessions/:id — Delete a LAT session."
  def lat_delete(conn, %{"id" => session_id}) do
    case ScrapeSession.by_session_id(session_id) do
      {:ok, session} ->
        ScrapeSession.destroy(session)
        json(conn, %{message: "Session deleted"})

      {:error, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Session not found"})
    end
  end

  # ── LAT SSE parse stream ───────────────────────────────────────────

  @sse_heartbeat_interval 5_000

  @doc "GET /api/lat/sessions/:id/parse-stream?name=UK_uksi_2024_1001 — SSE streaming LAT parse."
  def lat_parse_stream(conn, %{"id" => session_id, "name" => law_name}) do
    case ScrapeSession.by_session_id(session_id) do
      {:ok, _session} ->
        conn =
          conn
          |> put_resp_content_type("text/event-stream")
          |> put_resp_header("cache-control", "no-cache")
          |> put_resp_header("connection", "keep-alive")
          |> send_chunked(200)

        {:ok, conn} =
          chunk(conn, "data: #{Jason.encode!(%{event: "connected", name: law_name})}\n\n")

        caller = self()

        send_progress = fn event ->
          send(caller, {:sse_event, event})
          :ok
        end

        task =
          Task.async(fn ->
            LatStagedParser.parse(law_name, on_progress: send_progress)
          end)

        lat_sse_event_loop(conn, task, session_id, law_name)

      {:error, _} ->
        conn |> put_status(:not_found) |> json(%{error: "Session not found"})
    end
  end

  def lat_parse_stream(conn, %{"id" => _}) do
    conn |> put_status(:bad_request) |> json(%{error: "Missing required parameter: name"})
  end

  defp lat_sse_event_loop(conn, task, session_id, law_name) do
    receive do
      {:sse_event, event} ->
        data = lat_encode_progress_event(event)

        case chunk(conn, "data: #{data}\n\n") do
          {:ok, conn} ->
            lat_sse_event_loop(conn, task, session_id, law_name)

          {:error, _} ->
            Task.await(task, :infinity)
            conn
        end

      {ref, {:ok, result}} when is_reference(ref) ->
        Process.demonitor(ref, [:flush])
        lat_send_parse_complete(conn, result, session_id, law_name)

      {ref, {:error, reason}} when is_reference(ref) ->
        Process.demonitor(ref, [:flush])
        Logger.error("[LAT SSE] Parse task failed: #{inspect(reason)}")

        # Update session record with error
        Storage.mark_lat_failed(session_id, law_name, inspect(reason), 0)
        conn

      {:DOWN, _ref, :process, _pid, reason} ->
        Logger.error("[LAT SSE] Parse task crashed: #{inspect(reason)}")
        Storage.mark_lat_failed(session_id, law_name, inspect(reason), 0)
        conn
    after
      @sse_heartbeat_interval ->
        case chunk(conn, ": heartbeat\n\n") do
          {:ok, conn} ->
            lat_sse_event_loop(conn, task, session_id, law_name)

          {:error, _} ->
            Logger.info("[LAT SSE] Client disconnected during heartbeat")
            Task.await(task, :infinity)
            conn
        end
    end
  end

  defp lat_send_parse_complete(conn, result, session_id, law_name) do
    # Update session record with results
    case result do
      %{has_errors: false} = r ->
        Storage.update_lat_result(session_id, law_name, r)

      %{has_errors: true, error: error} ->
        Storage.mark_lat_failed(session_id, law_name, error, result[:duration_ms] || 0)

      %{has_errors: true} = r ->
        # Partial success — some stages may have succeeded
        Storage.update_lat_result(session_id, law_name, r)
    end

    final_event =
      Jason.encode!(%{
        event: "parse_complete",
        has_errors: result[:has_errors] || false,
        result: %{
          law_name: law_name,
          lat: result[:lat],
          annotations: result[:annotations],
          duration_ms: result[:duration_ms]
        }
      })

    chunk(conn, "data: #{final_event}\n\n")
    conn
  end

  defp lat_encode_progress_event({:stage_start, stage, stage_num, total}) do
    Jason.encode!(%{event: "stage_start", stage: stage, stage_num: stage_num, total: total})
  end

  defp lat_encode_progress_event({:stage_complete, stage, status, summary}) do
    Jason.encode!(%{event: "stage_complete", stage: stage, status: status, summary: summary})
  end

  defp lat_encode_progress_event({:parse_complete, has_errors}) do
    Jason.encode!(%{event: "parse_done", has_errors: has_errors})
  end

  # ── LAT Session helpers ────────────────────────────────────────────

  defp session_to_json(session) do
    %{
      id: session.id,
      session_id: session.session_id,
      session_type: session.session_type,
      status: session.status,
      group1_count: session.group1_count,
      persisted_count: session.persisted_count,
      lat_total_inserted: session.lat_total_inserted,
      lat_total_annotations: session.lat_total_annotations,
      inserted_at: format_datetime(session.inserted_at),
      updated_at: format_datetime(session.updated_at)
    }
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_datetime(%NaiveDateTime{} = dt), do: NaiveDateTime.to_iso8601(dt)

  defp update_session_lat_totals(session_id) do
    sql = """
    SELECT
      COALESCE(SUM(lat_inserted), 0) AS total_inserted,
      COALESCE(SUM(annotations_inserted), 0) AS total_annotations,
      COUNT(*) FILTER (WHERE status = 'confirmed') AS confirmed_count
    FROM scrape_session_records
    WHERE session_id = $1
    """

    case Repo.query(sql, [session_id]) do
      {:ok, %{rows: [[total_inserted, total_annotations, confirmed_count]]}} ->
        case ScrapeSession.by_session_id(session_id) do
          {:ok, session} ->
            ScrapeSession.update_lat_totals(session, %{
              lat_total_inserted: total_inserted,
              lat_total_annotations: total_annotations,
              persisted_count: confirmed_count
            })

          _ ->
            :ok
        end

      _ ->
        :ok
    end
  end
end
