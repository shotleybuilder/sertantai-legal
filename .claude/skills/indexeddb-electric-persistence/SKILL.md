# SKILL: IndexedDB Persistence for ElectricSQL + TanStack DB

**Purpose:** Enable persistent offline storage for ElectricSQL-synced data using IndexedDB, with delta sync support across page reloads.

**Context:** ElectricSQL, TanStack DB, idb-keyval, IndexedDB, Svelte

**When to Use:**
- Syncing large datasets (>5MB) that exceed localStorage limits
- Need data to persist across page reloads
- Want delta sync (only download changes on subsequent visits)
- Building offline-first features with ElectricSQL

---

## Core Principles

### 1. TanStack DB is Storage-Agnostic

TanStack DB is a **reactive client store**, not a database. It sits on top of various storage backends:

| Collection Type | Storage | Persistence | Size Limit |
|-----------------|---------|-------------|------------|
| `electricCollectionOptions` | Memory | None | RAM only |
| `localStorageCollectionOptions` | localStorage | Yes | ~5MB |
| Custom IndexedDB adapter | IndexedDB | Yes | ~50% disk |

### 2. ElectricSQL Doesn't Persist by Default

The `@tanstack/electric-db-collection` uses **memory-only storage**:
- First visit: Downloads all data
- Page reload: Downloads all data again
- No persistence between sessions

### 3. True Delta Sync Requires Two Things

1. **Data persistence** - Store records in IndexedDB
2. **Offset persistence** - Store Electric's sync position to resume from

### 4. idb-keyval Limitation

`idb-keyval`'s `createStore()` only supports **one object store per database**. Use separate database names for different stores.

---

## Common Pitfalls & Solutions

### Pitfall 1: localStorage Quota Exceeded

```
DOMException: The quota has been exceeded
```

**Cause:** localStorage has ~5MB limit. Large datasets (e.g., 19K records) exceed this.

❌ **Wrong:**
```typescript
// Using default localStorage
ukLrtCol = createCollection(
  localStorageCollectionOptions<UkLrtRecord, string>({
    storageKey: 'uk-lrt',
    getKey: (item) => item.id
  })
);
```

✅ **Right:**
```typescript
// Use IndexedDB adapter
const idbStorage = await initializeIDBStorage(['uk-lrt']);
ukLrtCol = createCollection(
  localStorageCollectionOptions<UkLrtRecord, string>({
    storageKey: 'uk-lrt',
    getKey: (item) => item.id,
    storage: idbStorage  // Custom IndexedDB storage
  })
);
```

### Pitfall 2: Multiple idb-keyval Stores in Same Database

```
DOMException: IDBDatabase.transaction: 'store-name' is not a known object store name
```

**Cause:** `createStore('db-name', 'store-1')` creates a database. Calling `createStore('db-name', 'store-2')` fails because the DB already exists with only `store-1`.

❌ **Wrong:**
```typescript
const dataStore = createStore('my-app-db', 'data');
const metaStore = createStore('my-app-db', 'metadata');  // Fails!
```

✅ **Right:**
```typescript
// Use separate databases
const dataStore = createStore('my-app-db', 'data');
const metaStore = createStore('my-app-sync-meta', 'state');  // Different DB name
```

### Pitfall 3: Stale Offset with Empty Collection

**Cause:** Browser storage cleared but sync offset still exists. Electric resumes from offset, gets no data.

❌ **Wrong:**
```typescript
if (savedState?.offset) {
  streamOptions.offset = savedState.offset;  // Resumes from old offset
}
// Collection is empty, no data loaded!
```

✅ **Right:**
```typescript
const collectionSize = ukLrtCollection.size;
const shouldUseOffset = savedState?.offset && collectionSize > 0;

if (shouldUseOffset) {
  streamOptions.offset = savedState.offset;
} else if (savedState?.offset && collectionSize === 0) {
  // Clear stale offset, do fresh sync
  await clearElectricSyncState(shapeKey);
}
```

### Pitfall 4: Insert Collision with Cached Data

```
CollectionOperationError: Cannot insert document with ID "xxx" because it already exists
```

**Cause:** Electric sends `insert` for records already in IndexedDB cache.

❌ **Wrong:**
```typescript
case 'insert':
  ukLrtCollection.insert(data);  // Throws if exists
  break;
```

✅ **Right:**
```typescript
case 'insert':
  // Upsert: update if exists, insert if not
  if (ukLrtCollection.has(data.id)) {
    ukLrtCollection.update(data.id, (draft) => {
      Object.assign(draft, data);
    });
  } else {
    ukLrtCollection.insert(data);
  }
  break;
```

### Pitfall 5: subscribeChanges Not Firing

**Cause:** TanStack DB's `subscribeChanges()` may not fire for programmatic updates via `insert`/`update`.

❌ **Wrong:**
```typescript
collectionSubscription = collection.subscribeChanges(() => {
  data = collection.toArray;  // Never called!
});
```

✅ **Right:**
```typescript
// Subscribe to syncStatus store instead
const unsubscribeSyncStatus = syncStatus.subscribe((status) => {
  if (status.connected && !status.syncing) {
    data = collection.toArray;  // Refresh when sync completes
  }
});
```

