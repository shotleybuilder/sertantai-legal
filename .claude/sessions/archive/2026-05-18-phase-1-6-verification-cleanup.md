---
session: Phase 1.6 — Verification & Cleanup
status: closed
opened: 2026-05-18
closed: 2026-05-18
---
# Title: Phase 1.6 — Verification & Cleanup

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Audit: Raw SQL references to uk_lrt/lat views

~70 raw SQL references across 10 files:
- `analytics_controller.ex` (~20 refs)
- `lat_admin_controller.ex` (~15 refs)
- `graph_controller.ex` (~10 refs)
- `ai_sync_controller.ex` (~8 refs)
- `ai_drrp_controller.ex` (1 ref)
- `mix/tasks/law_edges.rebuild.ex` (~5 refs)
- `scraper/staged_parser.ex`, `lat_staged_parser.ex`, `lat_reparser.ex`, `lat_persister.ex` (~5 refs)
- `legal/family_inference.ex` (1 ref)

**Decision**: Keep views. Dropping them would require updating ~70 raw SQL statements
for no functional benefit. The views are zero-cost (simple SELECT with WHERE country='uk')
and provide a clean backwards-compat layer.

## Todo

### Cleanup — drop only _old backup tables
- [x] Drop 5 `_old` backup tables via migration
- [x] Remove legacy `/api/uk-lrt/*` route aliases from router (9 routes removed)
- [x] Update tests referencing old routes (35 refs in 2 files)

### Verification
- [x] All 1,211 backend tests pass
- [x] All 131 frontend tests pass (verified in Phase 1.5)
- [x] Frontend syncs and displays correctly (verified in Phase 1.5)

**Ended**: 2026-05-18
**Commits**: (pending)

## Notes
- NAS scripts already updated in Phase 1.1
- Electric shapes already updated in Phase 1.5
- Views (`uk_lrt`, `lat`) KEPT — ~70 raw SQL refs depend on them, zero-cost to maintain
- Legacy `UkLrt` and `Lat` Ash resources KEPT — views need backing resources for Ecto schema
- Production deployment is a separate concern
