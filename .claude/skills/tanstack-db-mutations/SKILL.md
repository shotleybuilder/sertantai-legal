# SKILL: TanStack DB Mutations with Custom Sync Providers

**Purpose:** Implement optimistic mutations on TanStack DB collections that use custom sync providers (e.g., PGLite collection bridge), not just Electric's built-in sync.

**Context:** TanStack DB 0.5+, custom `CollectionConfig` sync, PGLite or other external data sources

**When to Use:**
- Adding write/edit support to a TanStack DB collection
- Making inline edits optimistic (instant UI feedback)
- Understanding how `onUpdate`/`onInsert`/`onDelete` handlers work
- Choosing between mutation strategies for collections with custom sync

---

## Core Concept: Mutation Handlers

TanStack DB collections support three mutation callbacks in their config:

```typescript
createCollection({
  id: 'my-collection',
  getKey: (item) => item.id,
  sync: { ... },        // Existing sync config (read path)

  // Mutation handlers (write path):
  onInsert: async ({ transaction }) => { ... },
  onUpdate: async ({ transaction }) => { ... },
  onDelete: async ({ transaction }) => { ... }
});
```

When you call `collection.update(key, mutatorFn)`, TanStack DB:
1. Applies the change **optimistically** (UI updates immediately)
2. Calls `onUpdate` asynchronously (persists to backend)
3. Keeps optimistic state until the sync layer confirms the real data

---

## Three Mutation Patterns

### Pattern 1: Collection-Level Mutations (Recommended)

Define `onUpdate` in the collection config. Use `collection.update()` from components.

**Collection config:**
```typescript
createCollection({
  id: 'uk-lrt',
  getKey: (item) => item.id,
  sync: { /* existing read-only sync */ },

  onUpdate: async ({ transaction }) => {
    for (const mutation of transaction.mutations) {
      const { original, changes } = mutation;

      // 1. Persist to backend API
      await authFetch(`/api/uk-lrt/${original.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(changes)
      });

      // 2. Write to PGLite for instant live.changes() feedback
      //    (Skip if using Electric-backed collection — Electric syncs it)
      for (const [field, value] of Object.entries(changes)) {
        await db.query(
          `UPDATE uk_lrt SET "${field}" = $1 WHERE id = $2`,
          [value === '' ? null : value, original.id]
        );
      }
    }
  }
});
```

**Component usage (clean):**
```typescript
function handleFieldChange(id: string, field: string, value: string | null) {
  collection.update(id, (draft) => {
    (draft as Record<string, unknown>)[field] = value;
  });
}
```

### Pattern 2: createTransaction (Multi-Collection or Custom Control)

Use `createTransaction()` when mutations span multiple collections or you need manual commit control.

```typescript
import { createTransaction } from '@tanstack/db';

const tx = createTransaction({
  mutationFn: async ({ transaction }) => {
    // Persist all mutations across all collections
    for (const mutation of transaction.mutations) {
      await api.persist(mutation);
    }
  }
});

// Apply mutations (optimistic)
tx.mutate(() => {
  collectionA.update(id1, (draft) => { draft.status = 'active'; });
  collectionB.insert({ id: newId, name: 'New Item' });
});

