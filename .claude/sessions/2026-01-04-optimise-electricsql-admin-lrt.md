# Title: optimise-electricsql-admin-lrt

**Started**: 2026-01-04
**Status**: Completed
**Issue**: None

## Summary

Optimized the `/admin/lrt` ElectricSQL implementation to fix two key performance issues:
1. Eager filter-sync causing excessive re-syncs on every keystroke
2. Slow initial load waiting for Electric sync instead of showing cached local data

## Completed Tasks

- [x] Review previous session notes and current implementation
- [x] Compare with sertantai-enforcement ./data route pattern
- [x] Fix eager filter-sync issue (added 500ms debounce)
- [x] Optimize initial load from local TanstackDB (show cached data immediately)
- [x] Fix localStorage quota exceeded error - switch to IndexedDB
- [x] Research TanStack DB persistence architecture (RxDB, PowerSync, idb-keyval)
- [x] Document storage stack and complementary technologies
- [x] Implement Electric offset persistence for true delta sync

## Key Findings

### sertantai-enforcement Pattern Analysis

The `/data` route in sertantai-enforcement uses **TanStack Query** with a REST API, not ElectricSQL for that page. Filtering happens client-side on cached data. This is a different pattern from what we're doing with ElectricSQL.

However, their `sync-cases.ts` shows good patterns for ElectricSQL:
- Progressive sync (recent data first, historical in background)
- Batch message processing with `requestIdleCallback` to prevent UI freezing
- Separate sync progress tracking

### Issues Identified in /admin/lrt

1. **Eager filter-sync**: `handleTableStateChange` called `updateUkLrtWhere` on EVERY filter change
   - This stopped existing sync, cleared ALL data, created new ShapeStream, re-downloaded everything
   - User typing "2024" triggered 4 separate syncs

2. **Blocking initial load**: Page waited for `await syncUkLrt()` to complete before showing any data
   - Even if data was already cached in localStorage/TanstackDB, user saw loading spinner

## Changes Made

### 1. `frontend/src/lib/electric/sync-uk-lrt.ts`

**Added debouncing for WHERE clause updates:**
```typescript
// Debounce settings for WHERE clause updates
const WHERE_DEBOUNCE_MS = 500;
let whereDebounceTimeout: ReturnType<typeof setTimeout> | null = null;

export async function updateUkLrtWhere(whereClause: string) {
  // Clear any pending debounce
  if (whereDebounceTimeout) {
    clearTimeout(whereDebounceTimeout);
    whereDebounceTimeout = null;
  }

  // Debounce the WHERE clause update
  whereDebounceTimeout = setTimeout(async () => {
    console.log(`[Electric Sync] Updating WHERE clause to: ${whereClause}`);
    await syncUkLrt(whereClause);
    whereDebounceTimeout = null;
  }, WHERE_DEBOUNCE_MS);
}
```

**Added immediate update function for saved views:**
```typescript
export async function updateUkLrtWhereImmediate(whereClause: string) {
  // Clear any pending debounce and sync immediately
  if (whereDebounceTimeout) {
    clearTimeout(whereDebounceTimeout);
    whereDebounceTimeout = null;
  }
  await syncUkLrt(whereClause);
}
```

**Changed `syncUkLrt` to NOT clear data by default:**
```typescript
export async function syncUkLrt(whereClause?: string, isReconnect = false, clearData = false) {
  // ...
  // Only clear existing data if explicitly requested
  if (clearData) {
    const existingKeys = Array.from(ukLrtCollection.keys());
    for (const key of existingKeys) {
      ukLrtCollection.delete(key);
    }
  }
  // ...
}
```

### 2. `frontend/src/routes/admin/lrt/+page.svelte`

