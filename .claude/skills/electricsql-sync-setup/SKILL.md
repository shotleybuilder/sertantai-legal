# SKILL: ElectricSQL + TanStack DB Sync Setup

**Purpose:** Set up real-time data sync between PostgreSQL and the browser using ElectricSQL with the official TanStack DB integration, proxied through the Phoenix backend.

**Context:** ElectricSQL 1.2+, TanStack DB 0.5+, @tanstack/electric-db-collection 0.2+, @electric-sql/client 1.5+, Svelte/SvelteKit, Phoenix backend proxy

**When to Use:**
- Setting up real-time sync for a new resource
- Fixing sync issues (401s, 400s, MissingHeadersError, data not loading)
- Adding server-side filtering to synced data
- Configuring the backend proxy for Electric

---

## Core Principles

### 1. All Electric Requests Go Through the Backend Proxy

Never expose Electric directly to the browser. The Phoenix backend proxies all shape requests, injecting the `ELECTRIC_SECRET` server-side and validating auth via the Gatekeeper.

```
Browser → Phoenix proxy (/api/electric/v1/shape) → ElectricSQL (:3000)
```

### 2. Use `electricCollectionOptions` — The Official Pattern

The `@tanstack/electric-db-collection` package provides `electricCollectionOptions()` which handles ShapeStream lifecycle, batched updates, and reactive state internally.

### 3. Use `eager` Sync Mode (Not `progressive`)

`progressive` maps to `on-demand` internally in TanStack DB. In on-demand mode, data is only loaded via `loadSubset`/`fetchSnapshot`, NOT via `collection.toArray`. Since pages use `collection.toArray` directly, progressive mode results in **no data**.

Use `eager` mode with WHERE clauses to limit the dataset size.

### 4. PostgreSQL Generated Columns Cannot Be Synced

Electric returns 400 when trying to sync generated columns. Always pass an explicit `columns` array excluding them.

### 5. Quote String Values in WHERE Clauses

All comparison operators must quote string/date values: `field >= '2024-01-01'` not `field >= 2024-01-01`. Unquoted date values cause Electric 400 errors.

---

## Architecture: Proxy Pattern

### Why a Proxy?

1. **Security**: `ELECTRIC_SECRET` stays server-side, never sent to browser
2. **Auth**: Gatekeeper validates JWT and injects org-scoped WHERE clauses
3. **Public tables**: Some tables (reference data) bypass auth entirely
4. **CORS**: Proxy controls headers so browser JS can read Electric protocol headers

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

### Adding a New Table to the Proxy

In `electric_proxy_controller.ex`:

```elixir
# For public reference data (no auth):
@public_tables ~w(uk_lrt lat amendment_annotations your_new_table)

# For all tables (including shape DELETE recovery):
@allowed_tables ~w(uk_lrt organization_locations ... your_new_table)
```

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Using `progressive` Sync Mode

**Why it fails:**
`progressive` maps to `on-demand` internally. In on-demand mode:
- ShapeStream uses `log=changes_only` and `offset=now`
- Data is ONLY loaded via `loadSubset` → `fetchSnapshot`/`requestSnapshot`
- `loadSubset` is triggered by live queries, NOT by `collection.toArray`
- Pages use `collection.toArray` directly → data never loads

**✅ Fix:** Use `eager` mode with WHERE clause to limit dataset:

```typescript
const collection = createCollection(
  electricCollectionOptions<ElectricMyRecord>({
    id: 'my-collection',
    syncMode: 'eager',  // NOT progressive
    shapeOptions: {
      url: `${ELECTRIC_URL}/v1/shape`,
      fetchClient: electricFetchClient,  // Injects auth headers
      params: {
        table: 'my_table',
        where: 'year >= 2024',  // Limit dataset size
        columns: MY_COLUMNS     // String array, not comma-joined
      }
    },
    getKey: (item) => item.id as string
  })
);
```

### ❌ Pitfall 2: MissingHeadersError

