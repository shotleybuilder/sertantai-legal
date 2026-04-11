# Data Sync Phase 2: Delta Export/Import (dev→prod)

**Started**: 2026-04-11
**Plan**: `.claude/plans/DATA-SYNC.md` — Phase 2

## Todo
- [x] Create delta export script (`scripts/sync/export_delta.exs`) — timestamp-based differential export
- [x] Create delta apply script (`scripts/sync/apply_delta.exs`) — transactional import with conflict detection
- [x] Add sync tables migration (`20260321194736_add_sync_tables.exs`) + 5 Ash resources
- [x] Generate sample delta export — verified with 2 rows/table × 6 tables
- [x] Extract core modules to `backend/lib/sertantai_legal/sync/delta/` (Config, ColumnMapper, SqlGenerator, Exporter, Applier)
- [x] Wrap as Mix tasks — `mix data.export_delta`, `mix data.apply_delta`
- [x] Fix `__DIR__` path resolution bug (compile-time vs runtime for output dir)
- [x] Test: export 10 uk_lrt rows → sync_test DB → apply → verify count + idempotency
- [x] Document promotion workflow SOP in `.claude/plans/DATA-SYNC.md`
- [ ] Deploy to prod (prod is several migrations behind)

## Notes
- Build and test locally first, defer prod connection to end
- Prod needs migrations caught up before delta apply
- Dev is source of truth — prod is read-only for LRT/LAT data
- **Session recovered after Zed crash** — first 4 items were done in previous context
