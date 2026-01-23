# SKILL: ElectricSQL + TanStack DB Sync Setup

**Purpose:** Set up real-time data sync between PostgreSQL and the browser using ElectricSQL with the official TanStack DB integration.

**Context:** ElectricSQL, TanStack DB, @tanstack/electric-db-collection, Svelte/SvelteKit

**When to Use:**
- Setting up real-time sync for a new resource
- Fixing sync issues (stuck status, browser crashes, data not loading)
- Migrating from manual ShapeStream to the official pattern
- Adding server-side filtering to synced data

---

## Core Principles

### 1. Use `electricCollectionOptions` - The Official Pattern

The `@tanstack/electric-db-collection` package provides `electricCollectionOptions()` which is the **official, correct way** to connect ElectricSQL to TanStack DB.

**Key Understanding:**
- It handles ShapeStream lifecycle internally
- It batches updates efficiently (no browser crash)
- It manages reactive state updates automatically
- It tracks sync status (`isReady()`, `status`)

### 2. Don't Manually Subscribe to ShapeStream

Manual ShapeStream subscription with `collection.insert()` is an anti-pattern that causes:
- Browser crashes from excessive reactive updates
- Memory exhaustion from unbatched operations
- Sync status bugs from improper state management

### 3. PostgreSQL Generated Columns Cannot Be Synced

Electric cannot sync PostgreSQL generated columns. You must explicitly exclude them using the `columns` parameter.

### 4. Type Constraints for Electric

Electric's `Row<unknown>` type requires an index signature. Your record types must satisfy this constraint with `& Record<string, unknown>`.

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Manual ShapeStream + collection.insert()

**Why it fails:**
Each `insert()` call triggers reactive updates and storage writes. With thousands of records, this crashes the browser.

```typescript
// WRONG - Manual ShapeStream subscription
const stream = new ShapeStream({
  url: `${ELECTRIC_URL}/v1/shape`,
  params: { table: 'my_table' }
});

stream.subscribe((messages) => {
  messages.forEach((msg) => {
    if (msg.headers?.operation === 'insert') {
      collection.insert(msg.value);  // 💥 Triggers reactive update for EACH record
    }
  });
});
```

**✅ Correct Pattern:**
```typescript
import { createCollection } from '@tanstack/db';
import { electricCollectionOptions } from '@tanstack/electric-db-collection';

const collection = createCollection(
  electricCollectionOptions<MyRecord>({
    id: 'my-collection',
    shapeOptions: {
      url: `${ELECTRIC_URL}/v1/shape`,
      params: { table: 'my_table' }
    },
    getKey: (item) => item.id
  })
);
```

### ❌ Pitfall 2: Syncing PostgreSQL Generated Columns

**Why it fails:**
Electric returns HTTP 400 error when trying to sync generated columns.

```
FetchError: HTTP Error 400: Bad Request
// Error: Cannot sync generated column "my_computed_field"
```

**✅ Correct Pattern:**
Explicitly list columns, excluding generated ones:

```typescript
const COLUMNS = [
  'id',
  'name',
  'title',
  'created_at',
  // Do NOT include generated columns like 'computed_url', 'full_name', etc.
].join(',');

const collection = createCollection(
  electricCollectionOptions<MyRecord>({
    id: 'my-collection',
    shapeOptions: {
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'my_table',
        columns: COLUMNS  // Explicit whitelist
      }
    },
    getKey: (item) => item.id
  })
);
```

### ❌ Pitfall 3: TypeScript Type Doesn't Satisfy Row<unknown>

**Why it fails:**
Electric requires types with index signatures. Interface types without `[key: string]: unknown` fail.

```typescript
// WRONG - No index signature
interface MyRecord {
  id: string;
  name: string;
}

// Error: Type 'MyRecord' does not satisfy the constraint 'Row<unknown>'.
// Index signature for type 'string' is missing in type 'MyRecord'.
```

**✅ Correct Pattern:**
Add index signature to your type:

```typescript
// Define base type
interface MyRecord {
  id: string;
  name: string;
}

// Create Electric-compatible type with index signature
type ElectricMyRecord = MyRecord & Record<string, unknown>;

// Use Electric-compatible type with electricCollectionOptions
const collection = createCollection(
  electricCollectionOptions<ElectricMyRecord>({
    id: 'my-collection',
    shapeOptions: { ... },
    getKey: (item) => item.id as string
  })
);
```