**Why it fails:** Multiple possible causes:
1. Corsica plug doesn't expose `electric-*` headers → browser JS can't read them
2. Proxy doesn't set `Access-Control-Expose-Headers`
3. Browser caches a proxied response → cached response lacks CORS headers
4. Proxy forwards stale `content-encoding`/`content-length` → browser can't decode body

**✅ Fix:** Ensure proxy follows the official Electric proxy pattern:

```elixir
defp forward_electric_headers(conn, %Req.Response{headers: headers}) do
  # Headers to skip — replaced or invalid after decompression
  skip = MapSet.new(~w(cache-control content-encoding content-length transfer-encoding))

  conn =
    Enum.reduce(headers, conn, fn {key, values}, conn ->
      if key in skip do
        conn
      else
        if String.starts_with?(key, "electric-") or key in ~w(etag x-request-id) do
          case values do
            [val | _] -> put_resp_header(conn, key, val)
            _ -> conn
          end
        else
          conn
        end
      end
    end)

  conn
  |> put_resp_header("cache-control", "no-store")
  |> put_resp_header("vary", "Authorization")
  |> put_resp_header(
    "access-control-expose-headers",
    "electric-cursor,electric-handle,electric-offset,electric-schema,electric-up-to-date,electric-internal-known-error"
  )
end
```

### ❌ Pitfall 3: Unquoted String Values in WHERE Clauses

**Why it fails:**
`latest_amend_date >= 2024-01-01` is invalid SQL. Electric returns 400.

**✅ Fix:** Quote string values in all comparison operators:

```typescript
case 'greater_or_equal':
  return typeof value === 'string'
    ? `${field} >= '${escapeValue(String(value))}'`
    : `${field} >= ${value}`;
```

Apply this pattern to: `greater_than`, `less_than`, `greater_or_equal`, `less_or_equal`.

Note: `is_before`/`is_after` operators already quote correctly by design.

### ❌ Pitfall 4: Double Collection Creation on Page Load

**Why it fails:**
`lastWhereClause` initialized with a different format than what `buildWhereFromFilters` produces. Example:
- Init: `"md_date" > '2026-03-01'` (quoted column name)
- `buildWhereFromFilters`: `md_date > '2026-03-01'` (unquoted)
- They don't match → collection recreated immediately → two rapid requests → second hits browser cache → MissingHeadersError

**✅ Fix:** Initialize `lastWhereClause` to match `buildWhereFromFilters` output format:

```typescript
// WRONG — quoted column name
let lastWhereClause = `"md_date" > '${thisMonthStart}'`;

// CORRECT — matches buildWhereFromFilters output
let lastWhereClause = `md_date > '${thisMonthStart}'`;
```

### ❌ Pitfall 5: Syncing PostgreSQL Generated Columns

**Why it fails:**
Electric returns 400 when trying to sync generated columns.

**✅ Fix:** Pass `columns` as a string array excluding generated columns:

```typescript
const COLUMNS: string[] = [
  'id', 'name', 'title', 'year', 'created_at', 'updated_at'
  // Do NOT include generated columns like 'computed_url', 'number_int'
];
```

Find generated columns with:
```sql
SELECT column_name, generation_expression
FROM information_schema.columns
WHERE table_name = 'my_table'
  AND generation_expression IS NOT NULL;
```

### ❌ Pitfall 6: No Auth Token on Electric Requests

**Why it fails:**
Electric shape requests need JWT for org-scoped tables. Without `fetchClient`, no `Authorization` header is sent.

**✅ Fix:** Use `electricFetchClient` which injects the JWT:

```typescript
// frontend/src/lib/electric/fetch-client.ts
import { getAuthToken } from '$lib/stores/auth';

export function createElectricFetchClient(
  fetchFn: typeof fetch = fetch
): (input: RequestInfo | URL, init?: RequestInit) => Promise<Response> {
  return async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const token = getAuthToken();
    const headers = new Headers(init?.headers);
    if (token && !headers.has('Authorization')) {
      headers.set('Authorization', `Bearer ${token}`);
    }
    return fetchFn(input, { ...init, headers });
  };
}

export const electricFetchClient = createElectricFetchClient();
```

