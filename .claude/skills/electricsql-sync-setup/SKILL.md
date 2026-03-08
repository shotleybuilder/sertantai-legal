# SKILL: ElectricSQL + TanStack DB Sync Setup

**Purpose:** Set up real-time data sync between PostgreSQL and the browser using ElectricSQL with the official TanStack DB integration, proxied through the Phoenix backend.

**Context:** ElectricSQL 1.5+, TanStack DB 0.5+, @tanstack/electric-db-collection 0.2+, @electric-sql/client 1.5+, Svelte/SvelteKit, Phoenix backend proxy

**When to Use:**
- Setting up real-time sync for a new resource
- Choosing the right sync mode for a page
- Fixing sync issues (401s, 400s, MissingHeadersError, data not loading)
- Configuring the backend proxy for Electric

---

## Core Principles

### 1. Three Sync Modes — Choose by Use Case

TanStack DB's `electricCollectionOptions` supports three sync modes:

| Mode | Behaviour | Use When |
|------|-----------|----------|
| **`progressive`** | Snapshot loads first query fast, full dataset backfills in background. After backfill, all data is local. | Admin pages — full dataset needed, all filtering client-side |
| **`on-demand`** | Starts at `offset=now` (empty). Each `createLiveQueryCollection` triggers `loadSubset` → `fetchSnapshot` for matching rows. | Public pages — fetch only what's queried, data accumulates |
| **`eager`** | Downloads entire shape immediately. Simple, predictable. | Small fixed datasets with WHERE clause (e.g. `is_making = true`) |

**Key insight:** `progressive` maps to `on-demand` internally but with `offset=void` (→ `-1`) instead of `offset=now`. The initial snapshot is what makes progressive feel fast — it loads the first query's worth of data immediately, then backfills everything else.

### 2. All Electric Requests Go Through the Backend Proxy

Never expose Electric directly to the browser. The Phoenix backend proxies all shape requests, injecting the `ELECTRIC_SECRET` server-side and validating auth via the Gatekeeper.

```
Browser → Phoenix proxy (/api/electric/v1/shape) → ElectricSQL (:3000)
```

### 3. Column Sets Control Payload Size

Exclude columns you don't need. Excluding 7 heavy JSONB columns from admin sync saves ~50% payload:

```
Full sync:     19K × ~5.7 KB/row ≈ 107 MB
Admin columns: 19K × ~2.5 KB/row ≈ 48 MB  (exclude heavy JSONB)
Browse columns: Minimal subset (~30 columns for views)
```

### 4. Singleton Collections — One Per Page Type

Collections are created once and cached. Navigation between pages reuses the same collection. The data persists in memory for the session but not across page refresh.

### 5. PostgreSQL Generated Columns Cannot Be Synced

Electric returns 400 when trying to sync generated columns. Always pass an explicit `columns` array excluding them.

### 6. No Data Persistence Across Refresh

Collections are in-memory only. On page refresh, progressive sync restarts from scratch (snapshot → backfill). The old `sync-uk-lrt.ts` module had IndexedDB offset persistence, but the `electricCollectionOptions` approach does not use that.

---

## Architecture

### Current Collection Architecture (post-#46)

```
ADMIN (/admin/lrt)          BROWSE (/browse)            LAT QUEUE (/admin/lat/queue)
─────────────────           ────────────────            ────────────────────────────
getAdminCollection()        getBrowseCollection()       getLatQueueCollection()
syncMode: progressive       syncMode: on-demand         syncMode: eager
columns: ADMIN (no JSONB)   columns: BROWSE (minimal)   columns: ADMIN (no JSONB)
WHERE: none                 WHERE: none                 WHERE: is_making = true

After backfill:             Per-query:                  Immediate:
collection.toArray = 19K    createLiveQueryCollection   collection.toArray = ~3K
TableKit filters locally    → loadSubset → snapshot     Fixed dataset
```

### Proxy Flow

```
Public tables (uk_lrt, lat, amendment_annotations):
  Browser → Phoenix proxy → Electric (no auth needed)

Org-scoped tables (organization_locations, etc.):
  Browser → Phoenix proxy → Gatekeeper (validates JWT, injects org WHERE) → Electric
```

### Backend Proxy Controller

See `backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex`

Key responsibilities:
- Route public tables directly to Electric (bypass Gatekeeper)
- Route auth-required tables through Gatekeeper validation
- Forward handle-based requests directly (already validated)
- Inject `ELECTRIC_SECRET` on all requests
- Forward `electric-*` response headers for client protocol
- Strip `content-encoding` and `content-length` (Req decompresses but leaves stale headers)
- Set `cache-control: no-store` (prevents browser caching without CORS headers)
- Set `Vary: Authorization` for per-user cache isolation
- Expose `electric-*` headers via `Access-Control-Expose-Headers`

