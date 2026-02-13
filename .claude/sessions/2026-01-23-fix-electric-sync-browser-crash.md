# Title: Fix ElectricSQL Sync Browser Crash

**Started**: 2026-01-23 19:23
**Issue**: None

## Todo
- [x] Fix ElectricSQL sync status stuck on 'Syncing'
- [x] Fix browser crash during Electric sync with large datasets
- [x] Create/update SKILL.md for ElectricSQL + TanStack DB setup

## Problem Summary

The admin/lrt page was experiencing two issues:
1. Sync status permanently stuck on "Syncing"
2. Browser crashing during data sync (no console access)

## Root Cause

The original implementation manually subscribed to `ShapeStream` and called `collection.insert()` for each record. With ~600+ records, this caused:
- Excessive reactive updates (one per record)
- Memory exhaustion from unbatched operations
- Browser crash before sync completed

## Solution

### 1. Use Official `electricCollectionOptions` Pattern

Replaced manual ShapeStream subscription with the official `@tanstack/electric-db-collection` integration:

```typescript
import { electricCollectionOptions } from '@tanstack/electric-db-collection';

const collection = createCollection(
  electricCollectionOptions<ElectricUkLrtRecord>({
    id: 'uk-lrt',
    syncMode: 'progressive',  // Key: incremental snapshots for large datasets
    shapeOptions: {
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'uk_lrt',
        where: whereClause,
        columns: UK_LRT_COLUMNS  // Exclude generated columns
      }
    },
    getKey: (item) => item.id as string
  })
);
```

### 2. Use Progressive Sync Mode

Added `syncMode: 'progressive'` which provides incremental snapshots during initial sync instead of loading everything at once.

| Mode | Behavior | Use When |
|------|----------|----------|
| `eager` (default) | Downloads all data before ready | Small datasets (<100 records) |
| `progressive` | Incremental snapshots | Large datasets (100-10k records) |
| `on-demand` | Syncs when queried | Very large datasets, paginated |

### 3. Debounce Updates

- Sync status updates: 100ms debounce
- UI refresh: 200ms debounce

### 4. Single Subscription

Changed from subscribing to both `collection.subscribeChanges()` AND `syncStatus` (causing double updates) to only subscribing to `syncStatus`.

### 5. Exclude Generated Columns

PostgreSQL generated columns (`leg_gov_uk_url`, `number_int`) cannot be synced by Electric. Added explicit `columns` parameter to exclude them.

### 6. Fix TypeScript Types

Electric's `Row<unknown>` requires an index signature:
```typescript
type ElectricUkLrtRecord = UkLrtRecord & Record<string, unknown>;
```

## Files Changed

- `frontend/src/lib/db/index.client.ts` - Complete rewrite using electricCollectionOptions
- `frontend/src/lib/db/idb-storage.ts` - Added write debouncing
- `frontend/src/lib/electric/sync-uk-lrt.ts` - Added columns whitelist (now mostly obsolete)
- `frontend/src/routes/admin/lrt/+page.svelte` - Debounced refreshData, single subscription
- `.claude/skills/electricsql-sync-setup/SKILL.md` - New comprehensive skill documentation (827 lines)

## Commits

- `d5a00d1` fix(electric): Use progressive sync mode to prevent browser crash

## Key Learnings (Documented in SKILL.md)

1. **Always use `electricCollectionOptions`** - Manual ShapeStream subscription is an anti-pattern
2. **Use `syncMode: 'progressive'`** for datasets with 100+ records
3. **Debounce everything** - Sync status (100ms), UI refresh (200ms)
4. **Single subscription** - Don't subscribe to both `subscribeChanges()` and `syncStatus`
5. **Exclude generated columns** - Electric cannot sync PostgreSQL generated columns
6. **Type constraint** - Add `& Record<string, unknown>` for Electric compatibility
7. **Use `collection.isReady()`** - Not `state.isReady` (doesn't exist)

**Ended**: 2026-01-23 20:43