Then pass it to shape options:
```typescript
shapeOptions: {
  url: `${ELECTRIC_URL}/v1/shape`,
  fetchClient: electricFetchClient,  // ← Injects JWT
  params: { ... }
}
```

### ❌ Pitfall 7: Shape Recovery After Electric Restart

**Why it fails:**
After Electric restarts, restored shapes can have broken offsets (`offset out of bounds`, 400). The Electric client retains internal offset/handle state across retries, so `return {}` from `onError` doesn't help.

**✅ Fix:** Destroy and recreate the collection:

```typescript
shapeOptions: {
  // ...
  onError: async (error: unknown) => {
    const status = error instanceof Error && 'status' in error
      ? (error as { status: number }).status : null;

    if (status === 400) {
      const now = Date.now();
      if (now - shapeResetAttemptedAt < 30_000) {
        console.error('Shape recovery already attempted recently');
        return;
      }
      shapeResetAttemptedAt = now;

      // Try to delete the broken shape
      try {
        await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=my_table`, {
          method: 'DELETE'
        });
      } catch { /* DELETE may not be available */ }

      // Recreate after delay (new ShapeStream with offset=-1)
      setTimeout(async () => {
        myCollection = null;
        myCollection = await createMyCollection(currentWhereClause);
      }, 1500);
      return;
    }
  }
}
```

### ❌ Pitfall 8: TypeScript Type Doesn't Satisfy Row<unknown>

```typescript
// WRONG — No index signature
interface MyRecord { id: string; name: string; }

// CORRECT — Add index signature
type ElectricMyRecord = MyRecord & Record<string, unknown>;
```

---

## Working Pattern: Complete Collection Setup

### File: `src/lib/db/index.client.ts`

```typescript
import { browser } from '$app/environment';
import type { Collection } from '@tanstack/db';
import { writable } from 'svelte/store';
import type { MyRecord } from '$lib/types/my-record';
import { electricFetchClient } from '$lib/electric/fetch-client';
import { ELECTRIC_URL } from '$lib/electric/client';

type ElectricMyRecord = MyRecord & Record<string, unknown>;

// Columns to sync — excludes generated columns
const MY_COLUMNS: string[] = ['id', 'name', 'title', 'status', 'created_at', 'updated_at'];

let myCol: Collection<ElectricMyRecord, string> | null = null;
let currentWhereClause = '';
let shapeResetAttemptedAt = 0;

export interface SyncStatus {
  connected: boolean;
  syncing: boolean;
  recordCount: number;
  lastSyncTime: Date | null;
  error: string | null;
}

export const syncStatus = writable<SyncStatus>({
  connected: false, syncing: true, recordCount: 0,
  lastSyncTime: null, error: null
});

function getDefaultWhere(): string {
  return `year >= ${new Date().getFullYear() - 2}`;
}