### ❌ Pitfall 4: Using state.isReady Instead of isReady()

**Why it fails:**
`state.isReady` doesn't exist on TanStack DB collections. The correct API is `collection.isReady()` method.

```typescript
// WRONG
const isReady = collection.state.isReady;  // Property 'isReady' does not exist

// CORRECT
const isReady = collection.isReady();  // Method call
```

### ❌ Pitfall 5: Sync Status Stuck on "Syncing"

**Why it fails:**
Only checking for data messages, not handling `up-to-date` control message.

**✅ Correct Pattern:**
Use `collection.isReady()` or subscribe to changes:

```typescript
const checkSyncStatus = () => {
  const isReady = collection.isReady();
  const recordCount = collection.size;
  
  syncStatus.update((s) => ({
    ...s,
    connected: true,
    syncing: !isReady,
    recordCount,
    lastSyncTime: isReady ? new Date() : s.lastSyncTime
  }));
};

// Subscribe to collection changes
collection.subscribeChanges(() => {
  checkSyncStatus();
});
```

### ❌ Pitfall 6: Browser Crash with Large Datasets (Even with electricCollectionOptions)

**Why it fails:**
Even with the official `electricCollectionOptions`, large datasets (500+ records) can crash the browser due to:
- Default `eager` sync mode loading everything at once
- Excessive reactive updates from `subscribeChanges`
- UI re-renders on every collection change

**✅ Correct Pattern:**
Use `progressive` sync mode + debounced updates:

```typescript
const collection = createCollection(
  electricCollectionOptions<ElectricMyRecord>({
    id: 'my-collection',
    syncMode: 'progressive',  // 👈 Key: Use progressive for large datasets
    shapeOptions: {
      url: `${ELECTRIC_URL}/v1/shape`,
      params: {
        table: 'my_table',
        where: whereClause,
        columns: COLUMNS
      }
    },
    getKey: (item) => item.id as string
  })
);

// Debounce sync status updates to prevent UI thrashing
let statusDebounceTimer: ReturnType<typeof setTimeout> | null = null;
const checkSyncStatus = () => {
  if (statusDebounceTimer) clearTimeout(statusDebounceTimer);
  statusDebounceTimer = setTimeout(() => {
    syncStatus.update((s) => ({
      ...s,
      connected: true,
      syncing: !collection.isReady(),
      recordCount: collection.size
    }));
  }, 100);  // 100ms debounce
};
```

**Sync Mode Options:**
| Mode | Behavior | Use When |
|------|----------|----------|
| `eager` (default) | Downloads all data before ready | Small datasets (<100 records) |
| `progressive` | Incremental snapshots, ready after full sync | Large datasets (100-10k records) |
| `on-demand` | Syncs when queried, ready after first snapshot | Very large datasets, paginated views |

### ❌ Pitfall 7: Double Subscription Causing Excessive Updates

**Why it fails:**
Subscribing to BOTH `collection.subscribeChanges()` AND `syncStatus` causes double refreshes on every change.

```typescript
// WRONG - Double subscription
collection.subscribeChanges(() => refreshData());  // Fires on every change
syncStatus.subscribe((status) => {
  if (status.connected) refreshData();  // Also fires on every change!
});
```

**✅ Correct Pattern:**
Subscribe to `syncStatus` only - it's already debounced:

```typescript
// Only subscribe to syncStatus for UI updates
const unsubscribeSyncStatus = syncStatus.subscribe((status) => {
  if (status.connected) {
    refreshData();
    if (!status.syncing) {
      isLoading = false;
    }
  }
});
```

---

## Working Patterns

### Pattern 1: Complete Collection Setup with Electric

**File: `src/lib/db/index.client.ts`**

