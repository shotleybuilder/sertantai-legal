---
session: GridLite view sidebar, column resize, grouping, and filter bugs
status: closed
opened: 2026-03-27
closed: 2026-03-27
---
# Issue #61: GridLite view sidebar, column resize, grouping, and filter bugs

**Started**: 2026-03-27T13:15Z
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/61

## Todo
- [x] Sidebar: expand/collapse on view groups — replaced custom sidebar with library ViewSidebar (eebcba9, 69c847c)
- [x] Sidebar: drag views to reorder within/between groups — same fix, ViewSidebar has drag-and-drop built in
- [x] Column width changer not actually resizing — library bug: `border-collapse: collapse` broke `position: relative` on `<th>`, fixed in kit v0.4.6 (kit#13), bumped to v0.4.7 (4296939)
- [x] Error when all groups removed — Svelte reactive timing: `setGrouping([])` called `rebuildQuery` before `$: validGrouping` updated, fixed with snapshot in kit v0.4.8 (kit#14, 66ea1ad) — verified
- [x] Save View on default view should update, not create new — two-part fix:
  - hasActiveView subscription was one-shot, now live (be414e6)
  - Column visibility not persisting: notifyStateChange reported stale visibleColumns due to Svelte reactive batching (kit#15), fixed in kit v0.4.9 (1322db5) + consumer-side switchToView reads savedConfig.columnVisibility (d444966) — verified
- [x] Default view filters not showing in filter toolbar — views used raw SQL WHERE instead of GridLite FilterConditions. Converted all views on LRT page (8ae2c42) and LAT queue page (e5433bb) to use FilterNode[] with nested groups, JSONB operators, and column-to-column comparison. Kit bumped to v0.4.13 (kit#17 nested groups, kit#18 JSONB, kit#19 col compare)

## 2026-03-29 Continuation

- [x] Bump svelte-gridlite-kit to v0.4.16
- [x] JSONB filter fix: `function` column `dataType: 'text'` → `'json'` on browse, admin/lrt, admin/lat/queue — filter now shows individual keys (Making, Amending) instead of raw JSON combinations
- [x] **LAT queue browser crash fix**: root cause was `pagination: false` — after filter conversion changed per-view SQL WHERE to unfiltered `BASE_QUERY`, GridLite tried to render all 19K rows at once. Fixed: `pagination: true` (bc60402)
- [x] View re-seed fix: raw SQL wipe needs 200ms delay for PGLite live query to propagate before `seedDefaults` reads store (7e927e9)
- [x] Clean up redundant filters on family views: split `QUEUE_BASE_FILTERS` into `QUEUE_CORE_FILTERS` (always apply) + `QUEUE_BROAD_GUARDS` (title/family guards, only for views without a specific family)
- [x] **LAT queue filter logic was backwards**: filtered on `is_making = true` (confirmed by LAT parsing) instead of `making_classification != 'not_making'` (guess from LRT metadata). Queue purpose is to show candidates that NEED LAT parsing. Fixed in frontend and backend `lat_session_manager.ex` (9a6447e)
- [x] Updated `docs/FUNCTION_VALUES.md` with correct pipeline: LRT scraper → `making_classification` (guess) → LAT queue → LAT parser (Rust) → `duty_type` → `is_making` (confirmed) → `function` map
- [x] Stale data on view switch: removed inert `{#key currentQuery}` wrapper and `setTimeout` on `applyViewToGrid`. Root cause is kit#21 — `setFilters`/`setSorting`/`setGrouping` each fire async `rebuildQuery()` without await, causing race conditions. Temporary workaround: `await tick()` between calls. Raised kit#21 for `applyConfig()` batch API.
- [x] **kit#21 fix**: bumped svelte-gridlite-kit to v0.4.17 (`applyConfig()` batch API). Replaced `await tick()` workaround with single `gridRef.applyConfig()` call in `applyViewToGrid` on all three pages (browse, admin/lrt, admin/lat/queue). Committed (07b49dd)
- [x] **kit#22 fix**: stale data when removing grouping — `rebuildQuery()` checks `$: isGrouped` Svelte reactive which is stale when `setGrouping([])` is called synchronously. Grouped path early-returns on empty `validGrouping`, leaving no store → stale data displayed. Fixed in kit v0.4.18, bumped.

## Notes
- Affected libs: @shotleybuilder/svelte-gridlite-kit, @shotleybuilder/svelte-gridlite-views
- Pages: frontend/src/routes/admin/lrt/+page.svelte, frontend/src/routes/admin/lat/queue/+page.svelte, frontend/src/routes/browse/+page.svelte
- Backend: backend/lib/sertantai_legal/scraper/lat_session_manager.ex

**Ended**: 2026-03-29
