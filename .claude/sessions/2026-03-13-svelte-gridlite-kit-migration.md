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

## Notes
- 7 source files migrated
- `sql-filters.ts` deleted (gridlite-kit handles filtering internally)
- `electric/client.ts` simplified (removed old table-kit re-exports)
- Svelte 4 gotcha: no TS `as` casts in template markup — use helper functions instead
- gridlite-views `FilterCondition.operator` is `string`, gridlite-kit expects `FilterOperator` — needs cast at boundary
- Pre-existing: `env-production.test.ts` has `fs`/`path` import errors (vitest types, unrelated)