async function createMyCollection(
  whereClause: string
): Promise<Collection<ElectricMyRecord, string>> {
  const { createCollection } = await import('@tanstack/db');
  const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

  currentWhereClause = whereClause;
  syncStatus.update((s) => ({ ...s, syncing: true, error: null }));

  const collection = createCollection(
    electricCollectionOptions<ElectricMyRecord>({
      id: 'my-collection',
      syncMode: 'eager',  // Use eager — WHERE limits dataset size
      shapeOptions: {
        url: `${ELECTRIC_URL}/v1/shape`,
        fetchClient: electricFetchClient,
        params: {
          table: 'my_table',
          where: whereClause,
          columns: MY_COLUMNS
        },
        onError: async (error: unknown) => {
          const status = error instanceof Error && 'status' in error
            ? (error as { status: number }).status : null;

          if (status === 401) {
            syncStatus.update((s) => ({ ...s, error: 'Authentication required', syncing: false }));
            return;
          }

          if (status === 400) {
            const now = Date.now();
            if (now - shapeResetAttemptedAt < 30_000) return;
            shapeResetAttemptedAt = now;
            try {
              await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=my_table`, { method: 'DELETE' });
            } catch { /* OK */ }
            setTimeout(async () => {
              myCol = null;
              myCol = await createMyCollection(currentWhereClause);
            }, 1500);
            return;
          }

          console.error('Electric sync error:', error);
        }
      },
      getKey: (item) => item.id as string
    })
  );

  // Debounced sync status monitoring
  let timer: ReturnType<typeof setTimeout> | null = null;
  collection.subscribeChanges(() => {
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      if (collection.size > 0) shapeResetAttemptedAt = 0;
      syncStatus.update((s) => ({
        ...s, connected: true, syncing: !collection.isReady(),
        recordCount: collection.size,
        lastSyncTime: collection.isReady() ? new Date() : s.lastSyncTime
      }));
    }, 100);
  });

  return collection as unknown as Collection<ElectricMyRecord, string>;
}

export async function getMyCollection(
  whereClause?: string
): Promise<Collection<ElectricMyRecord, string>> {
  if (!browser) throw new Error('Collections can only be used in the browser');
  const where = whereClause || getDefaultWhere();
  if (myCol && currentWhereClause === where) return myCol;
  myCol = await createMyCollection(where);
  return myCol;
}

export async function updateMyWhere(whereClause: string): Promise<void> {
  if (!browser) return;
  myCol = await createMyCollection(whereClause);
}
```

### File: `src/lib/electric/client.ts`

```typescript
// Electric URL points to the backend proxy, NOT directly to Electric
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003/api';
export const ELECTRIC_URL = `${API_URL}/electric`;
```

### `buildWhereFromFilters` — Correct Value Quoting

```typescript
export function buildWhereFromFilters(
  filters: Array<{ field: string; operator: string; value: unknown }>
): string {
  if (!filters || filters.length === 0) return getDefaultWhere();

  const escapeValue = (v: string): string => v.replace(/'/g, "''");

  const clauses = filters.map(({ field, operator, value }) => {
    switch (operator) {
      case 'equals':
        return typeof value === 'string'
          ? `${field} = '${escapeValue(String(value))}'`
          : `${field} = ${value}`;
      case 'contains':
        return `${field} ILIKE '%${escapeValue(String(value))}%'`;
      case 'greater_than':
        return typeof value === 'string'
          ? `${field} > '${escapeValue(String(value))}'`
          : `${field} > ${value}`;
      case 'less_than':
        return typeof value === 'string'
          ? `${field} < '${escapeValue(String(value))}'`
          : `${field} < ${value}`;
      case 'greater_or_equal':
        return typeof value === 'string'
          ? `${field} >= '${escapeValue(String(value))}'`
          : `${field} >= ${value}`;
      case 'less_or_equal':
        return typeof value === 'string'
          ? `${field} <= '${escapeValue(String(value))}'`
          : `${field} <= ${value}`;
      case 'is_before':
        return `${field} < '${escapeValue(String(value))}'`;
      case 'is_after':
        return `${field} > '${escapeValue(String(value))}'`;
      case 'is_empty':
        return `(${field} IS NULL OR ${field} = '')`;
      case 'is_not_empty':
        return `(${field} IS NOT NULL AND ${field} != '')`;
      default:
        return null;
    }
  }).filter(Boolean);

  return clauses.length > 0 ? clauses.join(' AND ') : getDefaultWhere();
}
```

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

### Docker Compose for Electric (Development)

```yaml
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

### Production: ElectricSQL Replication Slot

Multiple Electric instances on the same PostgreSQL cluster conflict on replication slots. Set a unique ID:

```yaml
environment:
  - ELECTRIC_REPLICATION_STREAM_ID=legal  # → creates electric_slot_legal
```

---

## Troubleshooting

### MissingHeadersError
1. Check Corsica `expose_headers` in `endpoint.ex` includes all `electric-*` headers
2. Check proxy sets `Access-Control-Expose-Headers` on response
3. Check proxy sets `cache-control: no-store` (prevents browser serving cached responses without CORS)
4. Check proxy strips `content-encoding` and `content-length` (stale after Req decompression)
5. Check for double collection creation (format mismatch in `lastWhereClause`)

### Electric Returns 400
1. Are you syncing generated columns? → Add explicit `columns` array
2. Is the WHERE clause quoting string/date values? → `field >= '2024-01-01'` not `field >= 2024-01-01`
3. Is the table name correct?

### 401 Unauthorized
1. Is `electricFetchClient` being passed to `shapeOptions.fetchClient`?
2. Is the JWT in localStorage? (check `getAuthToken()`)
3. For public tables — is the table listed in `@public_tables` in the proxy controller?

### Data Doesn't Load (Spinner Forever)
1. Are you using `progressive` sync mode? → Switch to `eager`
2. Is `collection.subscribeChanges` connected?
3. Check browser console for errors

### Shape Broken After Electric Restart
The `onError` handler with 400 detection recreates the collection. If `ELECTRIC_ENABLE_INTEGRATION_TESTING=true` is set, it also DELETEs the broken shape first.

---

## Quick Reference

### Dependencies
```bash
npm install @electric-sql/client@^1.5 @tanstack/db@^0.5 @tanstack/electric-db-collection@^0.2
```

### Key Files
| File | Purpose |
|------|---------|
| `frontend/src/lib/db/index.client.ts` | Collections, sync status, WHERE builder |
| `frontend/src/lib/electric/fetch-client.ts` | JWT header injection for Electric requests |
| `frontend/src/lib/electric/client.ts` | ELECTRIC_URL (points to backend proxy) |
| `backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex` | Proxy controller |
| `backend/lib/sertantai_legal_web/endpoint.ex` | Corsica CORS config with expose_headers |

### Adding a New Synced Table Checklist
1. Create Ash resource with `REPLICA IDENTITY FULL` in migration
2. Add table to `@allowed_tables` in proxy controller
3. Add to `@public_tables` if it's public reference data (no auth needed)
4. Create column list excluding generated columns
5. Create collection in `index.client.ts` with `eager` mode + `fetchClient`
6. Add `onError` handler for shape recovery
7. Initialize `lastWhereClause` matching `buildWhereFromFilters` output format

---

## Related Skills

- [Production Deployment](../production-deployment/) — Deploy to Hetzner
- [Stale Electric Shapes](../stale-electric-shapes/) — Recovering from broken shapes
- [Creating Ash Resources](../creating-ash-resources/) — Backend resource definitions

---

## Key Takeaways

**Do:**
- ✅ Proxy all Electric requests through the Phoenix backend
- ✅ Use `eager` sync mode with WHERE-limited datasets
- ✅ Pass `fetchClient: electricFetchClient` for JWT injection
- ✅ Set `cache-control: no-store` and `Vary: Authorization` in proxy
- ✅ Strip `content-encoding`/`content-length` from proxied responses
- ✅ Expose `electric-*` headers in both Corsica plug AND proxy response
- ✅ Quote string/date values in all WHERE comparison operators
- ✅ Match `lastWhereClause` format to `buildWhereFromFilters` output
- ✅ Add `onError` handler for shape recovery (400 → recreate collection)
- ✅ Add `& Record<string, unknown>` to types for Electric compatibility
- ✅ Explicitly list columns, excluding generated ones

**Don't:**
- ❌ Use `progressive`/`on-demand` sync mode with `collection.toArray`
- ❌ Expose Electric directly to the browser (use proxy)
- ❌ Forget to quote string values in WHERE clauses
- ❌ Initialize `lastWhereClause` with different format than `buildWhereFromFilters`
- ❌ Forward `content-encoding`/`content-length` through the proxy
- ❌ Let Electric's `cache-control: public, max-age=604800` reach the browser
- ❌ Try to sync PostgreSQL generated columns
