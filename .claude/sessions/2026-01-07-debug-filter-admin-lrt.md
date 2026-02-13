# Title: debug-filter-admin-lrt

**Started**: 2026-01-07
**Issue**: None

## Todo
- [x] Investigate filter issue in /admin/lrt
- [x] Identify root cause
- [x] Fix the issue

## Problems Found & Fixed

### 1. Filter UI not showing default year filter
**Problem**: TableKit's filter dropdown showed "Add condition" despite `year >= 2024` being applied.
**Fix**: Added `defaultFilters` to TableKit config in `+page.svelte:1242-1248`

### 2. IndexedDB store conflict
**Problem**: `createStore('sertantai-legal-db', 'sync-meta')` failed because idb-keyval only supports one store per database.
**Fix**: Changed to separate database `createStore('sertantai-legal-sync-meta', 'sync-state')` in `idb-storage.ts:150`

### 3. Stale offset causing empty sync
**Problem**: Saved Electric offset existed but IndexedDB data was cleared → sync resumed from offset, got no data.
**Fix**: Added safety check in `sync-uk-lrt.ts:150-174` - if offset exists but collection is empty, clear offset and do fresh sync.

### 4. Insert collision errors
**Problem**: `Cannot insert document with ID X because it already exists` when Electric sends inserts for cached records.
**Fix**: Changed to upsert logic in `sync-uk-lrt.ts:229-264` - check `has()` before insert, update if exists.

### 5. Data not appearing in UI after sync
**Problem**: `subscribeChanges()` callback not firing when collection updated via Electric sync.
**Fix**: Subscribe to `syncStatus` store instead - refresh data when `connected && !syncing` in `+page.svelte:462-478`

### 6. Redundant sync on initial load
**Problem**: `handleTableStateChange` triggered sync with same WHERE clause as `initElectricSync`.
**Fix**: Initialize `lastWhereClause` to default WHERE in `+page.svelte:401-404`

### 7. Unsubscribe context error on navigation
**Problem**: `TypeError: this is undefined` when navigating away from page - extracting `unsubscribe` method lost `this` context.
**Fix**: Store original subscription object and call `unsubscribe()` on it directly in `+page.svelte:474-485`

## Notes
- TanStack DB's `subscribeChanges` may not fire for programmatic updates via `insert`/`update`
- idb-keyval's `createStore` creates one store per database - use different DB names for multiple stores

**Ended**: 2026-01-07 19:38