### CORS Configuration (endpoint.ex)

The Corsica plug must expose Electric headers so browser JS can read them:

```elixir
plug(Corsica,
  origins: [...],
  allow_credentials: true,
  allow_methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allow_headers: ["content-type", "authorization"],
  expose_headers: [
    "electric-cursor", "electric-handle", "electric-offset",
    "electric-schema", "electric-up-to-date", "electric-internal-known-error"
  ],
  max_age: 600
)
```

---

## Working Pattern: Collection Factories

### File: `src/lib/db/index.client.ts`

The module defines column sets, singleton factories, and shared error handling.

#### Column Sets

```typescript
// All syncable columns (excludes PostgreSQL generated columns)
export const UK_LRT_ALL_COLUMNS: string[] = ['id', 'family', 'name', 'year', ...];

// Heavy JSONB columns excluded from admin sync
const HEAVY_JSONB_COLUMNS = new Set([
  'role_details', 'role_gvt_details', 'duties',
  'responsibilities', 'powers', 'popimar_details', 'rights'
]);

// Admin: all minus heavy JSONB (~2.5 KB/row)
export const UK_LRT_ADMIN_COLUMNS: string[] = UK_LRT_ALL_COLUMNS.filter(
  (col) => !HEAVY_JSONB_COLUMNS.has(col)
);

// Browse: lightweight subset for public pages (~30 columns)
export const UK_LRT_BROWSE_COLUMNS: string[] = [
  'id', 'family', 'name', 'title_en', 'year', 'number',
  'type_code', 'live', 'function', 'is_making', 'md_date', ...
];
```

#### Singleton Factory Pattern

```typescript
let adminCollection: Collection<ElectricUkLrtRecord, string> | null = null;

export async function getAdminCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
  if (!browser) throw new Error('Collections can only be used in the browser');
  if (adminCollection) return adminCollection;  // Singleton

  const { createCollection } = await import('@tanstack/db');
  const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

  adminCollection = createCollection(
    electricCollectionOptions<ElectricUkLrtRecord>({
      id: 'uk-lrt-admin',
      syncMode: 'progressive',     // Full backfill, client-side filtering
      shapeOptions: {
        url: `${ELECTRIC_URL}/v1/shape`,
        fetchClient: electricFetchClient,
        params: {
          table: 'uk_lrt',
          columns: UK_LRT_ADMIN_COLUMNS
          // No WHERE — progressive syncs everything
        },
        onError: shapeErrorHandler('uk-lrt-admin', UK_LRT_ADMIN_COLUMNS, () => {
          adminCollection = null;  // Reset singleton on fatal error
        })
      },
      getKey: (item) => item.id as string
    })
  ) as unknown as Collection<ElectricUkLrtRecord, string>;

  monitorSyncStatus(adminCollection, 'uk-lrt-admin (progressive)');
  return adminCollection;
}
```

#### On-Demand Collection (Browse)

```typescript
let browseCollection: Collection<ElectricUkLrtRecord, string> | null = null;

export async function getBrowseCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
  if (!browser) throw new Error('...');
  if (browseCollection) return browseCollection;

  // Same pattern but:
  //   syncMode: 'on-demand'
  //   columns: UK_LRT_BROWSE_COLUMNS
  //   No WHERE — on-demand fetches per-query via createLiveQueryCollection
}
```

#### Eager Collection (LAT Queue)

```typescript
let latQueueCollection: Collection<ElectricUkLrtRecord, string> | null = null;

export async function getLatQueueCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
  if (!browser) throw new Error('...');
  if (latQueueCollection) return latQueueCollection;

  // Same pattern but:
  //   syncMode: 'eager'
  //   columns: UK_LRT_ADMIN_COLUMNS
  //   WHERE: 'is_making = true'  — small fixed dataset
}
```

#### Shared Error Handler