### Pitfall 6: Unsubscribe Loses `this` Context

```
TypeError: this is undefined
```

**Cause:** Extracting `unsubscribe` method loses `this` binding.

❌ **Wrong:**
```typescript
const originalUnsubscribe = subscription?.unsubscribe;
// Later...
originalUnsubscribe?.();  // `this` is undefined!
```

✅ **Right:**
```typescript
const originalSubscription = subscription;
// Later...
originalSubscription?.unsubscribe();  // Correct context
```

---

## Working Patterns

### Complete IndexedDB Storage Adapter

**File: `src/lib/db/idb-storage.ts`**

```typescript
import { get, set, del, createStore } from 'idb-keyval';

export interface StorageInterface {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

// Separate databases for data and sync metadata
const dataStore = createStore('sertantai-legal-db', 'collections');
const syncMetaStore = createStore('sertantai-legal-sync-meta', 'sync-state');

class IndexedDBStorage implements StorageInterface {
  private cache: Map<string, string> = new Map();
  private initialized = false;

  async initialize(keys: string[]): Promise<void> {
    if (this.initialized) return;
    
    for (const key of keys) {
      const value = await get<string>(key, dataStore);
      if (value !== undefined) {
        this.cache.set(key, value);
      }
    }
    this.initialized = true;
  }

  getItem(key: string): string | null {
    return this.cache.get(key) ?? null;
  }

  setItem(key: string, value: string): void {
    this.cache.set(key, value);
    set(key, value, dataStore);  // Async persist
  }

  removeItem(key: string): void {
    this.cache.delete(key);
    del(key, dataStore);
  }
}

let idbStorage: IndexedDBStorage | null = null;

export async function initializeIDBStorage(keys: string[]): Promise<StorageInterface> {
  if (!idbStorage) {
    idbStorage = new IndexedDBStorage();
  }
  await idbStorage.initialize(keys);
  return idbStorage;
}

// Electric Sync State Persistence
export interface ElectricSyncState {
  offset: string;
  handle?: string;
  lastSyncTime: string;
  recordCount: number;
}

export async function saveElectricSyncState(
  shapeKey: string,
  state: ElectricSyncState
): Promise<void> {
  await set(shapeKey, state, syncMetaStore);
}

export async function loadElectricSyncState(
  shapeKey: string
): Promise<ElectricSyncState | null> {
  return (await get<ElectricSyncState>(shapeKey, syncMetaStore)) ?? null;
}

export async function clearElectricSyncState(shapeKey: string): Promise<void> {
  await del(shapeKey, syncMetaStore);
}
```

### Collection Initialization with IndexedDB

**File: `src/lib/db/index.client.ts`**

```typescript
import { browser } from '$app/environment';
import { createCollection, localStorageCollectionOptions } from '@tanstack/db';
import { initializeIDBStorage } from './idb-storage';
import type { Collection } from '@tanstack/db';

const STORAGE_KEY = 'my-collection';
let collection: Collection<MyRecord, string> | null = null;

export async function getCollection(): Promise<Collection<MyRecord, string>> {
  if (!browser) {
    throw new Error('Collections can only be used in browser');
  }

  if (!collection) {
    const idbStorage = await initializeIDBStorage([STORAGE_KEY]);
    
    collection = createCollection(
      localStorageCollectionOptions<MyRecord, string>({
        storageKey: STORAGE_KEY,
        getKey: (item) => item.id,
        storage: idbStorage
      })
    );
  }

  return collection;
}
```

### Electric Sync with Offset Persistence

**File: `src/lib/electric/sync.ts`**

