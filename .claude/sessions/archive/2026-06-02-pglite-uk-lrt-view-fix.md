---
session: Fix PGLite sync — uk_lrt view reference broken
status: closed
opened: 2026-06-02
closed: 2026-06-02
---
# Title: Fix PGLite sync — uk_lrt view reference broken

**Started**: 2026-06-02 17:57
**Related**: .claude/plans/multi-jurisdiction.md (Phase 1.1 renamed uk_lrt → legal_register)

## Todo
- [x] Fix `relation "uk_lrt" does not exist` in PGLite live.changes()
- [x] Fix `duplicate key value violates unique constraint "laws_pkey"` — clear IndexedDB
- [x] Verify /admin/lat/queue loads correctly

## Notes
- Two console errors on /admin/lat/queue — page stuck on "Loading..."
- Root cause: multi-jurisdiction migration renamed uk_lrt to legal_register (partitioned), uk_lrt is now a view
- PGLite collection bridge references uk_lrt but PGLite has the underlying table not the view
- Duplicate key error: Electric shape reset re-syncing into already-populated PGLite store
- Error 1 is the blocker, error 2 is consequential
