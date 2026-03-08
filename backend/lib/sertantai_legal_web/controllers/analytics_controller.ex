defmodule SertantaiLegalWeb.AnalyticsController do
  @moduledoc """
  Admin endpoints for LRT analytics: change tracking and session metrics.

  ## Endpoints

    - `GET /api/analytics/changes` — Change log summary from record_change_log
    - `GET /api/analytics/sessions` — Scrape/reparse session analytics
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo

  # ── Change Tracking ─────────────────────────────────────────────────

  @change_summary_sql """
  SELECT
    COUNT(*) FILTER (WHERE record_change_log IS NOT NULL AND array_length(record_change_log, 1) > 0) AS records_with_changes,
    (SELECT COUNT(*)
     FROM uk_lrt u2, unnest(u2.record_change_log) AS e
     WHERE u2.record_change_log IS NOT NULL) AS total_entries
  FROM uk_lrt
  """

  @change_by_source_sql """
  SELECT entry->>'source' AS source, COUNT(*) AS count
  FROM uk_lrt u, unnest(u.record_change_log) AS entry
  WHERE u.record_change_log IS NOT NULL
  GROUP BY source
  ORDER BY count DESC
  """

  @change_by_changed_by_sql """
  SELECT entry->>'changed_by' AS changed_by, COUNT(*) AS count
  FROM uk_lrt u, unnest(u.record_change_log) AS entry
  WHERE u.record_change_log IS NOT NULL
  GROUP BY changed_by
  ORDER BY count DESC
  """

  @top_changed_fields_sql """
  SELECT key AS field, COUNT(*) AS count
  FROM uk_lrt u, unnest(u.record_change_log) AS entry,
       jsonb_object_keys(entry->'changes') AS key
  WHERE u.record_change_log IS NOT NULL
  GROUP BY key
  ORDER BY count DESC
  LIMIT 15
  """

  @change_timeline_sql """
  SELECT (entry->>'timestamp')::date AS change_date, COUNT(*) AS count
  FROM uk_lrt u, unnest(u.record_change_log) AS entry
  WHERE u.record_change_log IS NOT NULL
    AND (entry->>'timestamp')::date >= CURRENT_DATE - INTERVAL '90 days'
  GROUP BY change_date
  ORDER BY change_date DESC
  """

  def changes(conn, _params) do
    {:ok, %{rows: [[records_with_changes, total_entries]]}} = Repo.query(@change_summary_sql)

    {:ok, %{rows: source_rows}} = Repo.query(@change_by_source_sql)
    by_source = Enum.map(source_rows, fn [source, count] -> %{source: source, count: count} end)

    {:ok, %{rows: changed_by_rows}} = Repo.query(@change_by_changed_by_sql)

    by_changed_by =
      Enum.map(changed_by_rows, fn [changed_by, count] ->
        %{changed_by: changed_by, count: count}
      end)

    {:ok, %{rows: field_rows}} = Repo.query(@top_changed_fields_sql)

    top_changed_fields =
      Enum.map(field_rows, fn [field, count] -> %{field: field, count: count} end)

    {:ok, %{rows: timeline_rows}} = Repo.query(@change_timeline_sql)

    timeline =
      Enum.map(timeline_rows, fn [date, count] ->
        %{date: Date.to_iso8601(date), count: count}
      end)

    json(conn, %{
      records_with_changes: records_with_changes,
      total_entries: total_entries,
      by_source: by_source,
      by_changed_by: by_changed_by,
      top_changed_fields: top_changed_fields,
      timeline: timeline
    })
  end

  # ── Session Analytics ───────────────────────────────────────────────

  @sessions_summary_sql """
  SELECT
    session_type,
    status,
    COUNT(*) AS count,
    COALESCE(SUM(group1_count), 0) AS total_group1,
    COALESCE(SUM(persisted_count), 0) AS total_persisted,
    COALESCE(SUM(lat_total_inserted), 0) AS total_lat_inserted,
    COALESCE(SUM(lat_total_annotations), 0) AS total_lat_annotations
  FROM scrape_sessions
  GROUP BY session_type, status
  ORDER BY session_type, status
  """

  @sessions_totals_sql """
  SELECT
    COUNT(*) AS total_sessions,
    COALESCE(SUM(group1_count), 0) AS total_records_processed,
    COALESCE(SUM(persisted_count), 0) AS total_persisted
  FROM scrape_sessions
  """

  @recent_sessions_sql """
  SELECT
    session_id, session_type, status::text, year, month, day_from, day_to,
    type_code, total_fetched, group1_count, persisted_count,
    lat_total_inserted, lat_total_annotations,
    inserted_at, updated_at
  FROM scrape_sessions
  ORDER BY inserted_at DESC
  LIMIT 20
  """

  def sessions(conn, _params) do
    {:ok, %{rows: summary_rows}} = Repo.query(@sessions_summary_sql)

    summary =
      Enum.map(summary_rows, fn [type, status, count, g1, persisted, lat, annot] ->
        %{
          session_type: type,
          status: to_string(status),
          count: count,
          total_group1: g1,
          total_persisted: persisted,
          total_lat_inserted: lat,
          total_lat_annotations: annot
        }
      end)

    {:ok, %{rows: [[total, processed, persisted]]}} = Repo.query(@sessions_totals_sql)

    {:ok, %{rows: recent_rows}} = Repo.query(@recent_sessions_sql)

    recent =
      Enum.map(recent_rows, fn [
                                  session_id,
                                  session_type,
                                  status,
                                  year,
                                  month,
                                  day_from,
                                  day_to,
                                  type_code,
                                  total_fetched,
                                  group1_count,
                                  persisted_count,
                                  lat_inserted,
                                  lat_annotations,
                                  inserted_at,
                                  updated_at
                                ] ->
        %{
          session_id: session_id,
          session_type: session_type,
          status: to_string(status),
          year: year,
          month: month,
          day_from: day_from,
          day_to: day_to,
          type_code: type_code,
          total_fetched: total_fetched,
          group1_count: group1_count,
          persisted_count: persisted_count,
          lat_total_inserted: lat_inserted,
          lat_total_annotations: lat_annotations,
          inserted_at: maybe_format_timestamp(inserted_at),
          updated_at: maybe_format_timestamp(updated_at)
        }
      end)

    json(conn, %{
      summary: summary,
      recent: recent,
      totals: %{
        total_sessions: total,
        total_records_processed: processed,
        total_persisted: persisted
      }
    })
  end

  defp maybe_format_timestamp(nil), do: nil
  defp maybe_format_timestamp(%NaiveDateTime{} = ts), do: NaiveDateTime.to_iso8601(ts)
  defp maybe_format_timestamp(other), do: to_string(other)
end
