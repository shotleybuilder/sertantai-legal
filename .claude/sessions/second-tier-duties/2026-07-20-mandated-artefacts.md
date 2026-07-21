---
session: Mandated Artefacts Extension to SecondaryTaxaSubscriber
project: sertantai-legal
status: closed
opened: 2026-07-20
closed: 2026-07-20
outcome: success
commits: [8b058bd]

summary: >
  Added secondary_mandated_artefacts table for artefacts mandated by JSP
  obligations. Phase 4 of the consolidated enrichment payload — all four
  enrichment types (DRRP, references, obligations+RACI, artefacts) now
  flow through a single SecondaryTaxaSubscriber.

decisions:
  - what: Full replace per source (same as RACI), not upsert
    why: >
      No natural unique key for artefacts — same artefact_type can appear
      multiple times for different obligations in the same provision.
      Delete-then-insert per source_id is clean and idempotent.
    result: Re-publishes produce identical row counts

metrics:
  artefacts: { total: 32, types: 8, risk_assessment: 13, inspection_report: 8, occurrence_report: 3 }

lessons: []

artifacts:
  - backend/lib/sertantai_legal/legal/secondary_mandated_artefact.ex
  - backend/lib/sertantai_legal/zenoh/secondary_taxa_subscriber.ex
  - backend/priv/repo/migrations/20260720080220_add_secondary_mandated_artefacts.exs

depends_on:
  - 2026-07-19-obligations-raci.md

enables:
  - Baserow sync of mandated artefacts for customer compliance workbench
  - "What artefacts does this JSP require?" query for BMS instruction generation
---

# Mandated Artefacts Extension to SecondaryTaxaSubscriber

**Started**: 2026-07-20
**Spec**: docs/zenoh/ZENOH-SECONDARY-SOURCES.md (mandated_artefacts_json)
**Depends on**: 2026-07-19-obligations-raci.md

## Todo
- [x] Create SecondaryMandatedArtefact resource
- [x] Register in Api domain
- [x] Generate + run migration
- [x] Parse `mandated_artefacts_json` in subscriber
- [x] Full replace per source_id (same as RACI)
- [x] Add to batch summary logging
- [x] Tests
- [x] Verify with live publish

## Notes
- Phase 4 of consolidated payload
- Links to secondary_obligations via obligation_id
- 8 artefact types observed: Risk Assessment, Safety Case, Hazard Log, Permit, etc.
- Same DuckDB struct parser (parse_duckdb_structs)
