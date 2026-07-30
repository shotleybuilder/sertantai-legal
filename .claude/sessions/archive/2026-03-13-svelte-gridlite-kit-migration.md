---
session: Migrate svelte-table-kit → svelte-gridlite-kit
status: closed
opened: 2026-03-13
closed: 2026-03-13
---
# Title: Migrate svelte-table-kit → svelte-gridlite-kit

**Started**: 2026-03-13 15:47

## Context
- svelte-table-kit was built for TanStack DB; project now uses PGLite
- svelte-gridlite-kit is the PGLite-compatible fork
- svelte-gridlite-views is under dev (not yet released)

## Files using svelte-table-kit
- `frontend/package.json` (dependency)
- `frontend/src/routes/browse/+page.svelte`
- `frontend/src/routes/admin/lrt/+page.svelte`
- `frontend/src/routes/admin/lat/queue/+page.svelte`
- `frontend/src/lib/pglite/sql-filters.ts`
- `frontend/src/lib/electric/client.ts`
- `frontend/src/app.css`

## Todo
- [x] Understand svelte-gridlite-kit API differences
- [x] Update package.json dependency
- [x] Migrate browse page
- [x] Migrate admin/lrt page
- [x] Migrate admin/lat/queue page
- [x] Update sql-filters.ts (deleted — filters now handled by gridlite-kit internally)
- [x] Update electric/client.ts (removed old table-kit exports)
- [x] Update app.css references
- [x] Test all migrated pages — build + type check clean

## Post-crash fixes (session 2)
Zed IDE crashed mid-migration. Resumed to fix type errors.

- [x] Fix Svelte 4 template `as` cast errors (markup doesn't support TS casts)
  - `admin/lat/queue`: added `str()`, `bool()` helpers, replaced 12+ inline casts
  - `admin/lrt`: added `asLrt()` helper for `{@const r = row as UkLrtRecord}`
  - `browse`: used existing `asStr()`/`asStrArr()` helpers, hoisted `{@const fns}` to valid block level
- [x] Fix `{@const}` placement — must be direct child of `{#if}`, not inside `<div>`
- [x] Fix FilterCondition type mismatch between gridlite-views and gridlite-kit
  - `applyViewToGrid()` in all 3 pages: cast `cfg.filters/sorting/grouping` to kit types
- [x] Build passes clean, dev server responds 200

## Commits
- `441c560` feat: migrate svelte-table-kit → svelte-gridlite-kit + svelte-gridlite-views
- `b886217` fix: drop stale _gridlite_views table missing grid_id column
- `c25a683` fix: also drop _gridlite_meta to force kit migration re-run
- `1a1ba85` fix: detect and drop incompatible _gridlite_column_state on every init

## Notes
- 7 source files migrated
- `sql-filters.ts` deleted (gridlite-kit handles filtering internally)
- `electric/client.ts` simplified (removed old table-kit re-exports)
- Svelte 4 gotcha: no TS `as` casts in template markup — use helper functions instead
- gridlite-views `FilterCondition.operator` is `string`, gridlite-kit expects `FilterOperator` — needs cast at boundary
- Pre-existing: `env-production.test.ts` has `fs`/`path` import errors (vitest types, unrelated)
- **gridlite-kit vs gridlite-views schema conflict**: both create `_gridlite_column_state` with different schemas (kit has `grid_id`, views doesn't). Fix: `initSchema` introspects the table and drops all `_gridlite_*` if incompatible

## Session 3 — gridlite-kit bug fixing (2026-03-14)

Resolved "No data" on all 3 grid pages. Root cause: multiple gridlite-kit bugs.

### Kit issues raised and fixed
- **#4** (0.3.1): `query` prop — columns not derived from result fields
- **#5** (0.4.0): `query` prop — toolbar not rendered; fix: subquery wrapping gives full parity
- **#6** (0.4.1): `setFilters`/`setSorting`/`setGrouping` throw before first query result
- **#7** (0.4.2): Grouped mode ORDER BY includes non-grouped columns
- **#8** (0.4.3): Top-level GROUP BY ORDER BY includes deeper-level group columns
- **#9** (0.4.4): Grouped mode `storeState.loading` stays true forever

### Commits
- `7c586c7` fix: guard GridLite render on non-empty currentQuery in admin/lrt
- `c30288a` feat: upgrade svelte-gridlite-kit to 0.4.4 (subquery wrapping, query prop parity)

**Ended**: 2026-03-14T23:30Z
