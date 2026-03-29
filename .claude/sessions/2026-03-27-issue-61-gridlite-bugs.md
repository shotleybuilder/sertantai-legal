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

## Notes
- Affected libs: @shotleybuilder/svelte-gridlite-kit, @shotleybuilder/svelte-gridlite-views
- Page: frontend/src/routes/admin/lrt/+page.svelte
- Also fixed: frontend/src/routes/admin/lat/queue/+page.svelte (same sidebar swap)

**Ended**: 2026-03-28T10:30Z