**Optimized `initElectricSync` for instant local data display:**
```typescript
async function initElectricSync() {
  try {
    error = null;

    // Get collection first - immediate access to cached data
    const collection = await getUkLrtCollection();

    // Load existing local data IMMEDIATELY
    const localData = collection.toArray as UkLrtRecord[];
    if (localData.length > 0) {
      data = localData;
      totalCount = localData.length;
      isLoading = false; // Show data immediately!
    }

    // Subscribe to collection changes for reactivity
    collectionSubscription = collection.subscribeChanges(() => {
      data = collection.toArray as UkLrtRecord[];
      totalCount = data.length;
    });

    // Start Electric sync in the background
    syncUkLrt().then(() => {
      isLoading = false;
    }).catch((e) => {
      // Don't set error if we have local data
      if (data.length === 0) {
        error = e instanceof Error ? e.message : 'Failed to sync data';
      }
      isLoading = false;
    });

    // Only show loading if no local data
    if (localData.length === 0) {
      isLoading = true;
    }
  } catch (e) {
    error = e instanceof Error ? e.message : 'Failed to initialize';
    isLoading = false;
  }
}
```

## Behavioral Improvements

| Before | After |
|--------|-------|
| Every filter keystroke triggered resync | 500ms debounce waits for user to finish |
| All data cleared on filter change | Data merges, no flicker |
| Page waited for Electric sync to complete | Local data shown instantly |
| Sync failure = error screen | Sync failure = show local data + offline indicator |

### 3. IndexedDB Storage Adapter

**Problem**: localStorage has a ~5MB limit, but 19,000+ UK LRT records exceed this, causing `DOMException: The quota has been exceeded` errors.

**Solution**: Created a custom IndexedDB storage adapter that implements the same interface as localStorage.

**New file: `frontend/src/lib/db/idb-storage.ts`**
```typescript
import { get, set, del, createStore } from 'idb-keyval';

// Create a dedicated store for sertantai-legal
const customStore = createStore('sertantai-legal-db', 'collections');

class IndexedDBStorage implements StorageInterface {
  private cache: Map<string, string> = new Map();
  
  // Sync reads from memory cache, async writes to IndexedDB
  getItem(key: string): string | null {
    return this.cache.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.cache.set(key, value);
    // Persist to IndexedDB in background
    set(key, value, customStore);
  }

  removeItem(key: string): void {
    this.cache.delete(key);
    del(key, customStore);
  }
}
```

**Updated: `frontend/src/lib/db/index.client.ts`**
```typescript
import { initializeIDBStorage } from './idb-storage';

async function ensureCollections() {
  // Initialize IndexedDB storage first
  const idbStorage = await initializeIDBStorage([UK_LRT_STORAGE_KEY]);

  ukLrtCol = createCollection(
    localStorageCollectionOptions<UkLrtRecord, string>({
      storageKey: UK_LRT_STORAGE_KEY,
      getKey: (item) => item.id,
      // Use IndexedDB-backed storage instead of localStorage
      storage: idbStorage
    })
  );
}
```

**Dependencies added**: `idb-keyval` (lightweight IndexedDB wrapper)

## Testing

- Build passes: `npm run build` completes successfully
- TypeScript check: Only pre-existing test file issues (unrelated to these changes)

## Deep Dive: TanStack DB Persistence Architecture

### The Core Question

