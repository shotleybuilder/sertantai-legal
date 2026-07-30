---
session: BMS Laws — LAT Parse Session
project: sertantai-legal
status: closed
opened: 2026-07-28
closed: 2026-07-29
outcome: success
commits: [7886511]

summary: >
  LAT triage and parse for 63 BMS-sourced laws. 27 parsed and enriched by fractalaw
  (14,890 provisions, 250 new Baserow duties). 11 confirmed not-making and cleaned
  (LAT + annotations deleted). 16 amendment/commencement orders skipped. 9 out-of-scope
  Acts deferred. Added 'cleaned' session status and live LAT/annotation counts.

decisions:
  - what: New 'cleaned' status for session records where LAT has been parsed then deleted
    why: >
      fractalaw reviews parsed laws and may conclude they are not-making — LAT rows should
      be deleted to save space. Need a status distinct from 'skipped' (never parsed) and
      'confirmed' (LAT kept). 'cleaned' = parsed, triaged, LAT removed.
    result: Added to schema constraint, auto-complete logic, UI with amber badge

  - what: Live LAT/annotation counts instead of static snapshots
    why: >
      Session records stored lat_inserted at parse time. After cleaning (deleting LAT),
      the count was stale — UI showed 33 LAT rows for a law with 0. Live counts from
      uk_lrt.lat_count (trigger-maintained) and amendment_annotations (batch query) are
      always accurate.
    result: API now reads live counts, falling back to stored value only if LRT lookup fails

metrics:
  session_laws: 63
  confirmed: 27
  skipped: 16
  cleaned: 11
  pending_deferred: 9
  lat_provisions: 14890
  baserow_duties_created: 250
  baserow_duties_total: 2804
  lat_rows_deleted: 222
  annotations_deleted: 56

lessons:
  - title: Confidence scores are the triage signal, not making_review
    detail: >
      making_confidence being non-NULL means the auto-detection pipeline ran.
      making_review is for human override and is rarely populated. Don't use
      making_review IS NULL as a proxy for "not triaged."
    tag: data

  - title: md_body_paras is from legislation.gov.uk XML metadata, not from LAT parsing
    detail: >
      The metadata stage extracts TotalParagraphs/BodyParagraphs from the XML — this is
      a structural count from the source, not from our LAT parse. lat_count=0 with
      md_body_paras>0 means the law has content but hasn't been parsed yet.
    tag: data

  - title: Static counts on session records go stale when data is deleted downstream
    detail: >
      lat_inserted and annotations_inserted were snapshots saved at parse time. When LAT
      rows are deleted (cleaning), the session UI shows wrong numbers. Live counts from
      the source tables (uk_lrt.lat_count, amendment_annotations COUNT) are always correct.
      Same principle applies to any denormalised count stored on a session record.
    tag: schema

  - title: LAT deletion does not cascade to amendment_annotations — raised #131
    detail: >
      amendment_annotations FK is to legal_register (the law), not legal_articles
      (provisions). Deleting all LAT for a law leaves orphaned annotations. Need
      either a trigger or application-level cleanup.
    tag: schema

artifacts:
  - backend/lib/sertantai_legal/scraper/resources/scrape_session_record.ex
  - backend/lib/sertantai_legal_web/controllers/lat_admin_controller.ex
  - backend/lib/sertantai_legal_web/controllers/scrape_controller.ex
  - frontend/src/routes/admin/lat/sessions/[id]/+page.svelte

depends_on:
  - qq-requirements/2026-07-28-bms-register.md

enables:
  - LAT deletion cascade to annotations (#131)
  - Parse 9 deferred out-of-scope Acts if scope expands
---

# BMS Laws — LAT Parse Session

**Started**: 2026-07-28
**Context**: Laws added to QQ from BMS register (source: bms_import) that need LAT triage/parse

## Session: `lat-parse-bms-triage-2026-07-28`
- 63 laws: 27 confirmed, 16 skipped, 11 cleaned, 9 pending (deferred)

## Todo
- [x] Built LAT parse session: `lat-parse-bms-triage-2026-07-28` (63 laws)
- [x] 11 fractalaw-confirmed not-making laws: LAT + annotations deleted, marked `cleaned`
- [x] Added `cleaned` status to session record schema (7886511)
- [x] Live LAT/annotation counts in session UI — no more stale snapshots (7886511)
- [x] Amber badge for `cleaned` status in UI
- [x] Raised #131 — LAT deletion should cascade to amendment_annotations
- [x] 16 amendment/commencement orders marked `skipped`
- [x] Fractalaw enrichment complete — taxa + provisions published via Zenoh
- [x] Baserow re-sync: 250 new duties created (2,554 → 2,804 total)
- [ ] 9 out-of-scope Acts pending (Bribery, Official Secrets, etc.) (deferred)

## Notes
- Confidence scores ARE the triage signal — not making_review
- `md_body_paras` comes from legislation.gov.uk XML metadata, not from LAT parsing
- fractalaw reviews parsed laws and may conclude LAT should be deleted (not-making)
- Session record `lat_inserted` was a static snapshot — now reads live `uk_lrt.lat_count`