```typescript
import { ShapeStream, type Offset } from '@electric-sql/client';
import { getCollection } from '$lib/db/index.client';
import {
  saveElectricSyncState,
  loadElectricSyncState,
  clearElectricSyncState
} from '$lib/db/idb-storage';
import { writable } from 'svelte/store';

const ELECTRIC_URL = 'http://localhost:3002';
const SHAPE_KEY = 'my-shape';

export const syncStatus = writable({
  connected: false,
  syncing: false,
  recordCount: 0
});

function getShapeKey(whereClause: string): string {
  // Hash WHERE clause for separate sync states per filter
  const hash = whereClause.split('').reduce((acc, char) => {
    return ((acc << 5) - acc + char.charCodeAt(0)) | 0;
  }, 0);
  return `${SHAPE_KEY}-${hash}`;
}

export async function startSync(whereClause: string) {
  const collection = await getCollection();
  const shapeKey = getShapeKey(whereClause);
  
  // Load saved sync state
  const savedState = await loadElectricSyncState(shapeKey);
  const collectionSize = collection.size;
  
  // Build stream options
  const streamOptions: {
    url: string;
    params: { table: string; where: string };
    offset?: Offset;
    handle?: string;
  } = {
    url: `${ELECTRIC_URL}/v1/shape`,
    params: { table: 'my_table', where: whereClause }
  };

  // Use saved offset only if we have cached data
  if (savedState?.offset && collectionSize > 0) {
    streamOptions.offset = savedState.offset as Offset;
    if (savedState.handle) {
      streamOptions.handle = savedState.handle;
    }
    console.log(`Resuming from offset ${savedState.offset}`);
  } else {
    // Clear stale offset if collection is empty
    if (savedState?.offset && collectionSize === 0) {
      await clearElectricSyncState(shapeKey);
    }
    console.log('Starting fresh sync');
  }

  syncStatus.set({ connected: false, syncing: true, recordCount: 0 });

  const stream = new ShapeStream(streamOptions);
  let latestOffset: string | undefined;
  let latestHandle: string | undefined;

  stream.subscribe((messages) => {
    messages.forEach((msg: any) => {
      // Track offset
      if (msg.offset) latestOffset = msg.offset;
      if (msg.headers?.handle) latestHandle = msg.headers.handle;

      // Handle control messages
      if (msg.headers?.control) {
        if (msg.headers.control === 'up-to-date' && latestOffset) {
          // Save sync state for next visit
          saveElectricSyncState(shapeKey, {
            offset: latestOffset,
            handle: latestHandle,
            lastSyncTime: new Date().toISOString(),
            recordCount: collection.size
          });
          
          syncStatus.set({
            connected: true,
            syncing: false,
            recordCount: collection.size
          });
        }
        return;
      }

      // Process data messages with upsert logic
      const operation = msg.headers?.operation;
      const data = transformRecord(msg.value);

      if (operation === 'insert' || operation === 'update') {
        if (collection.has(data.id)) {
          collection.update(data.id, (draft) => Object.assign(draft, data));
        } else {
          collection.insert(data);
        }
      } else if (operation === 'delete') {
        if (collection.has(data.id)) {
          collection.delete(data.id);
        }
      }
    });
  });
}
```

### Svelte Page Integration

```svelte
<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { getCollection } from '$lib/db/index.client';
  import { startSync, syncStatus } from '$lib/electric/sync';

  let data: MyRecord[] = [];
  let unsubscribeSyncStatus: (() => void) | null = null;

  onMount(async () => {
    const collection = await getCollection();
    
    // Load cached data immediately
    data = collection.toArray;
    
    // Refresh when sync status changes
    unsubscribeSyncStatus = syncStatus.subscribe((status) => {
      if (status.connected && !status.syncing) {
        data = collection.toArray;
      }
    });
    
    // Start sync in background
    startSync('year >= 2024');
  });

  onDestroy(() => {
    unsubscribeSyncStatus?.();
  });
</script>

{#if $syncStatus.syncing}
  <p>Syncing...</p>
{:else}
  <p>{data.length} records</p>
{/if}
```

---

## Troubleshooting

### "Quota exceeded" error
- **Cause:** Using localStorage for large datasets
- **Fix:** Switch to IndexedDB adapter

### "Object store not found" error
- **Cause:** Multiple `createStore()` calls with same DB name
- **Fix:** Use different database names for each store

### Data loads but shows 0 records
- **Cause:** Stale offset resuming from wrong position
- **Fix:** Check collection size before using saved offset

### "Cannot insert document" error
- **Cause:** Electric insert for existing record
- **Fix:** Use upsert logic (check `has()` before insert)

### Data doesn't update in UI
- **Cause:** `subscribeChanges` not firing
- **Fix:** Subscribe to `syncStatus` store instead

### "this is undefined" on navigation
- **Cause:** Extracted method lost context
- **Fix:** Store subscription object, call `unsubscribe()` on it

---

## Quick Reference

### Dependencies
```bash
npm install idb-keyval
```

### Key Files
```
src/lib/db/
  idb-storage.ts      # IndexedDB adapter + sync state
  index.client.ts     # Collection initialization

src/lib/electric/
  sync.ts             # Electric sync with offset persistence
```

### Sync State Flow
```
First Visit:
  1. Empty collection → Fresh sync (offset=-1)
  2. Download all records
  3. Save offset to IndexedDB

Subsequent Visits:
  1. Load data from IndexedDB → Show immediately
  2. Load offset from IndexedDB
  3. Resume sync from offset → Only changes
  4. Update offset in IndexedDB
```

### Storage Databases
```
sertantai-legal-db          # Collection data
  └── collections store

sertantai-legal-sync-meta   # Sync metadata
  └── sync-state store
```

---

## Related Skills

- [ElectricSQL Sync Setup](../electricsql-sync-setup/) - Basic Electric setup
- [Creating Ash Resources](../creating-ash-resources/) - Backend resource definitions

---

## Key Takeaways

**Do:**
- Use IndexedDB for datasets >5MB
- Use separate databases for idb-keyval stores
- Persist Electric offset for delta sync
- Check collection size before using saved offset
- Use upsert logic for Electric operations
- Subscribe to sync status store for UI updates

**Don't:**
- Use localStorage for large datasets
- Create multiple stores in same idb-keyval database
- Resume from offset without checking collection has data
- Extract unsubscribe methods (loses `this` context)
- Rely solely on `subscribeChanges` for UI updates
