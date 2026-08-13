---
session: Definition Backfill & QA
status: pending
opened: 2026-08-13
---

# Session: Definition Backfill & QA (PENDING)

## Problem

After the parser, schema, and API are built, we need to run a full backfill across all 19K+ laws and validate the results. This session runs the backfill at scale, builds QA checks, and fixes any parser edge cases discovered.

## Todo

- ⬜ Run `mix definitions.backfill` across all law families
- ⬜ Report: total definitions extracted, breakdown by family, scope distribution
- ⬜ QA checks:
  - Laws with Interpretation sections but 0 definitions extracted (parser gaps)
  - Definitions with empty text (cleaning bugs)
  - Cross-reference targets that don't exist in the legal register
  - Duplicate terms within the same law (parser producing duplicates)
- ⬜ Fix parser edge cases discovered during QA
- ⬜ Sample audit: manually verify 10 laws against legislation.gov.uk (correct terms, complete extraction)
- ⬜ Sync to NAS snapshot (include definitions in backup)

## Dependencies

- ⬜ Definition Parser session
- ⬜ Definition Schema & Storage session
- ✅ LAT data for 19K+ laws

## Acceptance Criteria

Backfill complete across all families. QA checks pass with documented known-good counts. Sample audit confirms ≥90% extraction accuracy on checked laws. Definitions included in NAS snapshots.
