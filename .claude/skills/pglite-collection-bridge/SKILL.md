# SKILL: PGLite Collection Bridge

**Purpose:** Bridge PGLite local database into TanStack DB Collections using `live.changes()`, enabling reactive grids (GridLite) with instant local writes.

**Context:** PGLite 0.2+, @electric-sql/pglite/live, TanStack DB 0.5+, ElectricSQL shape sync, Svelte/SvelteKit

**When to Use:**
- Understanding how the LAT Queue page (and similar PGLite-backed pages) work
- Adding write/mutation support to a PGLite-backed collection
- Debugging why live queries aren't detecting changes
- Deciding between PGLite-backed vs Electric-backed collections

---

## Core Architecture

```
PostgreSQL (server, source of truth)
    │
    ▼ (ElectricSQL shape sync)
PGLite (browser, local database)
    │
    ▼ (live.changes() — PostgreSQL triggers + pg_notify)
TanStack DB Collection (reactive in-memory store)
    │
    ▼ (adapter)
GridLite / UI Components
```

**Key difference from Electric collections:** Electric-backed collections (`electricCollectionOptions`) sync directly from Electric's HTTP shape API into TanStack DB. PGLite-backed collections use PGLite as an intermediate storage layer, with `live.changes()` feeding data into TanStack DB.

### When to Use PGLite-Backed Collections

| Use PGLite-backed | Use Electric-backed |
|---|---|
| Page needs raw SQL queries (stats, aggregates) | Pure reactive grid/list display |
| Need to write locally for instant feedback | Read-only data display |
| Complex computed columns in SQL (e.g. `lat_stale`) | Simple column selection |
| Data already in PGLite from shape sync | No PGLite dependency needed |

### Current Pages Using PGLite-Backed Collections

| Page | Collection ID | SQL Source |
|---|---|---|
| LAT Queue (`/admin/lat/queue`) | `lat-queue-uk-lrt` | `SELECT ... FROM uk_lrt` with computed `lat_stale` |

---

## How live.changes() Detects Changes

PGLite's `live.changes()` uses **PostgreSQL-level triggers + `pg_notify()`**. This is critical to understand.

### Mechanism

1. When you call `db.live.changes(query, null, primaryKey)`, PGLite:
   - Analyzes the query to find all referenced tables
   - Creates triggers on those tables (if not already present)
   - Sets up LISTEN on notification channels

2. The auto-created trigger:
   ```sql
   CREATE OR REPLACE TRIGGER "_notify_trigger_{schema_oid}_{table_oid}"
   AFTER INSERT OR UPDATE OR DELETE ON "{schema_name}"."{table_name}"
   FOR EACH STATEMENT
   EXECUTE FUNCTION "_notify_{schema_oid}_{table_oid}"();
   ```
   The function calls `pg_notify('table_change__{schema_oid}__{table_oid}', '')`.

3. When the trigger fires, PGLite's listener re-runs the query and diffs against previous state. Changes are emitted as `INSERT`/`UPDATE`/`DELETE` events.

### Source-Agnostic Detection

**The triggers fire for ALL writes, regardless of source:**
- Direct SQL via `db.query('UPDATE ...')` or `db.exec(...)` — detected
- ElectricSQL `syncShapeToTable()` writes — detected
- Writes inside `db.transaction(...)` — detected (fires on commit)

**There is NO filtering by write source.** This is a plain PostgreSQL trigger.

### Change Event Structure

```typescript
interface Change {
  __op__: 'INSERT' | 'UPDATE' | 'DELETE';
  __changed_columns__: string[];   // Only columns that changed (UPDATE)
  __after__: unknown;              // Positioning key for ordered results
  [column: string]: unknown;       // All row data
}
```

---

## The Collection Bridge (`collection-bridge.ts`)

### Key File: `frontend/src/lib/pglite/collection-bridge.ts`

The bridge creates a TanStack DB `CollectionConfig` whose sync function subscribes to PGLite `live.changes()`:

```typescript
sync: {
  sync: ({ begin, write, commit, markReady }) => {
    // 1. Subscribe to live.changes()
    const result = await db.live.changes<Row>(query, null, primaryKey);

    // 2. Feed initial rows as INSERT events
    begin();
    for (const change of result.initialChanges) {
      write({ type: 'insert', value: stripInternalFields(change) });
    }
    commit();
    markReady();

    // 3. Subscribe to subsequent changes
    result.subscribe((changes) => {
      begin();
      for (const change of changes) {
        if (change.__op__ === 'INSERT') write({ type: 'insert', value: ... });
        if (change.__op__ === 'UPDATE') write({ type: 'update', value: ... });
        if (change.__op__ === 'DELETE') write({ type: 'delete', key: ... });
      }
      commit();
    });
  },
  rowUpdateMode: 'full'
}
```

### Value Normalization

`stripInternalFields()` removes PGLite's `__op__`, `__changed_columns__`, `__after__` fields and converts `Date` objects to ISO strings (for GridLite filter compatibility).

---

## Writing Data: Mutations Pattern

### The Problem

When a user edits a field in the grid, we need:
1. **Instant UI feedback** — the grid shows the new value immediately
2. **Server persistence** — the change is saved to PostgreSQL
3. **Consistency** — PGLite, TanStack DB, and PostgreSQL all agree

### Approach: Direct PGLite Write (Current Pattern)

After a successful backend PATCH, write the same value directly to PGLite. The `live.changes()` trigger fires, TanStack DB receives the update, and the grid re-renders.

