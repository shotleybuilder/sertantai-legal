defmodule SertantaiLegal.Repo.Migrations.AddLatEvidenceToMakingFunnel do
  @moduledoc """
  `making_funnel.lat_evidence` from `lat_events` (enrichment readiness,
  2026-09-27): what LAT evidence stands behind a law's verdict.

  - `lat_held` — LAT present now
  - `lat_held_stale_enrichment` — LAT present, but the latest `enriched`
    event names a different `lat_hash` (needs fractalaw provenance)
  - `enriched_then_discarded` — enrichment ran before the last discard
  - `parsed_then_discarded` — LAT was parsed, later discarded
  - `none` — no LAT evidence (legacy / detector verdicts)
  """

  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE VIEW making_funnel AS
    WITH last_lat AS (
      SELECT DISTINCT ON (r.law_name)
             r.law_name, r.session_id, r.status, COALESCE(r.lat_inserted, 0) AS lat_inserted
      FROM scrape_session_records r
      JOIN scrape_sessions s ON s.session_id = r.session_id
      WHERE s.session_type = 'lat_parse'
      ORDER BY r.law_name, r.updated_at DESC
    ),
    f AS (
      SELECT l.id, l.name, l.country, l.title_en, l.family, l.live,
             l.is_making, l.is_making_source, l.is_making_reason, l.is_making_decided_at,
             l.making_review, l.making_review_at,
             l.making_enrichment_verdict, l.making_enriched_at,
             l.making_classification, l.making_classification_source, l.making_confidence,
             l.duty_type -> 'values' AS duty_types,
             l.lat_count, l.has_fitness,
             l.compiled_applicability IS NOT NULL AS has_tree,
             ll.session_id AS last_lat_session,
             ll.status AS last_lat_status,
             (ll.status = 'cleaned'
               OR (ll.status = 'confirmed' AND ll.lat_inserted > 0 AND l.lat_count = 0)) AS lat_cleaned,
             (l.making_classification_source = 'triage'
               AND l.making_classification IN ('making', 'not_making')
               AND (l.making_classification = 'making') IS DISTINCT FROM COALESCE(l.is_making, false)) AS conflict
      FROM legal_register l
      LEFT JOIN last_lat ll ON ll.law_name = l.name
    )
    SELECT f.*,
      CASE
        WHEN making_review IS NOT NULL THEN 'reviewed'
        WHEN lat_count > 0 AND has_fitness THEN 'enriched'
        WHEN lat_count > 0 THEN 'lat_parsed'
        WHEN lat_cleaned THEN 'cleaned'
        WHEN last_lat_status = 'skipped' THEN 'skipped'
        WHEN last_lat_status = 'pending' THEN 'deferred'
        WHEN making_classification_source = 'triage' THEN 'triaged'
        WHEN making_classification IS NOT NULL THEN 'detected'
        ELSE 'unclassified'
      END AS stage,
      CASE
        WHEN live ~ '(Revoked|Repealed|Abolished)' THEN NULL
        WHEN conflict THEN 'review_conflict'
        WHEN is_making AND lat_count = 0 AND lat_cleaned THEN 'review_lat_deleted'
        WHEN has_fitness AND duty_types IS NULL AND making_enrichment_verdict IS NULL
          THEN 'check_enrichment_output'
        WHEN is_making AND lat_count > 0 AND NOT has_fitness THEN 'enrich'
        WHEN is_making AND lat_count = 0 AND NOT COALESCE(lat_cleaned, false) THEN 'lat_parse'
        WHEN making_review IS NULL AND making_classification = 'uncertain'
             AND lat_count = 0 AND last_lat_status IS NULL THEN 'lat_parse_or_review'
        ELSE NULL
      END AS next_action,
      COALESCE(live ~ '(Revoked|Repealed|Abolished)', false) AS revoked,
      CASE
        WHEN f.lat_count > 0 AND le.latest_enriched_hash IS NOT NULL
             AND le.latest_enriched_hash IS DISTINCT FROM le.current_hash THEN 'lat_held_stale_enrichment'
        WHEN f.lat_count > 0 THEN 'lat_held'
        WHEN le.last_discard IS NOT NULL AND le.first_enriched <= le.last_discard
          THEN 'enriched_then_discarded'
        WHEN le.last_discard IS NOT NULL THEN 'parsed_then_discarded'
        ELSE 'none'
      END AS lat_evidence
    FROM f
    LEFT JOIN LATERAL (
      SELECT
        max(e.at) FILTER (WHERE e.event = 'discarded') AS last_discard,
        min(e.at) FILTER (WHERE e.event = 'enriched') AS first_enriched,
        (SELECT e2.lat_hash FROM lat_events e2
          WHERE e2.law_id = f.id AND e2.country = f.country AND e2.event = 'enriched'
          ORDER BY e2.at DESC, e2.id DESC LIMIT 1) AS latest_enriched_hash,
        (SELECT r.lat_hash FROM legal_register r WHERE r.id = f.id AND r.country = f.country) AS current_hash
      FROM lat_events e
      WHERE e.law_id = f.id AND e.country = f.country
    ) le ON true
    """)
  end

  def down do
    # CREATE OR REPLACE cannot remove the lat_evidence column
    execute("DROP VIEW making_funnel")

    execute("""
    CREATE OR REPLACE VIEW making_funnel AS
    WITH last_lat AS (
      SELECT DISTINCT ON (r.law_name)
             r.law_name, r.session_id, r.status, COALESCE(r.lat_inserted, 0) AS lat_inserted
      FROM scrape_session_records r
      JOIN scrape_sessions s ON s.session_id = r.session_id
      WHERE s.session_type = 'lat_parse'
      ORDER BY r.law_name, r.updated_at DESC
    ),
    f AS (
      SELECT l.id, l.name, l.country, l.title_en, l.family, l.live,
             l.is_making, l.is_making_source, l.is_making_reason, l.is_making_decided_at,
             l.making_review, l.making_review_at,
             l.making_enrichment_verdict, l.making_enriched_at,
             l.making_classification, l.making_classification_source, l.making_confidence,
             l.duty_type -> 'values' AS duty_types,
             l.lat_count, l.has_fitness,
             l.compiled_applicability IS NOT NULL AS has_tree,
             ll.session_id AS last_lat_session,
             ll.status AS last_lat_status,
             (ll.status = 'cleaned'
               OR (ll.status = 'confirmed' AND ll.lat_inserted > 0 AND l.lat_count = 0)) AS lat_cleaned,
             (l.making_classification_source = 'triage'
               AND l.making_classification IN ('making', 'not_making')
               AND (l.making_classification = 'making') IS DISTINCT FROM COALESCE(l.is_making, false)) AS conflict
      FROM legal_register l
      LEFT JOIN last_lat ll ON ll.law_name = l.name
    )
    SELECT f.*,
      CASE
        WHEN making_review IS NOT NULL THEN 'reviewed'
        WHEN lat_count > 0 AND has_fitness THEN 'enriched'
        WHEN lat_count > 0 THEN 'lat_parsed'
        WHEN lat_cleaned THEN 'cleaned'
        WHEN last_lat_status = 'skipped' THEN 'skipped'
        WHEN last_lat_status = 'pending' THEN 'deferred'
        WHEN making_classification_source = 'triage' THEN 'triaged'
        WHEN making_classification IS NOT NULL THEN 'detected'
        ELSE 'unclassified'
      END AS stage,
      CASE
        WHEN live ~ '(Revoked|Repealed|Abolished)' THEN NULL
        WHEN conflict THEN 'review_conflict'
        WHEN is_making AND lat_count = 0 AND lat_cleaned THEN 'review_lat_deleted'
        WHEN has_fitness AND duty_types IS NULL AND making_enrichment_verdict IS NULL
          THEN 'check_enrichment_output'
        WHEN is_making AND lat_count > 0 AND NOT has_fitness THEN 'enrich'
        WHEN is_making AND lat_count = 0 AND NOT COALESCE(lat_cleaned, false) THEN 'lat_parse'
        WHEN making_review IS NULL AND making_classification = 'uncertain'
             AND lat_count = 0 AND last_lat_status IS NULL THEN 'lat_parse_or_review'
        ELSE NULL
      END AS next_action,
      COALESCE(live ~ '(Revoked|Repealed|Abolished)', false) AS revoked
    FROM f
    """)
  end
end