```typescript
function shapeErrorHandler(collectionId: string, columns: string[], resetSingleton: () => void) {
  let resetAttemptedAt = 0;

  return async (error: unknown) => {
    const status = error instanceof Error && 'status' in error
      ? (error as { status: number }).status : null;

    if (status === 401) {
      syncStatus.update((s) => ({ ...s, error: 'Authentication required', syncing: false }));
      return;
    }

    if (status === 400) {
      const now = Date.now();
      if (now - resetAttemptedAt < 30_000) return;  // Throttle
      resetAttemptedAt = now;

      // Try to delete the broken shape
      try {
        const colParam = encodeURIComponent(columns.join(','));
        await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=uk_lrt&columns=${colParam}`, {
          method: 'DELETE'
        });
      } catch { /* DELETE may not be available */ }

      resetSingleton();  // Null out singleton so next call recreates
      return;
    }

    console.error(`[TanStack DB] ${collectionId}: sync error:`, error);
  };
}
```

---

## Working Pattern: On-Demand with Live Queries (Browse Page)

On-demand mode starts empty. Use `createLiveQueryCollection` to drive data fetching:

### File: `src/lib/db/query-helpers.ts`

Translates svelte-table-kit `FilterCondition[]` to TanStack DB query expressions:

```typescript
import { eq, gt, gte, lt, lte, and, not, ilike, isNull, inArray } from '@tanstack/db';

export function filtersToWhereCallback(
  filters: FilterConditionInput[]
): ((sources: any) => ReturnType<typeof eq>) | null {
  if (!filters || filters.length === 0) return null;

  return (sources: any) => {
    const sourceKey = Object.keys(sources)[0];
    const source = sources[sourceKey];

    const exprs = filters
      .map((f) => filterToExpr(source, f))
      .filter((e): e is ReturnType<typeof eq> => e !== null);

    if (exprs.length === 0) return eq(1, 1);
    if (exprs.length === 1) return exprs[0];
    return and(exprs[0], exprs[1], ...exprs.slice(2));
  };
}
```

### Browse Page Usage

```typescript
import { getBrowseCollection } from '$lib/db/index.client';
import { createLiveQueryCollection } from '@tanstack/db';
import { filtersToWhereCallback } from '$lib/db/query-helpers';

let baseCollection = await getBrowseCollection();
let liveQuery: ReturnType<typeof createLiveQueryCollection> | null = null;

function buildLiveQuery(filters: FilterCondition[]) {
  if (liveQueryCleanup) { liveQueryCleanup(); }

  const filterInputs = filters.map((f) => ({
    field: f.field, operator: f.operator, value: f.value
  }));
  const whereCallback = filtersToWhereCallback(filterInputs);

  liveQuery = createLiveQueryCollection((q) => {
    const query = q.from({ law: baseCollection! });
    if (whereCallback) return query.where(whereCallback);
    return query;
  });

  const sub = liveQuery.subscribeChanges(() => {
    data = liveQuery!.toArray as unknown as UkLrtRecord[];
  }, { includeInitialState: true });

  liveQueryCleanup = () => { sub.unsubscribe(); liveQuery?.cleanup(); };
}

// Reactive: rebuild live query when filters change
$: if (baseCollection && activeFilters) { buildLiveQuery(activeFilters); }
```

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Wrong Sync Mode for the Use Case

| Symptom | Likely Cause |
|---------|--------------|
| Data never loads | Using `progressive` with `collection.toArray` and no `createLiveQueryCollection` (works, but takes time for backfill) |
| Full re-sync on every filter change | Using `eager` with dynamic WHERE — shape recreated each time |
| Slow initial load | Using `progressive` for small fixed datasets (use `eager` instead) |

**✅ Fix:** Match sync mode to page type:
- Admin (full dataset, client filtering) → `progressive`
- Public (fetch-per-query) → `on-demand` + `createLiveQueryCollection`
- Small fixed dataset → `eager` with WHERE

### ❌ Pitfall 2: MissingHeadersError

**Why it fails:** Multiple possible causes:
1. Corsica plug doesn't expose `electric-*` headers
2. Proxy doesn't set `Access-Control-Expose-Headers`
3. Browser caches a response → cached response lacks CORS headers
4. Proxy forwards stale `content-encoding`/`content-length`

**✅ Fix:** Ensure proxy follows the official Electric proxy pattern. See proxy controller for the complete `forward_electric_headers/2` function.

### ❌ Pitfall 3: Syncing PostgreSQL Generated Columns

Electric returns 400 for generated columns like `leg_gov_uk_url`, `number_int`.

**✅ Fix:** Pass explicit `columns` array:

```sql
-- Find generated columns:
SELECT column_name, generation_expression
FROM information_schema.columns
WHERE table_name = 'my_table' AND generation_expression IS NOT NULL;
```

### ❌ Pitfall 4: No Auth Token on Electric Requests

**✅ Fix:** Pass `electricFetchClient` to `shapeOptions.fetchClient`. It injects the JWT from `adminAuth` store.

### ❌ Pitfall 5: Shape Broken After Electric Restart

Restored shapes can have broken offsets (400 "offset out of bounds"). The `shapeErrorHandler` deletes the broken shape and nulls the singleton so the next call recreates fresh.

See [Stale Electric Shapes](../stale-electric-shapes/) skill for full details.

### ❌ Pitfall 6: TypeScript Type Doesn't Satisfy Row<unknown>

```typescript
// WRONG — No index signature
interface MyRecord { id: string; name: string; }