```typescript
import { browser } from '$app/environment';
import type { Collection } from '@tanstack/db';
import { writable } from 'svelte/store';
import type { MyRecord } from '$lib/types/my-record';

// Re-export for external use
export type { MyRecord } from '$lib/types/my-record';

// Type that satisfies Electric's Row constraint
type ElectricMyRecord = MyRecord & Record<string, unknown>;

const ELECTRIC_URL = import.meta.env.VITE_ELECTRIC_URL || 'http://localhost:3002';

/**
 * Columns to sync - excludes PostgreSQL generated columns
 */
const COLUMNS = [
  'id',
  'name',
  'title',
  'description',
  'status',
  'created_at',
  'updated_at'
].join(',');

// Collection singleton
let collection: Collection<ElectricMyRecord, string> | null = null;
let currentWhereClause: string = '';

// Sync status store
export interface SyncStatus {
  connected: boolean;
  syncing: boolean;
  offline: boolean;
  recordCount: number;
  lastSyncTime: Date | null;
  error: string | null;
  whereClause: string;
}

export const syncStatus = writable<SyncStatus>({
  connected: false,
  syncing: true,
  offline: false,
  recordCount: 0,
  lastSyncTime: null,
  error: null,
  whereClause: ''
});

/**
 * Get default WHERE clause
 */
function getDefaultWhere(): string {
  const currentYear = new Date().getFullYear();
  return `year >= ${currentYear - 2}`;
}

/**
 * Create collection with Electric sync
 */
async function createMyCollection(
  whereClause: string
): Promise<Collection<ElectricMyRecord, string>> {
  const { createCollection } = await import('@tanstack/db');
  const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

  currentWhereClause = whereClause;

  syncStatus.update((s) => ({
    ...s,
    syncing: true,
    whereClause,
    error: null
  }));

  const col = createCollection(
    electricCollectionOptions<ElectricMyRecord>({
      id: 'my-collection',
      syncMode: 'progressive',  // Use progressive for large datasets (500+ records)
      shapeOptions: {
        url: `${ELECTRIC_URL}/v1/shape`,
        params: {
          table: 'my_table',
          where: whereClause,
          columns: COLUMNS
        }
      },
      getKey: (item) => item.id as string
    })
  );

  // Monitor sync status (debounced to prevent excessive updates)
  let statusDebounceTimer: ReturnType<typeof setTimeout> | null = null;
  const checkSyncStatus = () => {
    if (statusDebounceTimer) clearTimeout(statusDebounceTimer);
    statusDebounceTimer = setTimeout(() => {
      const isReady = col.isReady();
      const recordCount = col.size;

      syncStatus.update((s) => ({
        ...s,
        connected: true,
        syncing: !isReady,
        recordCount,
        lastSyncTime: isReady ? new Date() : s.lastSyncTime
      }));
    }, 100);  // 100ms debounce
  };

  // Subscribe to collection changes
  col.subscribeChanges(() => {
    checkSyncStatus();
  });

  // Initial status (immediate)
  syncStatus.update((s) => ({
    ...s,
    connected: true,
    syncing: true,
    recordCount: col.size
  }));

  console.log(`[TanStack DB] Collection initialized with WHERE: ${whereClause}`);

  return col;
}

/**
 * Get collection (creates on first call)
 */
export async function getMyCollection(
  whereClause?: string
): Promise<Collection<ElectricMyRecord, string>> {
  if (!browser) {
    throw new Error('Collections can only be used in the browser');
  }

  const where = whereClause || getDefaultWhere();

  // Return existing if WHERE unchanged
  if (collection && currentWhereClause === where) {
    return collection;
  }

  // Create new collection
  collection = await createMyCollection(where);
  return collection;
}

/**
 * Update WHERE clause (recreates collection)
 */
export async function updateMyWhere(whereClause: string): Promise<void> {
  if (!browser) return;
  collection = await createMyCollection(whereClause);
}

/**
 * Build WHERE clause from filter conditions
 */
export function buildWhereFromFilters(
  filters: Array<{ field: string; operator: string; value: unknown }>
): string {
  if (!filters || filters.length === 0) {
    return getDefaultWhere();
  }

  const escapeValue = (value: string): string => value.replace(/'/g, "''");

  const clauses = filters
    .map((filter) => {
      const { field, operator, value } = filter;

      switch (operator) {
        case 'equals':
          return typeof value === 'string'
            ? `${field} = '${escapeValue(String(value))}'`
            : `${field} = ${value}`;
        case 'contains':
          return `${field} ILIKE '%${escapeValue(String(value))}%'`;
        case 'greater_or_equal':
          return `${field} >= ${value}`;
        case 'less_or_equal':
          return `${field} <= ${value}`;
        default:
          return null;
      }
    })
    .filter(Boolean);

  return clauses.length > 0 ? clauses.join(' AND ') : getDefaultWhere();
}
```

### Pattern 2: Svelte Page Integration