```typescript
const EDITABLE_FIELDS = new Set(['family', 'family_ii', 'making_classification', 'is_making']);

async function updateRecord(id: string, field: string, value: string | boolean | null) {
  if (!EDITABLE_FIELDS.has(field)) return;

  // 1. Persist to backend (PostgreSQL)
  const response = await authFetch(`${API_URL}/api/uk-lrt/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ [field]: value })
  });
  if (!response.ok) throw new Error('Failed to update');

  // 2. Apply to PGLite — triggers live.changes() → TanStack DB → GridLite
  if (db) {
    const pgValue = value === '' ? null : value;
    await db.query(`UPDATE uk_lrt SET "${field}" = $1 WHERE id = $2`, [pgValue, id]);
  }
  // Electric will eventually sync the same value from PostgreSQL (no conflict)
}
```

**Why this works:**
- `db.query('UPDATE ...')` fires the PGLite trigger
- `live.changes()` detects the change and emits an UPDATE event
- The collection bridge feeds it into TanStack DB
- GridLite re-renders with the new value
- Electric eventually syncs the same value from PostgreSQL (idempotent)

**Security:** Always whitelist editable field names (the `EDITABLE_FIELDS` set) to prevent SQL injection via column names, since column names cannot be parameterized.

### Alternative: TanStack DB Mutation Handlers (Cleaner)

For a more idiomatic approach, add `onUpdate` handlers to the collection config. See the [TanStack DB Mutations](../tanstack-db-mutations/) skill.

---

## Common Pitfalls & Solutions

### Pitfall 1: TanStack DB Transactions Overwritten by Sync

**Symptom:** `createTransaction` + `collection.update()` applies optimistic update, but the grid immediately reverts to the old value.

**Why:** The PGLite-backed sync constantly pushes data from `live.changes()` into TanStack DB. Since PGLite still has the old value (PATCH hasn't synced back through Electric yet), the sync overwrites the optimistic state.

**Fix:** Don't use `createTransaction` alone. Either:
- Write directly to PGLite after PATCH (triggers sync with new value)
- Use `onUpdate` mutation handlers (TanStack DB manages optimistic state properly)

### Pitfall 2: live.changes() Not Detecting Local Writes

**Symptom:** `db.query('UPDATE ...')` runs without error, but the grid doesn't update.

**Possible causes:**
1. **Wrong table:** The trigger only fires on tables referenced by the live query. If your UPDATE targets a different table or schema, it won't fire.
2. **Column not in SELECT:** If the column you updated isn't in the live query's SELECT, the change may not affect the query result.
3. **Transaction not committed:** Writes inside `db.transaction()` don't fire triggers until the transaction commits.
4. **Subscription not initialized:** `live.changes()` is async. If you write before the subscription is fully set up, changes may be missed.
5. **SQL error:** The UPDATE silently failed. Check the return value of `db.query()`.

### Pitfall 3: Electric Overwrites Local PGLite Writes

**Symptom:** Local write shows briefly, then reverts.

**Why:** Electric's `syncShapeToTable()` synced a stale version from the server before the PATCH propagated.

**Fix:** This is a rare race condition. The PATCH reaches PostgreSQL in ~100ms; Electric polls every few hundred ms. By the time Electric polls again, PostgreSQL has the new value. If it does happen, the next Electric poll cycle will correct it.

### Pitfall 4: Debounce Delay on Rapid Writes

**Symptom:** After several rapid edits, the last one takes a moment to appear.

**Why:** PGLite's `live.changes()` uses an internal `debounceMutex()` to coalesce rapid notifications. Multiple writes in quick succession may be batched.

**Fix:** Use `db.transaction()` to batch multiple writes — single notification after commit.

---

## Quick Reference

### Key Files

| File | Purpose |
|---|---|
| `frontend/src/lib/pglite/collection-bridge.ts` | PGLite → TanStack DB bridge via live.changes() |
| `frontend/src/lib/pglite/client.ts` | PGLite singleton instance |
| `frontend/src/lib/pglite/schema.sql.ts` | Local table schema for PGLite |
| `frontend/src/lib/pglite/sync.ts` | Electric → PGLite shape sync |
| `frontend/src/lib/pglite/uk-lrt-columns.ts` | Column metadata for TanStack DB adapter |

### Creating a PGLite-Backed Collection

```typescript
import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';

const collection = createPGLiteCollection({
  db,                              // PGLite instance
  query: 'SELECT ... FROM uk_lrt', // SQL query
  id: 'my-collection',             // Unique collection ID
  primaryKey: 'id'                 // Default: 'id'
});

const adapter = createTanStackDBAdapter({ collection, columns: columnMetadata });
await adapter.init();
```

### Data Flow Summary

```
Write path:
  Component → authFetch(PATCH) → Backend → PostgreSQL
                                           ↓ (immediate)
  Component → db.query(UPDATE) → PGLite trigger → live.changes() → TanStack DB → GridLite

Sync path (background):
  PostgreSQL → ElectricSQL → PGLite → live.changes() → TanStack DB → GridLite
```

---

## Related Skills

- [ElectricSQL Sync Setup](../electricsql-sync-setup/) — Electric-backed collections (progressive, on-demand, eager)
- [TanStack DB Mutations](../tanstack-db-mutations/) — Mutation handlers for custom sync providers
- [Stale Electric Shapes](../stale-electric-shapes/) — Recovering from broken Electric shapes