// Wait for persistence
await tx.isPersisted.promise;
```

### Pattern 3: Direct Write (Simplest, No Mutation Handlers)

Skip TanStack DB mutation handlers entirely. PATCH the backend, then write to PGLite directly. The sync layer (live.changes()) propagates the update.

```typescript
async function updateRecord(id: string, field: string, value: unknown) {
  await authFetch(`/api/uk-lrt/${id}`, {
    method: 'PATCH',
    body: JSON.stringify({ [field]: value })
  });

  // Write to PGLite → triggers live.changes() → TanStack DB updates
  await db.query(`UPDATE uk_lrt SET "${field}" = $1 WHERE id = $2`, [value, id]);
}
```

**Trade-offs:**

| Aspect | Pattern 1 (onUpdate) | Pattern 2 (createTransaction) | Pattern 3 (Direct Write) |
|---|---|---|---|
| Optimistic UI | Instant (before PATCH) | Instant (before PATCH) | After PGLite write (~ms) |
| Rollback on failure | Automatic | Automatic | Manual (reload/revert) |
| Component code | Clean (`collection.update()`) | Verbose | Raw SQL in component |
| Setup complexity | Moderate (config) | Low | Lowest |
| Multi-collection | No | Yes | No |

---

## Dropping Optimistic State

When using Patterns 1 or 2, TanStack DB keeps the optimistic state until the sync layer provides the real data. Five strategies for confirming mutations:

### Strategy 1: Sync Confirmation (Best for PGLite Bridge)

The sync layer (`live.changes()`) feeds the confirmed data. When the PGLite write happens (in the handler), `live.changes()` fires with the new value, replacing the optimistic state.

```typescript
onUpdate: async ({ transaction }) => {
  // PATCH backend
  await api.update(transaction.mutations);

  // Write to PGLite — live.changes() confirms the mutation
  await db.query(`UPDATE ...`);
  // Optimistic state replaced when live.changes() emits the UPDATE event
}
```

### Strategy 2: Electric Round-Trip (For Electric-Backed Collections)

Wait for Electric to sync the change back from PostgreSQL. The `electricCollectionOptions` sync detects the updated row and drops the optimistic state.

```typescript
onUpdate: async ({ transaction }) => {
  const response = await api.update(transaction.mutations);
  // Return txid so Electric can match it
  return { txid: response.txid };
}
```

### Strategy 3: Polling for Confirmation

Poll PGLite (or any data source) until the change appears:

```typescript
onUpdate: async ({ transaction }) => {
  await api.update(transaction.mutations);

  // Poll until PGLite has the new value
  const maxWait = 5000;
  const start = Date.now();
  while (Date.now() - start < maxWait) {
    const result = await db.query(
      'SELECT updated_at FROM uk_lrt WHERE id = $1',
      [transaction.mutations[0].original.id]
    );
    if (result.rows[0]?.updated_at > transaction.startedAt) return;
    await new Promise((r) => setTimeout(r, 100));
  }
}
```

### Strategy 4: Fire-and-Forget

Just persist. Optimistic state stays until the next sync cycle confirms it. Simple but risky if sync is slow.

```typescript
onUpdate: async ({ transaction }) => {
  await api.update(transaction.mutations);
  // Optimistic state remains until Electric/PGLite sync catches up
}
```

### Strategy 5: acceptMutations() (LocalOnly Collections)

For collections without a sync provider (`localOnlyCollectionOptions`):

```typescript
onUpdate: async ({ transaction }) => {
  await api.update(transaction.mutations);
  collection.utils.acceptMutations(transaction);  // Drop optimistic state now
}
```

**Note:** `acceptMutations()` is only for LocalOnly/LocalStorage collections. Collections with sync providers drop optimistic state when the sync feeds confirmed data.

---

## Adding Mutation Handlers to the PGLite Collection Bridge

To upgrade from Pattern 3 (direct write) to Pattern 1 (onUpdate handlers):

### Step 1: Extend `PGLiteCollectionOptions`

```typescript
// collection-bridge.ts
export interface PGLiteCollectionOptions {
  db: PGLiteWithExtensions;
  query: string;
  id: string;
  primaryKey?: string;
  /** Optional: mutation handler called when collection.update() is used */
  onUpdate?: (params: { transaction: MutationTransaction }) => Promise<void>;
  onInsert?: (params: { transaction: MutationTransaction }) => Promise<void>;
  onDelete?: (params: { transaction: MutationTransaction }) => Promise<void>;
}
```

### Step 2: Pass Handlers Through to CollectionConfig

```typescript
export function pgliteCollectionOptions(options: PGLiteCollectionOptions): CollectionConfig<Row, string> {
  const { db, query, id, primaryKey = 'id', onUpdate, onInsert, onDelete } = options;

  return {
    id,
    getKey: (item: Row) => item[primaryKey] as string,
    sync: { /* existing sync config */ },
    ...(onUpdate && { onUpdate }),
    ...(onInsert && { onInsert }),
    ...(onDelete && { onDelete })
  };
}
```

### Step 3: Use From Component

```typescript
const collection = createPGLiteCollection({
  db,
  query: BASE_QUERY,
  id: 'lat-queue-uk-lrt',
  onUpdate: async ({ transaction }) => {
    for (const m of transaction.mutations) {
      await authFetch(`${API_URL}/api/uk-lrt/${m.original.id}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(m.changes)
      });
      // Write to PGLite for instant live.changes() confirmation
      for (const [field, value] of Object.entries(m.changes)) {
        if (EDITABLE_FIELDS.has(field)) {
          await db.query(`UPDATE uk_lrt SET "${field}" = $1 WHERE id = $2`, [value, m.original.id]);
        }
      }
    }
  }
});

// Component — clean, no raw SQL:
collection.update(id, (draft) => {
  draft.making_classification = 'not_making';
});
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Optimistic State Immediately Reverted

**Symptom:** `collection.update()` applies, UI flickers to new value, then reverts.

**Why:** The sync layer (`live.changes()` or Electric) is pushing the old value from the data source, overwriting the optimistic state.

**Fix:** In the `onUpdate` handler, write to the data source (PGLite/PostgreSQL) so the sync layer confirms the new value instead of reverting it.

### Pitfall 2: No onUpdate Handler → Mutation Silently Ignored

**Symptom:** `collection.update()` does nothing — no optimistic update, no error.

**Why:** Without an `onUpdate` handler, TanStack DB has nowhere to persist the mutation. The mutation is discarded.

**Fix:** Add `onUpdate` to the collection config, or use direct writes (Pattern 3).

### Pitfall 3: Mutations Across Multiple Collections Need createTransaction

**Symptom:** Updating two collections in sequence — if the second fails, the first isn't rolled back.

**Fix:** Use `createTransaction()` to wrap both mutations. On failure, both are rolled back.

### Pitfall 4: Column Names in Direct PGLite Writes

**Symptom:** SQL injection risk when interpolating field names.

**Fix:** Always whitelist editable fields:

```typescript
const EDITABLE_FIELDS = new Set(['family', 'family_ii', 'making_classification', 'is_making']);

if (!EDITABLE_FIELDS.has(field)) return;
await db.query(`UPDATE uk_lrt SET "${field}" = $1 WHERE id = $2`, [value, id]);
```

---

## Quick Reference

### Mutation API

```typescript
// Insert
collection.insert({ id: 'new', name: 'New Record' });

// Update (optimistic when onUpdate is defined)
collection.update(key, (draft) => {
  draft.field = 'new value';
});

// Delete
collection.delete(key);

// Transaction (multi-collection)
const tx = createTransaction({ mutationFn: async ({ transaction }) => { ... } });
tx.mutate(() => {
  collectionA.update(id, (draft) => { ... });
  collectionB.delete(otherId);
});
await tx.isPersisted.promise;
```

### Handler Signature

```typescript
onUpdate: async ({ transaction }) => {
  transaction.mutations.forEach((m) => {
    m.original;   // Record before mutation
    m.modified;   // Record after mutation
    m.changes;    // Only the changed fields { field: newValue }
  });
}
```

---

## Related Skills

- [PGLite Collection Bridge](../pglite-collection-bridge/) — The PGLite → live.changes() → TanStack DB architecture
- [ElectricSQL Sync Setup](../electricsql-sync-setup/) — Electric-backed collections (progressive, on-demand, eager)