```svelte
<script lang="ts">
  import { browser } from '$app/environment';
  import { onMount, onDestroy } from 'svelte';
  import {
    getMyCollection,
    updateMyWhere,
    buildWhereFromFilters,
    syncStatus
  } from '$lib/db/index.client';
  import type { MyRecord } from '$lib/db/index.client';

  let data: MyRecord[] = [];
  let isLoading = true;
  let error: string | null = null;
  let collectionSubscription: { unsubscribe: () => void } | null = null;

  async function initSync() {
    try {
      error = null;
      isLoading = true;

      // Get collection (creates Electric-synced collection)
      const collection = await getMyCollection();

      // Debounced refresh to prevent excessive UI updates
      let refreshDebounceTimer: ReturnType<typeof setTimeout> | null = null;
      const refreshData = () => {
        if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
        refreshDebounceTimer = setTimeout(() => {
          const newData = collection.toArray as MyRecord[];
          data = newData;
          if (newData.length > 0) {
            isLoading = false;
          }
        }, 200);  // 200ms debounce
      };

      // Only subscribe to syncStatus - it's already debounced
      // Don't also subscribe to collection.subscribeChanges() (causes double updates)
      const unsubscribeSyncStatus = syncStatus.subscribe((status) => {
        if (status.connected) {
          refreshData();
          if (!status.syncing) {
            isLoading = false;
          }
        }
        if (status.error) {
          error = status.error;
          isLoading = false;
        }
      });

      // Store cleanup
      collectionSubscription = {
        unsubscribe: () => {
          unsubscribeSyncStatus();
          if (refreshDebounceTimer) clearTimeout(refreshDebounceTimer);
        }
      };

      // Initial data load (immediate, no debounce)
      const initialData = collection.toArray as MyRecord[];
      if (initialData.length > 0) {
        data = initialData;
        isLoading = false;
      }

    } catch (e) {
      console.error('Failed to initialize sync:', e);
      error = e instanceof Error ? e.message : 'Failed to initialize';
      isLoading = false;
    }
  }

  function handleFilterChange(filters: Array<{ field: string; operator: string; value: unknown }>) {
    const newWhere = buildWhereFromFilters(filters);
    updateMyWhere(newWhere);
  }

  onMount(() => {
    if (browser) {
      initSync();
    }
  });

  onDestroy(() => {
    collectionSubscription?.unsubscribe();
  });
</script>

{#if isLoading}
  <div class="loading">
    <span class="spinner"></span>
    <p>Loading data...</p>
  </div>
{:else if error}
  <div class="error">
    <p>Error: {error}</p>
    <button on:click={initSync}>Retry</button>
  </div>
{:else}
  <!-- Sync Status Indicator -->
  <div class="sync-status">
    {#if $syncStatus.syncing}
      <span class="status syncing">Syncing...</span>
    {:else if $syncStatus.connected}
      <span class="status connected">Connected ({$syncStatus.recordCount} records)</span>
    {:else if $syncStatus.offline}
      <span class="status offline">Offline</span>
    {:else}
      <span class="status disconnected">Disconnected</span>
    {/if}
  </div>

  <!-- Data Display -->
  <ul>
    {#each data as item (item.id)}
      <li>{item.name}</li>
    {/each}
  </ul>
{/if}
```

### Pattern 3: Finding Generated Columns to Exclude

Run this SQL to find generated columns in your table:

```sql
SELECT column_name, generation_expression
FROM information_schema.columns
WHERE table_name = 'my_table'
  AND generation_expression IS NOT NULL;
```

Or in Elixir:

```elixir
# Via Ecto
query = """
SELECT column_name, generation_expression
FROM information_schema.columns
WHERE table_name = 'my_table'
  AND generation_expression IS NOT NULL
"""
Ecto.Adapters.SQL.query!(MyApp.Repo, query)
```

---

## Backend Setup (PostgreSQL + Electric)

### Required Migration Setup

```elixir
# In migration file
def change do
  create table(:my_table, primary_key: false) do
    add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
    add :name, :string, null: false
    add :title, :string
    add :status, :string, default: "active"
    
    timestamps(type: :utc_datetime)
  end

  # Enable Electric sync
  execute "ALTER TABLE my_table REPLICA IDENTITY FULL"
end
```

### Docker Compose for Electric