From [Frontend at Scale blog](https://frontendatscale.com/blog/tanstack-db):

> "Loading megabytes of data upfront is not only acceptable, but a best practice. Sure, the first time a user opens our app they might need to look at a splash screen for a few seconds while the data is downloaded, but on any subsequent requests and visits, they'd only need to download the data that changed."

**The question**: Where is this data stored between visits?

### TanStack DB Collection Types

TanStack DB is **storage-agnostic**. It provides different collection types for different persistence needs:

| Collection Type | Package | Storage | Persistence | Size Limit |
|-----------------|---------|---------|-------------|------------|
| `electricCollectionOptions` | `@tanstack/electric-db-collection` | Memory | None | RAM only |
| `localStorageCollectionOptions` | `@tanstack/db` | localStorage | Yes | ~5MB |
| `rxdbCollectionOptions` | `@tanstack/rxdb-db-collection` | **IndexedDB** | Yes | ~50% disk |
| `powersyncCollectionOptions` | `@tanstack/powersync-db-collection` | SQLite/OPFS | Yes | ~50% disk |
| `localOnlyCollectionOptions` | `@tanstack/db` | Memory | None | RAM only |

### The Missing Piece: ElectricSQL + Persistence

The official `@tanstack/electric-db-collection` uses **memory-only storage**. This means:

1. **First visit**: Downloads all data from Electric (e.g., 19K records)
2. **Page reload**: Downloads all data again (no persistence!)
3. **Live updates**: Only downloads changes (delta sync works)

To achieve the "megabytes upfront, then only changes" pattern, you need:

1. **IndexedDB persistence** - Store the data locally (RxDB or PowerSync)
2. **Saved Electric offset** - So Electric knows where to resume from
3. **Offset persistence** - Store the offset in IndexedDB too

### How ElectricSQL Offset/Resume Works

ElectricSQL's ShapeStream tracks sync position via:
- `offset`: Position in the shape log
- `handle`: Shape subscription identifier

```typescript
// Initial sync (first visit)
new ShapeStream({ url: '...', offset: -1 })  // Download everything

// Resume sync (subsequent visits) 
new ShapeStream({ url: '...', offset: savedOffset, handle: savedHandle })  // Only changes
```

The offset/handle are kept in memory during a session, but **not persisted by default**. For true "only download changes" on subsequent visits, you must:
1. Persist the offset to IndexedDB
2. Pass it back to ShapeStream on next visit

### Our Current Implementation Gap

We built a custom IndexedDB adapter (`idb-storage.ts`) that:
- Persists the **data** to IndexedDB
- Does NOT persist the Electric **offset**

This means on page reload:
- Data loads instantly from IndexedDB (good!)
- Electric re-syncs from offset=-1, re-downloading all 19K records (bad!)
- The re-downloaded data overwrites/merges with cached data

### The Complete Solution

To achieve true "only download changes":

```
┌─────────────────────────────────────────────────────────────┐
│                     Page Load                                │
├─────────────────────────────────────────────────────────────┤
│  1. Load data from IndexedDB → Show immediately             │
│  2. Load saved offset from IndexedDB                        │
│  3. Start Electric sync with saved offset                   │
│  4. Only download records changed since last sync           │
│  5. Update IndexedDB with changes                           │
│  6. Save new offset to IndexedDB                            │
└─────────────────────────────────────────────────────────────┘
```

## Browser Storage Architecture

### The Storage Stack

Understanding the layers is critical:

```
┌─────────────────────────────────────────────────────────────┐
│  HIGH LEVEL: Database/Collection Abstraction                │
├─────────────────────────────────────────────────────────────┤
│  TanStack DB       │  RxDB             │  PowerSync         │
│  - Collections     │  - Collections    │  - SQLite queries  │
│  - Live Queries    │  - Reactive       │  - Sync rules      │
│  - Mutations       │  - Replication    │  - Replication     │
├─────────────────────────────────────────────────────────────┤
│  MID LEVEL: Storage Library / Wrapper                        │
├─────────────────────────────────────────────────────────────┤
│  idb-keyval (~1KB) │  Dexie.js (~30KB) │  wa-sqlite         │
│  Just get/set      │  Full queries     │  SQLite in WASM    │
├─────────────────────────────────────────────────────────────┤
│  LOW LEVEL: Browser Storage API                              │
├─────────────────────────────────────────────────────────────┤
│  IndexedDB                             │  OPFS (Origin      │
│  (NoSQL key-value, ~50% of disk)       │  Private File Sys) │
└─────────────────────────────────────────────────────────────┘
```

### Storage Technologies Comparison

| Technology | Type | Used By | Size Limit | Query Support |
|------------|------|---------|------------|---------------|
| **localStorage** | Key-value | TanStack (default) | ~5MB | None |
| **IndexedDB** | NoSQL | RxDB, Dexie, idb-keyval | ~50% of disk | Indexes, cursors |
| **OPFS** | File system | PowerSync (SQLite) | ~50% of disk | Full SQL |
| **SQLite (WASM)** | Relational DB | PowerSync | Via OPFS | Full SQL |

### What Each Library Actually Does

**idb-keyval** (~1KB)
- Tiny wrapper around IndexedDB's clunky API
- Just `get(key)`, `set(key, value)`, `del(key)`
- Stores data as single JSON blobs
- No query capability - you load everything into memory
- *What we used in our custom adapter*

**Dexie.js** (~30KB)
- Full IndexedDB wrapper with query support
- Stores each record separately (not as JSON blob)
- Can query/filter at the IndexedDB level
- Used by RxDB as one of its storage backends

**RxDB** (~50KB+)
- Full reactive database layer
- Uses Dexie/IndexedDB/OPFS as storage backends
- Provides collections, schemas, replication
- Its own sync protocol (not ElectricSQL)

**PowerSync**
- Uses SQLite compiled to WebAssembly
- Stores data in OPFS (Origin Private File System)
- Full SQL query support
- Its own sync protocol with Postgres/MongoDB/MySQL

### Our Approach vs Proper Solutions

**What we did (idb-keyval hack):**
```
TanStack DB Collection
    ↓
localStorageCollectionOptions({ storage: idbStorage })
    ↓
Our idb-storage.ts wrapper
    ↓
idb-keyval (get/set)
    ↓
IndexedDB (single JSON blob per collection)
```

**How RxDB does it properly:**
```
TanStack DB Collection
    ↓
rxdbCollectionOptions({ rxCollection })
    ↓
RxDB Collection
    ↓
Dexie.js storage adapter
    ↓
IndexedDB (one record per document, with indexes)
```

**Key difference**: We store the entire 19K record collection as ONE JSON blob. RxDB stores each record separately with proper indexes. Our approach works but is less efficient for partial queries.

## Corrected Understanding: TanStack DB Architecture

### The Key Insight

**TanStack DB is NOT a database or sync engine.** It's a **reactive client store** - a query layer that sits on top of various data sources.

```
┌─────────────────────────────────────────────────────────────┐
│  APPLICATION LAYER                                           │
│  Your Svelte/React components                                │
├─────────────────────────────────────────────────────────────┤
│  CLIENT STORE LAYER  ←── TanStack DB                        │
│  - Reactive queries (sub-millisecond)                        │
│  - Optimistic mutations                                      │
│  - Normalized collections                                    │
│  - Framework bindings (React, Svelte, etc.)                  │
├─────────────────────────────────────────────────────────────┤
│  DATA SOURCE LAYER  (plug in ANY of these together)         │
├──────────────┬──────────────┬──────────────┬────────────────┤
│ ElectricSQL  │ RxDB         │ PowerSync    │ REST API       │
│ Collection   │ Collection   │ Collection   │ (TanStack      │
│              │              │              │  Query)        │
├──────────────┼──────────────┼──────────────┼────────────────┤
│ Electric     │ RxDB         │ PowerSync    │ HTTP           │
│ Sync Service │ Replication  │ Sync Service │ Requests       │
├──────────────┴──────────────┴──────────────┴────────────────┤
│  PERSISTENCE LAYER                                           │
├──────────────┬──────────────┬───────────────────────────────┤
│ (none -      │ IndexedDB    │ OPFS/SQLite                   │
│  memory only)│ (via Dexie)  │                               │
└──────────────┴──────────────┴───────────────────────────────┘
```

### RxDB and ElectricSQL: Complementary, Not Competing

**Previous (wrong) assumption**: RxDB and ElectricSQL compete for the same role.

**Correct understanding**: They can be **complementary**:

| Layer | ElectricSQL | RxDB | Together |
|-------|-------------|------|----------|
| Sync Protocol | HTTP Shape API | Pull/push handlers | Electric does sync |
| Server | Electric service | Custom backend | Electric service |
| Persistence | **None (memory)** | IndexedDB | RxDB does persistence |
| Client Queries | TanStack DB | TanStack DB | TanStack DB |

**The opportunity**: Use Electric for Postgres sync, RxDB for IndexedDB persistence, TanStack DB for reactive queries.

### Why Electric's TanStack Integration Has No Persistence

From Electric's docs: *"syncing into a database is out of scope of this guide"* and *"If you're interested in implementing it, raise an Issue or ask on Discord."*

The `@tanstack/electric-db-collection` deliberately uses memory-only storage because:
1. Electric is focused on the **sync** problem, not persistence
2. Persistence is seen as a separate concern
3. You can combine Electric with other collection types

### The Missing Integration

What doesn't exist yet (but could):
- An "Electric + RxDB" collection that uses Electric for sync and RxDB for persistence
- Or: Electric offset persistence built into the collection

This is why the author's promise ("megabytes upfront, then only changes") works in theory but requires custom implementation in practice.

## RxDB Integration Details

### What is RxDB?

RxDB is a **local-first, offline-capable NoSQL database** for JavaScript. Key features:
- Reactive data layer with RxJS observables
- Pluggable storage backends (localStorage, IndexedDB, SQLite, OPFS)
- Built-in replication with checkpoint-based sync
- Cross-tab synchronization
- Schema validation

### Using RxDB for Persistence (Without Its Sync)

We could use RxDB purely as a persistence layer:

```typescript
import { createRxDatabase } from 'rxdb/plugins/core'
import { getRxStorageDexie } from 'rxdb/plugins/storage-dexie'

// RxDB provides IndexedDB persistence
const db = await createRxDatabase({
  name: 'sertantai-legal',
  storage: getRxStorageDexie()
})

await db.addCollections({
  uk_lrt: { schema: ukLrtSchema }
})

// We manually sync from Electric into RxDB
electricStream.subscribe((messages) => {
  messages.forEach((msg) => {
    if (msg.headers.operation === 'insert') {
      db.uk_lrt.insert(msg.value)
    }
    // ... handle updates, deletes
  })
})

// TanStack DB wraps RxDB for reactive queries
const collection = createCollection(
  rxdbCollectionOptions({ rxCollection: db.uk_lrt })
)
```

This gives us:
- Electric's Postgres sync (real-time, efficient)
- RxDB's IndexedDB persistence (survives page reload)
- TanStack DB's reactive queries (fast UI updates)

## Comparison: Homegrown vs RxDB Solution

### Option A: Our Homegrown IndexedDB Adapter

**What we built:**
- `idb-storage.ts` - Custom IndexedDB adapter using `idb-keyval`
- Wraps `localStorageCollectionOptions` with custom storage
- Manual Electric sync via `sync-uk-lrt.ts`

**Pros:**
- Lightweight (~3KB for idb-keyval)
- Simple, focused on our exact needs
- Full control over implementation
- No extra abstraction layers
- Already implemented and working

**Cons:**
- We maintain it
- Missing: Electric offset persistence (re-downloads all data on reload)
- Missing: Cross-tab sync
- No schema validation at storage layer
- No built-in conflict handling

**To complete the solution, we need to add:**
1. Persist Electric offset/handle to IndexedDB
2. Load offset on startup, pass to ShapeStream

### Option B: RxDB as Storage Layer

**What it would look like:**
- RxDB with Dexie storage (IndexedDB)
- `rxdbCollectionOptions` for TanStack DB integration
- Still manual Electric sync (RxDB replication unused)

**Pros:**
- Battle-tested IndexedDB handling
- Cross-tab sync built-in
- Schema validation
- Reactive change streams

**Cons:**
- Heavy dependency (RxDB is ~50KB+ gzipped)
- Using only ~20% of RxDB's features (just storage)
- Still need to manually persist Electric offset
- Extra abstraction layer
- Schema must be defined twice (TypeScript + RxDB JSON schema)

### Option C: RxDB with Custom Electric Replication

**What it would look like:**
- RxDB with Dexie storage
- Custom `pullHandler` that uses Electric's ShapeStream
- RxDB manages checkpoints (mapped to Electric offset)

**Pros:**
- Best of both worlds: RxDB persistence + Electric sync
- Automatic checkpoint/offset persistence
- Cross-tab sync
- Full offline support

**Cons:**
- Complex integration work
- Must map Electric's offset to RxDB checkpoint format
- Electric's shape changes might break RxDB state
- Significant implementation effort
- Unclear if this is supported/tested pattern

### Option D: Wait for Official Electric + RxDB Integration

TanStack has packages for both Electric and RxDB. A combined solution may emerge.

## Decision: Option A (Homegrown IndexedDB Adapter)

**Chosen approach**: Keep and enhance our homegrown `idb-storage.ts` solution.

**Rationale**:
- This is admin UI - simpler solution is appropriate
- Already implemented and working
- Lightweight (~1KB idb-keyval vs ~50KB+ RxDB)
- Full control, no extra abstractions
- Research documented for future user-facing UI that may need RxDB

## Completed: Electric Offset Persistence (Delta Sync)

**Implementation complete** - Added Electric offset persistence to enable true delta sync.

### Changes to `idb-storage.ts`

Added sync state persistence functions:
```typescript
// Dedicated store for Electric sync metadata
const syncMetaStore = createStore('sertantai-legal-db', 'sync-meta');

export interface ElectricSyncState {
  offset: string;
  handle?: string;
  lastSyncTime: string;
  recordCount: number;
}

export async function saveElectricSyncState(shapeKey: string, state: ElectricSyncState): Promise<void>
export async function loadElectricSyncState(shapeKey: string): Promise<ElectricSyncState | null>
export async function clearElectricSyncState(shapeKey: string): Promise<void>
```

### Changes to `sync-uk-lrt.ts`

1. **Shape key includes WHERE clause hash** - Different filters have separate sync states:
```typescript
function getShapeKey(whereClause: string): string {
  const hash = whereClause.split('').reduce((acc, char) => {
    return ((acc << 5) - acc + char.charCodeAt(0)) | 0;
  }, 0);
  return `${UK_LRT_SHAPE_KEY}-${hash}`;
}
```

2. **Load saved offset on startup**:
```typescript
const savedState = await loadElectricSyncState(shapeKey);

if (savedState?.offset) {
  streamOptions.offset = savedState.offset as Offset;
  streamOptions.handle = savedState.handle;
  console.log(`[Electric Sync] Resuming from offset ${savedState.offset}`);
}
```

3. **Save offset on "up-to-date" control message**:
```typescript
if (msg.headers.control === 'up-to-date' && latestOffset) {
  saveElectricSyncState(shapeKey, {
    offset: latestOffset,
    handle: latestHandle,
    lastSyncTime: new Date().toISOString(),
    recordCount: ukLrtCollection.size
  });
}
```

4. **Added force full resync function**:
```typescript
export async function forceFullResync() {
  await clearElectricSyncState(getShapeKey(currentWhereClause));
  await syncUkLrt(currentWhereClause, false, true);
}
```

### Sync Flow Now

```
First Visit:
1. No saved offset → Download all 19K records
2. On "up-to-date" → Save offset to IndexedDB

Subsequent Visits:
1. Load data from IndexedDB → Show immediately
2. Load saved offset from IndexedDB
3. Start Electric sync WITH saved offset
4. Only download records changed since last sync
5. Update IndexedDB with changes
6. Save new offset to IndexedDB
```

**Future (user-facing UI)**:

When building the public user interface, consider:
- RxDB for proper IndexedDB persistence with per-record storage
- Electric + RxDB integration for robust offline support
- The research in this session provides the foundation

## Future Improvements

1. ~~Consider implementing progressive sync like sertantai-enforcement (recent records first)~~ ✅ ALREADY IMPLEMENTED - Default filter is `year >= 2024` which loads only ~585 records instead of 19K. The localStorage quota issue only occurred when users explicitly loaded the full dataset.
2. Add batch processing with `requestIdleCallback` for large datasets (only needed if users load full 19K)
3. Implement SearchShapeManager pattern for filter-based caching (cache multiple WHERE clause shapes)
4. ~~**Persist Electric offset** to IndexedDB for true delta-only sync on subsequent visits~~ ✅ DONE
5. Consider cross-tab sync using BroadcastChannel API

**Ended**: 2026-01-07 17:08
