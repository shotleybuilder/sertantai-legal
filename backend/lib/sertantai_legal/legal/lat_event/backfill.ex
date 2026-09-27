defmodule SertantaiLegal.Legal.LatEvent.Backfill do
  @moduledoc """
  One-off (idempotent) backfill of `lat_events` from what existed before the
  triggers (enrichment readiness, 2026-09-27). Every backfilled event has a
  `backfill_*` source — lower fidelity than live events, which are never
  touched: a run first deletes previous `backfill_*` events, then inserts:

  1. `parsed` from LAT parse sessions (`scrape_session_records` with
     `lat_inserted > 0`): at the record's `updated_at`, or its `inserted_at`
     when the record was later `cleaned` — `backfill_lat_session:<id>`
  2. `discarded` (reason `not_making`) at a `cleaned` record's `updated_at`
     (the not-Making clean-up) — `backfill_lat_session:<id>`
  3. `discarded` (reason `unknown`) for laws parsed with rows, now holding no
     LAT, never cleaned and with no discard event — `backfill_inferred`
  4. `enriched` from `making_enrichment_verdict` / `making_enriched_at`, unless
     a live TaxaSubscriber event exists — `backfill_verdict`
  5. `parsed` for laws holding LAT with no parsed event, from their current
     hashes and count at `latest_lat_updated_at` — `backfill_current_lat`

  `record_change_log` is not a source: it holds no reliable LAT-deletion
  records (a text match for "lat"/"deleted" found only unrelated words).
  """

  alias SertantaiLegal.Repo

  @sessions """
  FROM scrape_session_records ssr
  JOIN scrape_sessions s ON s.session_id = ssr.session_id AND s.session_type = 'lat_parse'
  JOIN legal_register r ON r.name = ssr.law_name
  """

  @doc "Run the backfill; returns the number of events inserted per step."
  @spec run() :: %{atom() => non_neg_integer()}
  def run do
    {:ok, counts} =
      Repo.transaction(
        fn ->
          Repo.query!("DELETE FROM lat_events WHERE source LIKE 'backfill%'")

          %{
            session_parsed:
              exec("""
              INSERT INTO lat_events (law_id, country, law_name, event, at, source, row_count)
              SELECT r.id, r.country, r.name, 'parsed',
                     (CASE WHEN ssr.status = 'cleaned' THEN ssr.inserted_at ELSE ssr.updated_at END) AT TIME ZONE 'UTC',
                     'backfill_lat_session:' || ssr.session_id, ssr.lat_inserted
              #{@sessions}
              WHERE coalesce(ssr.lat_inserted, 0) > 0
              """),
            session_cleaned:
              exec("""
              INSERT INTO lat_events (law_id, country, law_name, event, at, source, reason)
              SELECT r.id, r.country, r.name, 'discarded', ssr.updated_at AT TIME ZONE 'UTC',
                     'backfill_lat_session:' || ssr.session_id, 'not_making'
              #{@sessions}
              WHERE ssr.status = 'cleaned'
              """),
            inferred_discard:
              exec("""
              INSERT INTO lat_events (law_id, country, law_name, event, at, source, reason)
              SELECT r.id, r.country, r.name, 'discarded',
                     (max(ssr.updated_at) + interval '1 second') AT TIME ZONE 'UTC', 'backfill_inferred', 'unknown'
              #{@sessions}
              WHERE coalesce(ssr.lat_inserted, 0) > 0 AND r.lat_count = 0
                AND NOT EXISTS (SELECT 1 FROM lat_events e WHERE e.law_id = r.id AND e.event = 'discarded')
              GROUP BY r.id, r.country, r.name
              """),
            verdicts:
              exec("""
              INSERT INTO lat_events (law_id, country, law_name, event, at, source, verdict)
              SELECT r.id, r.country, r.name, 'enriched', coalesce(r.making_enriched_at, now()),
                     'backfill_verdict', r.making_enrichment_verdict
              FROM legal_register r
              WHERE r.making_enrichment_verdict IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM lat_events e WHERE e.law_id = r.id AND e.event = 'enriched')
              """),
            current_lat:
              exec("""
              INSERT INTO lat_events (law_id, country, law_name, event, at, source,
                                      lat_hash, struct_hash, row_count)
              SELECT r.id, r.country, r.name, 'parsed', coalesce(r.latest_lat_updated_at, now()),
                     'backfill_current_lat', r.lat_hash, r.struct_hash, r.lat_count
              FROM legal_register r
              WHERE r.lat_count > 0
                AND NOT EXISTS (SELECT 1 FROM lat_events e WHERE e.law_id = r.id AND e.event = 'parsed')
              """)
          }
        end,
        timeout: :infinity
      )

    counts
  end

  defp exec(sql) do
    %{num_rows: n} = Repo.query!(sql, [], timeout: :infinity)
    n
  end
end