```yaml
# docker-compose.dev.yml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: postgres
    command:
      - postgres
      - -c
      - wal_level=logical  # Required for Electric
    ports:
      - "5436:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  electric:
    image: electricsql/electric:latest
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres/my_app_dev
    ports:
      - "3002:3000"
    depends_on:
      postgres:
        condition: service_healthy
```

---

## Troubleshooting

### Error: HTTP 400 from Electric

**Check:**
- Are you syncing generated columns?
- Is the table name correct?
- Does the WHERE clause have valid SQL syntax?

**Fix:** Add explicit `columns` parameter excluding generated columns.

### Browser Crashes During Sync

**Check:**
- Are you manually subscribing to ShapeStream?
- Are you calling `collection.insert()` in a loop?
- Are you using default `eager` sync mode with large datasets?
- Are you subscribing to both `subscribeChanges` AND `syncStatus`?

**Fix:** 
1. Use `electricCollectionOptions()` instead of manual subscription
2. Add `syncMode: 'progressive'` for datasets >100 records
3. Debounce sync status updates (100ms) and UI refreshes (200ms)
4. Only subscribe to `syncStatus`, not both `subscribeChanges` and `syncStatus`

### Sync Status Stuck on "Syncing"

**Check:**
- Is `collection.isReady()` being called?
- Is there a `subscribeChanges` listener?

**Fix:** Add proper sync status monitoring as shown in Pattern 1.

### TypeScript Error: Type doesn't satisfy Row<unknown>

**Check:**
- Does your type have an index signature?

**Fix:** Add `& Record<string, unknown>` to your type.

### Data Not Updating in UI

**Check:**
- Is `subscribeChanges` connected?
- Is the data array being reassigned (not just mutated)?

**Fix:** Use `data = collection.toArray` to trigger Svelte reactivity.

---

## Quick Reference

### Dependencies

```bash
npm install @tanstack/db @tanstack/electric-db-collection @electric-sql/client
```

### Key Imports

```typescript
import { createCollection } from '@tanstack/db';
import { electricCollectionOptions } from '@tanstack/electric-db-collection';
import type { Collection } from '@tanstack/db';
```

### Collection API

```typescript
// Create collection
const collection = createCollection(electricCollectionOptions<T>({ ... }));

// Check if ready
collection.isReady();        // boolean

// Get data
collection.toArray;          // T[]
collection.size;             // number
collection.get(key);         // T | undefined
collection.has(key);         // boolean

// Subscribe to changes
const sub = collection.subscribeChanges((changes) => { ... });
sub.unsubscribe();

// Mutations (for local changes)
collection.insert(item);
collection.update(key, (draft) => { draft.field = value; });
collection.delete(key);
```

### Shape Options

```typescript
electricCollectionOptions<T>({
  id: 'unique-collection-id',
  shapeOptions: {
    url: 'http://localhost:3002/v1/shape',
    params: {
      table: 'table_name',
      where: 'status = \'active\'',  // SQL WHERE clause
      columns: 'id,name,title'        // Comma-separated, no spaces
    }
  },
  getKey: (item) => item.id
})
```

---

## Related Skills

- [IndexedDB Persistence](../indexeddb-electric-persistence/) - For offline persistence with delta sync
- [Creating Ash Resources](../creating-ash-resources/) - Backend resource definitions
- [Multi-Tenant Resources](../multi-tenant-resources/) - Organization-scoped data patterns

---

## Key Takeaways

**Do:**
- ✅ Use `electricCollectionOptions()` from `@tanstack/electric-db-collection`
- ✅ Use `syncMode: 'progressive'` for datasets with 100+ records
- ✅ Debounce sync status updates (100ms) and UI refreshes (200ms)
- ✅ Add `& Record<string, unknown>` to types for Electric compatibility
- ✅ Use `collection.isReady()` method for sync status
- ✅ Explicitly list columns, excluding generated ones
- ✅ Subscribe to `syncStatus` store only for UI updates

**Don't:**
- ❌ Manually subscribe to ShapeStream and call `collection.insert()`
- ❌ Use default `eager` sync mode for large datasets (causes browser crash)
- ❌ Subscribe to both `subscribeChanges()` AND `syncStatus` (causes double updates)
- ❌ Try to sync PostgreSQL generated columns
- ❌ Use `state.isReady` (doesn't exist, use `isReady()` method)
- ❌ Forget to handle sync errors in the UI
- ❌ Mutate arrays in place (reassign for Svelte reactivity)
