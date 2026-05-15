# Title: Upgrade svelte-gridlite-kit to v0.6.0 (breaking changes)

**Started**: 2026-05-13
**Related Issues**: #71, #59

## Current Versions → Target Versions
- `@shotleybuilder/svelte-gridlite-kit`: 0.5.1 → 0.6.0
- `@shotleybuilder/gridlite-adapter-pglite`: 0.6.0 → 0.7.0
- `@shotleybuilder/gridlite-adapter-tanstack-db`: 0.6.0 → 0.7.0
- `@shotleybuilder/svelte-gridlite-views`: 0.2.1 → no update available

## Affected Pages (3)
- `frontend/src/routes/browse/+page.svelte`
- `frontend/src/routes/admin/lat/queue/+page.svelte`
- `frontend/src/routes/admin/lrt/+page.svelte`

**Ended**: 2026-05-14
**Commits**: None (uncommitted — package.json + package-lock.json changes)

## Todo
- [x] Understand breaking changes in v0.6.0 (check lib source)
- [x] Update package.json versions
- [x] npm install
- [x] Update `/browse` page — no code changes needed (adapter-level change)
- [x] Update `/admin/lat/queue` page — no code changes needed
- [x] Update `/admin/lrt` page — no code changes needed
- [x] Build check (`npm run build`)
- [x] Manual testing of all three pages

## Notes
- Breaking change was adapter-internal (executeGroupSummary→createLiveGroupSummary), no page-level API changes
- Raised shotleybuilder/svelte-gridlite-kit#30 — workspace:^ leaked in adapter peerDeps, fixed in v0.7.1
- Raised shotleybuilder/svelte-gridlite-kit#31 — TDZ bug in GridLite.svelte subscribe, fixed in v0.6.1
- Final versions: kit 0.6.1, adapters 0.7.1, views 0.2.1
