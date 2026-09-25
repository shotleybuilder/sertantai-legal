---
session: "QQ-P2: Prod Data Sync (#27)"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 27
depends_on: [qq-data-readiness/2026-09-25-qq-p1-prod-partition-migration]
---

# Session: QQ-P2 Prod Data Sync (PENDING)

## Problem

Prod data dates from the 9 Feb 2026 deploy. None of the dev fixes since then have reached prod:
- July enrichment: expression trees, significance and DRRP fixes
- August definitions
- this plan's fixes (QQ-01 to QQ-06)
- the QQ org, its profile and its 711 org_applicabilities

Compliance's change feed also needs a **recurring** dev→prod push after each monthly scrape and enrichment.

## Rules for this session

- **Ask Jason before every prod action.** Run only after P1, with a fresh backup.
- Schema goes in before data.

## Todo (loose; rewrite on resume)

- ⬜ Choose the mechanism:
  - delta sync (`mix data.export_delta` / `mix data.apply_delta`, `prod-data-sync` skill) for `legal_register`, `legal_articles`, definitions and amendment annotations;
  - bulk `pg_restore` for empty tables.
- ⬜ Rehearse against a restored copy of prod. Check row counts and spot-check QQ laws: trees, `is_making`, `geo_extent`.
- ⬜ (approval) Push 1, around 10 Oct: the July enrichment plus whatever has landed from QQ-01 to QQ-04.
- ⬜ (approval) Push the QQ org, profile and org_applicabilities. Agree with compliance v0.1-03 whether QQ's prod register is copied or rebuilt through the screener in UAT.
- ⬜ (approval) Push 2, after the 17 Oct freeze: all remaining fixes.
- ⬜ Document the recurring push (after each scrape and enrichment) in `.claude/plans/DATA-SYNC.md`, and close #27.

## Dependencies

- ⬜ QQ-P1 closed
- ⬜ Jason's approval for each push

## Exit criteria

- The prod screener gives the same QQ benchmark numbers as dev, within known differences.
- A documented, repeatable push exists (#161 acceptance criterion).