// CORRECT — Add index signature
type ElectricMyRecord = MyRecord & Record<string, unknown>;
```

### ❌ Pitfall 7: Cache-bust Initial Shape Requests

Browser may serve stale cached responses lacking CORS headers.

**✅ Fix:** `electricFetchClient` adds `_cb=timestamp` to `offset=-1` URLs. The proxy strips this param before forwarding to Electric.

---

## Backend Setup

### Required Migration

```elixir
def change do
  create table(:my_table, primary_key: false) do
    add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
    add :name, :string, null: false
    timestamps(type: :utc_datetime)
  end

  # Enable Electric sync
  execute "ALTER TABLE my_table REPLICA IDENTITY FULL"
end
```

### Adding a New Table to the Proxy

In `electric_proxy_controller.ex`:

```elixir
# For public reference data (no auth):
@public_tables ~w(uk_lrt lat amendment_annotations your_new_table)

# For all tables (including shape DELETE recovery):
@allowed_tables ~w(uk_lrt organization_locations ... your_new_table)
```

---

## Quick Reference

### Dependencies
```bash
npm install @electric-sql/client@^1.5 @tanstack/db@^0.5 @tanstack/electric-db-collection@^0.2
```

### Key Files
| File | Purpose |
|------|---------|
| `frontend/src/lib/db/index.client.ts` | Column sets, singleton factories, sync status |
| `frontend/src/lib/db/query-helpers.ts` | FilterCondition → TanStack DB expressions |
| `frontend/src/lib/electric/fetch-client.ts` | JWT header injection + cache-busting |
| `frontend/src/lib/electric/client.ts` | ELECTRIC_URL (points to backend proxy) |
| `backend/.../electric_proxy_controller.ex` | Proxy controller |
| `backend/.../endpoint.ex` | Corsica CORS config with expose_headers |

### Adding a New Synced Table Checklist
1. Create Ash resource with `REPLICA IDENTITY FULL` in migration
2. Add table to `@allowed_tables` in proxy controller
3. Add to `@public_tables` if it's public reference data
4. Define column list excluding generated columns
5. Choose sync mode: `progressive` (admin), `on-demand` (public), `eager` (small fixed)
6. Create singleton factory in `index.client.ts`
7. Add `shapeErrorHandler` with singleton reset callback
8. For on-demand pages: create `filtersToWhereCallback` mappings in `query-helpers.ts`
9. Cache-busting is handled globally by `electricFetchClient`

### Test Files
| File | Covers |
|------|--------|
| `src/lib/db/index.client.test.ts` | Column sets, factory configs, sync status |
| `src/lib/db/query-helpers.test.ts` | All filter operators, multi-filter AND |
| `src/lib/electric/fetch-client.test.ts` | JWT injection |
| `src/lib/electric/client.test.ts` | URL resolution |

---

## Related Skills

- [Production Deployment](../production-deployment/) — Deploy to Hetzner
- [Stale Electric Shapes](../stale-electric-shapes/) — Recovering from broken shapes
- [Creating Ash Resources](../creating-ash-resources/) — Backend resource definitions

---

## Key Takeaways

**Do:**
- ✅ Choose sync mode by use case: progressive (admin), on-demand (public), eager (small fixed)
- ✅ Use singleton collection factories — one per page type, never destroyed
- ✅ Define column sets to exclude heavy/unnecessary columns
- ✅ Use `createLiveQueryCollection` with on-demand mode for query-driven fetching
- ✅ Use `filtersToWhereCallback` to translate UI filters to TanStack DB expressions
- ✅ Proxy all Electric requests through the Phoenix backend
- ✅ Pass `fetchClient: electricFetchClient` for JWT injection + cache-busting
- ✅ Add `shapeErrorHandler` with singleton reset for shape recovery
- ✅ Add `& Record<string, unknown>` to types for Electric compatibility
- ✅ Explicitly list columns, excluding generated ones

**Don't:**
- ❌ Use `eager` with dynamic WHERE clauses (shape recreated on every change)
- ❌ Use `on-demand` without `createLiveQueryCollection` (data never loads)
- ❌ Expose Electric directly to the browser
- ❌ Destroy/recreate collections on page navigation (use singletons)
- ❌ Try to sync PostgreSQL generated columns
- ❌ Let Electric's `cache-control: public, max-age=604800` reach the browser
- ❌ Expect data to persist across page refresh (in-memory only)
