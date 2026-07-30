---
session: Customer Onboarding Phase 4 — Sync to Baserow
status: closed
opened: 2026-06-03
closed: 2026-06-03
---
# Title: Customer Onboarding Phase 4 — Sync to Baserow

**Started**: 2026-06-03 00:30
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 4, excluding 4.5)

## Todo
- [x] 4.1 — QinetiQ org in auth, user linked as owner — c075d56b
- [x] 4.2 — Entitlement: 32 families, lrt_lat, standard — d72b5c2a
- [x] 4.3 — Sync profile (QQ Legal Register) + Baserow JWT config — 2b98afa
- [x] 4.4 — Initial sync: 106 L3 laws in Baserow, verified in UI — 2b98afa

## Housekeeping
- [x] Fix complete_job — Ash.update return now propagated, job shows :completed — 08485ce
- [x] Rename Baserow table from default "Table" to "Legal Register" via API — 08485ce
- [x] Clean Baserow table before sync — default rows + columns (Notes, Active) deleted — 08485ce
- [x] Meta-plan updated: added Phase 4.6 (JSONB formatting), Phase 5 (LAT sync), Phase 9 (multi-jurisdiction)

## Notes
- Baserow database tokens can't create fields — switched to JWT auth (email/password)
- Engine fixes: Ash Query/Changeset API, UUID binary handling, NaiveDateTime checkpoint
- Applicability records migrated from test UUID to real org ID
- Auth on port 4000, DB on port 5438

**Ended**: 2026-06-03 08:00
**Commits**: `2b98afa`, `e991dfa`, `08485ce`

## Summary
- Completed: 4 of 4 todos + 4 housekeeping items
- Files: engine.ex, profile_query.ex, baserow.ex, customer-onboarding.md
- Outcome: End-to-end sync working — QinetiQ org in auth, 32-family entitlement, L3 applicability filter, JWT auth to Baserow SaaS, 106 laws in "Legal Register" table. Table preparation automates cleanup of Baserow defaults.
- Next: Phase 4.6 (JSONB column formatting), Phase 5 (LAT sync), Phase 6 (prod deploy), Phase 9 (multi-jurisdiction)
