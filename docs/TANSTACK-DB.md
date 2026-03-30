# TanStack DB, PGLite & the ElectricSQL Stack

> **Status**: Phase 2 implemented. TanStack DB is the reactive layer for all GridLite pages.
> **Last reviewed**: 2026-03-30

## The Stack — Not Either/Or

PGLite and TanStack DB are both ElectricSQL products. They operate at **different layers** and work together.

**PGLite** is a database engine — full Postgres compiled to WASM. Real SQL in the browser. Under 3MB gzipped, 13M+ weekly downloads, v0.4 (March 2026) with PostGIS, pgvector, connection multiplexing. It persists to IndexedDB. It has live query primitives (`live.query()`, `live.incrementalQuery()`). It ships official framework hooks for React and Vue — but not Svelte.

**TanStack DB** is **not a database** — it's a reactive data orchestration layer. Its official description: "the reactive client store for your API." It provides Collections, Live Queries (powered by differential dataflow), and Optimistic Mutations. It is storage-agnostic — it sits on top of whatever data source you plug in. Current status: Beta. Has a Svelte adapter (`@tanstack/svelte-db`).

### How they fit together

TanStack DB does not own storage. It's a reactive layer with pluggable collection adapters:

- `electricCollectionOptions()` — sync from Postgres via ElectricSQL
- `queryCollectionOptions()` — REST APIs via TanStack Query
- `powerSyncCollectionOptions()` — PowerSync's SQLite-based sync
- RxDB, localStorage, in-memory, and [custom adapters](https://tanstack.com/db/latest/docs/guides/collection-options-creator)
- PGLite — via community [tanstack-db-pglite](https://github.com/letstri/tanstack-db-pglite) adapter

For its own persistence (surviving page refresh), TanStack DB v0.6 uses SQLite WASM — but this is separate from the collection source. The TanStack team [noted overlap](https://github.com/TanStack/db/issues/359) between PGLite and TanStack DB's *built-in SQLite persistence*, but not between PGLite and TanStack DB's collection/reactivity layer, which are genuinely complementary.

The target architecture:

```
Electric Sync → PGLite (storage + SQL engine) → TanStack DB (reactive orchestration) → UI
```

PGLite is the storage and SQL layer. TanStack DB is the reactivity and state management layer. They are partners, not competitors.

### Why PGLite stays

1. **SQL when you need it.** PostGIS geospatial queries, pgvector similarity search, complex raw SQL — PGLite handles what TanStack DB's JS query API can't.
2. **Schema fidelity.** Same Postgres dialect on server and client. A filter in `lat_session_manager.ex` and one in GridLite have identical semantics.
3. **Extension ecosystem.** PostGIS, pgvector, pg_uuidv7, pgTAP — production Postgres extensions running client-side.
4. **Proven at scale.** 19K rows with JSONB columns, complex filters, grouping — working today.

### Why TanStack DB comes in

1. **Differential dataflow.** Architecturally superior for reactivity — incrementally maintains results as data changes, vs PGLite's "re-run and diff".
2. **Optimistic mutations.** Built-in write-back with conflict resolution. Critical for future editing workflows.
3. **Production-grade sync.** `ElectricCollection` is production-ready. `pglite-sync` is alpha (we've hit stale subscriptions, BigInt bugs, schema versioning).
4. **Ecosystem convergence.** Electric's docs, examples, and investment all target TanStack DB as the canonical reactive layer.
5. **Svelte adapter.** `@tanstack/svelte-db` exists — PGLite has no Svelte hooks (we had to roll our own).

| | PGLite | TanStack DB |
|---|---|---|
| What it is | Database engine (Postgres in WASM) | Reactive data orchestration layer |
| Storage | Postgres WASM → IndexedDB / OPFS | Pluggable; built-in SQLite WASM for own persistence |
| Query language | SQL | JS/TS API (eq, gt, ilike, groupBy, ...) |
| Reactivity | `live.query()` — re-run and diff | Differential dataflow — incremental |
| Sync from Electric | `pglite-sync` (alpha) | `ElectricCollection` (production) |
| Optimistic mutations | Roll your own | Built-in |
| Framework hooks | React, Vue (no Svelte) | React, Svelte, Vue, Angular, Solid |
| Role in target stack | Storage + specialist SQL | Reactive orchestration + default queries |

### Electric's positioning

Electric's [Sync Stacks](https://electric-sql.com/docs/stacks) page labels the PGLite stack as "Great for dev, test and sandbox environments" and TanStack DB as the recommended choice for "web, mobile and AI app development." This is about the **sync pipeline maturity** (`pglite-sync` is alpha, `ElectricCollection` is production), not PGLite the database engine which is production-grade (13M downloads, adopted by Prisma).

## Our Current Stack

```
GridLite pages:  Electric → PGLite → live.changes() → TanStack DB → GridLite TanStack DB Adapter → UI
Other pages:     Electric → PGLite → custom Svelte stores (live-store.ts) → UI
```

| Layer | Tool | Package |
|---|---|---|
| Server → Client sync | ElectricSQL shapes | `@electric-sql/client` |
| Local storage + SQL | PGLite (WASM Postgres) | `@electric-sql/pglite` |
| Shape → PGLite pipe | pglite-sync (alpha) | `@electric-sql/pglite-sync` |
| Reactive orchestration (GridLite) | TanStack DB collection via `collection-bridge.ts` | `@tanstack/db` |
| Reactive UI (non-GridLite) | PGLite `live.query()` + custom Svelte stores | `@electric-sql/pglite/live` |
| Grid data layer | GridLite TanStack DB adapter | `@shotleybuilder/gridlite-adapter-tanstack-db` |
| Grid fallback | GridLite PGLite adapter (specialist SQL) | `@shotleybuilder/gridlite-adapter-pglite` |
| Stateless API calls | TanStack Query | `@tanstack/svelte-query` |

### The collection bridge

TanStack DB needs a collection source. The community [tanstack-db-pglite](https://github.com/letstri/tanstack-db-pglite) adapter requires `drizzle-orm` as a dependency — too heavy. We rolled a lightweight bridge in `frontend/src/lib/pglite/collection-bridge.ts` (~110 lines) that uses PGLite's `live.changes()` directly.

**How it works**: `live.changes(sql, params, primaryKey)` returns typed change events with `__op__: INSERT | UPDATE | DELETE`. These map 1:1 to TanStack DB's `write({ type, value })` sync API — no manual diffing of 19K rows.

```typescript
import { createPGLiteCollection } from '$lib/pglite/collection-bridge';

const collection = createPGLiteCollection({
  db,
  query: 'SELECT id, name, title_en, year, ... FROM uk_lrt',
  id: 'browse-uk-lrt'
});

const adapter = createTanStackDBAdapter({ collection, columns: metadata });
```

The bridge:
1. Calls `db.live.changes(query, null, primaryKey)` — gets `initialChanges` + `subscribe`
2. Maps initial rows (all INSERT) → `begin/write/commit` → `markReady()`
3. Subscribes to subsequent changes (Electric → PGLite → here) → maps `__op__` → `write()`
4. Strips PGLite internal fields (`__op__`, `__changed_columns__`, `__after__`)
5. Normalizes `Date` objects → ISO strings (see gotchas below)
6. Returns cleanup function that unsubscribes

### Custom Svelte stores (still used)

The reactive layer — `frontend/src/lib/pglite/live-store.ts` (~260 lines) — wraps PGLite's native live queries into Svelte stores. Still used by non-GridLite pages:

- `createLiveQuery` — static SQL, incremental diff subscription
- `createDynamicLiveQuery` — swappable SQL, incremental diff
- `createQueryStore` — one-shot query with manual `refresh()`
- `createDynamicQueryStore` — swappable SQL, manual refresh
- `createLiveCount` — single count value, live subscription

**We didn't roll this by choice — PGLite has no Svelte adapter.** It ships hooks for [React](https://pglite.dev/docs/framework-hooks/react) (`@electric-sql/pglite-react` v0.3.2) and [Vue](https://pglite.dev/docs/framework-hooks/vue) (`@electric-sql/pglite-vue` v0.3.2). There is **no `@electric-sql/pglite-svelte`** — it doesn't exist on npm and there's no open issue on the [PGLite monorepo](https://github.com/electric-sql/pglite/tree/main/packages).

For GridLite pages, TanStack DB replaces this custom reactive layer. For other pages, live-store.ts remains.

## GridLite Strategy: Dual Adapters (Implemented)

GridLite (`svelte-gridlite-kit` v0.5.0) compiles its IR (`FilterNode[]`, `SortConfig[]`, `GroupConfig[]`) into either TanStack DB query operators or parameterised SQL, depending on the adapter:

- **TanStack DB adapter** (`gridlite-adapter-tanstack-db` v0.5.1): GridLite compiles IR → TanStack DB query operators (`eq`, `ilike`, `groupBy`, etc.). Used by all three GridLite pages (browse, admin/lrt, admin/lat/queue).
- **PGLite SQL adapter** (`gridlite-adapter-pglite` v0.5.0): GridLite compiles IR → SQL. Available for specialist queries (pgvector similarity, PostGIS geospatial, complex subqueries). Not currently used by any page but stays in deps.

Both adapters share the same GridLite component — switching adapter is a one-line change.

### Query capability comparison

| GridLite IR | SQL (PGLite adapter) | TanStack DB adapter |
|---|---|---|
| `equals` filter | `"col" = $1` | `eq(col, value)` |
| `contains` filter | `"col" ILIKE '%' \|\| $1 \|\| '%'` | `ilike(col, '%value%')` |
| `is_empty` filter | `("col" IS NULL OR "col"::text = '')` | `or(isNull(col), eq(col, ''))` |
| `jsonb_has_key` | `"function" ? $1::text` | `eq(row.function[key], true)` — simpler |
| `jsonb_object_keys()` | SQL function | `Object.keys()` on collection — trivial JS |
| `ORDER BY` | `ORDER BY "col" ASC` | `orderBy(col, 'asc')` |
| `GROUP BY` + aggregates | `GROUP BY "col"`, `COUNT(*)` | `groupBy(col)`, `count()` |
| `LIMIT/OFFSET` | `LIMIT n OFFSET m` | `limit(n)`, `offset(m)` |
| Global search | `col::text ILIKE ...` | `ilike(col, pattern)` |
| pgvector similarity | `col <=> $1 ORDER BY ...` | **Not available** — use PGLite adapter |
| PostGIS spatial | `ST_DWithin(col, ...)` | **Not available** — use PGLite adapter |

The gap for standard grid operations is small. PGLite adapter stays available for specialist SQL.

## Gotchas & Lessons Learned

Discovered during Phase 2 implementation (2026-03-30). These apply to anyone wiring PGLite into TanStack DB.

### 1. PGLite DATE columns → JS Date objects

**Problem**: PGLite returns `date` and `timestamp` columns as JavaScript `Date` objects. TanStack DB filter values are ISO strings (e.g. `"2026-01-01"`). Comparisons like `gt(Date_object, "2026-01-01")` do `Date > string` — JavaScript coerces both to numbers, producing nonsensical results (a "Last Year" filter showed data from 1973).

**Fix**: Normalize `Date` objects to ISO date strings in the bridge's `stripInternalFields()`:

```typescript
clean[key] = val instanceof Date ? val.toISOString().split('T')[0] : val;
```

This runs on every row during initial load and on every change event. Cheap and prevents the type mismatch from ever reaching TanStack DB.

### 2. BasicIndex required for ordered pagination

**Problem**: TanStack DB throws "Ordered snapshot was requested but no index was found" when GridLite requests paginated, sorted data. TanStack DB needs an index on the first `orderBy` column to support `limit`/`offset` on ordered snapshots.

**Fix**: Add `defaultIndexType: BasicIndex` and `autoIndex: 'eager'` to the collection config:

```typescript
import { BasicIndex } from '@tanstack/db';

return {
  id,
  getKey: (item) => item[primaryKey] as string,
  defaultIndexType: BasicIndex,
  autoIndex: 'eager' as const,
  sync: { ... }
};
```

`autoIndex: 'eager'` builds indexes on all fields at collection creation time. For 19K rows this is fast and avoids lazy-index surprises at query time.

### 3. TanStack DB adapter does not support `intervalOffset` filters

**Problem**: The PGLite SQL adapter supported `intervalOffset` on date filters (e.g. `updated_at > NOW() - INTERVAL '6 months'`). The TanStack DB adapter throws because TanStack DB's JS query operators have no concept of SQL intervals.

**Fix**: Pre-compute the comparison as a boolean column in SQL:

```sql
SELECT ...,
  (updated_at IS NOT NULL AND latest_lat_updated_at IS NOT NULL
   AND updated_at > latest_lat_updated_at + INTERVAL '6 months') AS lat_stale
FROM uk_lrt
```

Then filter on `lat_stale equals true` instead of `updated_at > intervalOffset('6 months')`. This moves the date arithmetic into PGLite (which handles `INTERVAL` natively) and gives TanStack DB a simple boolean.

### 4. UPDATE writes must not include `key`

**Problem**: TanStack DB's `write()` for updates uses `Omit<ChangeMessage, 'key'>` — the key comes from `getKey(value)` in the collection config, not from the write payload. Including `key` in the write causes a type error.

**Fix**: Only pass `key` for DELETE operations:

```typescript
if (op === 'INSERT') {
  write({ type: 'insert', value });
} else if (op === 'UPDATE') {
  write({ type: 'update', value });      // no key — getKey(value) is used
} else if (op === 'DELETE') {
  write({ type: 'delete', key: value[primaryKey] as string });  // key required
}
```

### 5. `live.changes()` over `live.query()` for the bridge

**Why**: `live.query()` returns the full result set on every change — with 19K rows, you'd need to diff the entire dataset to find what changed. `live.changes()` returns only the changed rows with typed `__op__` events, which map directly to TanStack DB's insert/update/delete write types. Much more efficient and no manual diffing.

### 6. Column-subset queries reduce memory

Each page queries only the columns it needs (browse: 24, admin/lrt: 22, lat/queue: 15) rather than all 85 columns. The collection bridge accepts arbitrary SQL, so column subsetting is just a matter of writing the right SELECT. This reduces memory in both PGLite's change tracking and TanStack DB's collection store.

### 7. `rowUpdateMode: 'full'` is required

The sync config must include `rowUpdateMode: 'full'` because `live.changes()` sends the complete row on UPDATE (not just changed fields). Without this, TanStack DB may try to merge partial updates, causing data corruption.

## The Dual-Source Problem

Using TanStack Query to cache data that's also synced by ElectricSQL creates staleness — Electric updates the local store, but TanStack Query's in-memory cache doesn't know. **We don't have this problem** — our live stores listen directly to PGLite via `live.incrementalQuery()`, and TanStack Query is only used for stateless API calls (admin mutations, scraper triggers). TanStack DB would formalise this separation, but we've already avoided it by design.

## Migration History

### Phase 1: Extract `pglite-svelte` — SKIPPED

Originally planned to extract `live-store.ts` into a `@shotleybuilder/pglite-svelte` package. Skipped because Phase 2 was actionable sooner than expected — TanStack DB v0.6 reached sufficient maturity and the GridLite adapter was ready. The custom `live-store.ts` remains inline for non-GridLite pages; extracting it is low priority now that GridLite pages (the main consumers) use TanStack DB.

### Phase 2: TanStack DB reactive layer + GridLite adapter — COMPLETE (2026-03-30)

**Commits**: `98ab0ff` (Phase 1: GridLite 0.5.0 adapter pattern), `46f700f` (Phase 2: all pages migrated), `2af9bde` (bug fixes: ViewSidebar + date normalization)

**What was done**:
1. Created `collection-bridge.ts` — lightweight PGLite → TanStack DB bridge using `live.changes()`
2. Created `uk-lrt-columns.ts` — 85-column metadata array for the TanStack DB adapter
3. Migrated all three GridLite pages from `createPGLiteAdapter` → `createTanStackDBAdapter`:
   - **Browse** (`/browse`) — also migrated from custom sidebar to `ViewSidebar` package
   - **Admin LRT** (`/admin/lrt`) — removed reactive adapter recreation (`$:` + `{#key}` pattern)
   - **LAT Queue** (`/admin/lat/queue`) — pre-computed `lat_stale` boolean for intervalOffset workaround
4. Bumped `gridlite-adapter-tanstack-db` to v0.5.1
5. Fixed three runtime bugs (see Gotchas section above)

**What stayed the same**:
- `pglite/sync.ts` — Electric → PGLite sync unchanged
- `pglite/live-store.ts` — still used by non-GridLite pages
- `pglite/client.ts`, `pglite/schema.sql` — PGLite setup unchanged
- Backend API mutations — admin edits still go through `authFetch PATCH /api/uk-lrt/{id}` → Electric sync → PGLite → `live.changes()` picks it up

### Future: Remaining migration opportunities

- **Non-GridLite pages**: Dashboard stats, screening workflow — still use `live-store.ts`. Could migrate to `@tanstack/svelte-db` reactive stores directly, but low priority (they work fine).
- **Optimistic mutations**: TanStack DB supports optimistic writes with conflict resolution. Currently admin mutations go through the backend API and wait for Electric sync. Could add optimistic UI updates for faster perceived performance.
- **`@tanstack/svelte-db`**: Not currently used — the collection bridge feeds TanStack DB collections directly to the GridLite adapter. If we build custom (non-GridLite) reactive views on TanStack DB data, we'd use the Svelte adapter.

## Current Architecture

```
Postgres (source of truth)
    │
    ▼
Electric Sync (shapes API)
    │
    ▼
PGLite (WASM Postgres — storage + SQL engine)
    │
    ├──────────────────────────────────┐
    ▼                                  ▼
TanStack DB collection              Direct PGLite SQL
(via collection-bridge.ts)          (live-store.ts, specialist queries)
    │                                  │
    ▼                                  ▼
GridLite TanStack DB adapter       GridLite PGLite adapter (available)
(browse, admin/lrt, lat/queue)     + custom Svelte stores (other pages)
    │                                  │
    └────────────┬─────────────────────┘
                 ▼
          Svelte Components
```

## ElectricSQL Product Landscape (as of 2026-03)

The ElectricSQL team ships fast. Here's how all four primitives fit:

### Electric Sync (Shapes) — what we use today
Postgres logical replication → HTTP shape API → client. Our pipeline syncs shapes into PGLite via `pglite-sync`.

### PGLite — stays in the stack
Full WASM Postgres in the browser. Storage engine + specialist SQL. Electric syncs into it. TanStack DB sits on top for reactivity.

### TanStack DB — target reactive layer
Reactive data orchestration with differential dataflow. Beta. Plugs into PGLite (or Electric directly). The canonical reactive client layer in Electric's ecosystem.

### Durable Streams — new primitive
Persistent, resumable, append-only HTTP streams. Open protocol.
- Offset-based resumability (survives disconnects)
- 1M+ concurrent connections per stream
- 240K writes/sec throughput

### StreamDB — reactive database on a Durable Stream
Standard Schema → type-safe reactive database with sync. Routes streams into TanStack DB collections. Designed for AI agent sessions, presence, multi-agent coordination.

### Relevance to sertantai microservices

| Product | Relevance |
|---|---|
| **Electric Sync** | Core — uk_lrt shape sync |
| **PGLite** | Core — storage + specialist SQL. Stays in the stack |
| **TanStack DB** | Target reactive layer (Phase 2). Sits on top of PGLite |
| **Durable Streams** | Potential: inter-service messaging, LAT parser events |
| **StreamDB** | Potential: AI-driven DRRP clause refinement sessions |

## SKILL.md Pattern for New Services

### For GridLite pages (recommended)

Use PGLite + TanStack DB collection bridge + GridLite TanStack DB adapter.

```markdown
# Skill: Electric + PGLite + TanStack DB Data Layer

## Stack
- @electric-sql/pglite — WASM Postgres (storage + specialist SQL)
- @tanstack/db — reactive orchestration layer (via collection-bridge.ts)
- @shotleybuilder/gridlite-adapter-tanstack-db — GridLite adapter
- @tanstack/svelte-query — stateless API calls only (auth, external APIs)

## Architecture
Electric → PGLite (storage) → live.changes() → TanStack DB collection → GridLite → UI

## Do NOT
- Use TanStack Query for data that syncs via Electric (dual-source problem)
- Use PGLite live.query() directly for GridLite pages — use TanStack DB
- Use the community tanstack-db-pglite package (requires drizzle-orm)
- Include intervalOffset filters — pre-compute date comparisons in SQL instead
- Forget to normalize Date columns (PGLite returns Date objects, TanStack DB expects strings)

## Pattern
1. Electric syncs into PGLite
2. createPGLiteCollection() bridges PGLite → TanStack DB via live.changes()
3. createTanStackDBAdapter() wraps the collection for GridLite
4. Query only needed columns (not SELECT *) to reduce memory
5. Use TanStack Query for auth, file uploads, external APIs
```

### For non-GridLite pages

Use PGLite + custom Svelte stores (live-store.ts pattern).

```markdown
# Skill: Electric + PGLite Data Layer (non-GridLite)

## Stack
- @electric-sql/pglite — WASM Postgres (storage + SQL)
- @electric-sql/pglite-sync — Electric shapes → PGLite
- PGLite live queries + custom Svelte stores (see live-store.ts)
- @tanstack/svelte-query — stateless API calls only

## Pattern
1. Sync Electric shapes into PGLite tables
2. Use createLiveQuery() / createQueryStore() for reactive UI
3. Use PGLite SQL directly for filtering/sorting
4. Use TanStack Query for auth, file uploads, external APIs
```

## References

- [PGLite homepage](https://pglite.dev/)
- [PGLite docs](https://pglite.dev/docs/about)
- [PGLite live queries](https://pglite.dev/docs/live-queries)
- [PGLite React hooks](https://pglite.dev/docs/framework-hooks/react) (`@electric-sql/pglite-react`)
- [PGLite Vue hooks](https://pglite.dev/docs/framework-hooks/vue) (`@electric-sql/pglite-vue`)
- [PGLite monorepo packages](https://github.com/electric-sql/pglite/tree/main/packages) — no `pglite-svelte`
- [PGLite v0.4 announcement](https://electric-sql.com/blog/2026/03/25/announcing-pglite-v04)
- [PGLite sync (alpha)](https://pglite.dev/docs/sync)
- [TanStack DB docs](https://tanstack.com/db/latest)
- [TanStack DB 0.6 persistence](https://tanstack.com/blog/tanstack-db-0.6-app-ready-with-persistence-and-includes)
- [TanStack DB noted overlap with PGLite persistence](https://github.com/TanStack/db/issues/359)
- [tanstack-db-pglite](https://github.com/letstri/tanstack-db-pglite) — community adapter wiring PGLite as TanStack DB collection source
- [TanStack DB custom collection adapters](https://tanstack.com/db/latest/docs/guides/collection-options-creator)
- [TanStack DB operators](https://tanstack.com/db/latest/docs/reference/variables/operators)
- [TanStack DB live queries](https://tanstack.com/db/latest/docs/guides/live-queries)
- [TanStack DB Svelte adapter](https://tanstack.com/db/latest/docs/framework/svelte/overview)
- [Electric + TanStack DB](https://electric-sql.com/products/tanstack-db)
- [Electric Sync Stacks](https://electric-sql.com/docs/stacks)
- [ElectricSQL products overview](https://electric-sql.com/products/)
- [Durable Streams announcement](https://electric-sql.com/blog/2025/12/09/announcing-durable-streams)
- [Durable Streams 0.1.0 + State Protocol](https://electric-sql.com/blog/2025/12/23/durable-streams-0.1.0)
- [Hosted Durable Streams](https://electric-sql.com/blog/2026/01/22/announcing-hosted-durable-streams)
- [Durable Sessions for AI](https://electric-sql.com/blog/2026/01/12/durable-sessions-for-collaborative-ai)
- [Durable Transport for AI SDKs](https://electric-sql.com/blog/2026/03/24/durable-transport-ai-sdks)
- [`@tanstack/svelte-db` on npm](https://www.npmjs.com/package/@tanstack/svelte-db)
- [TanStack DB GitHub](https://github.com/TanStack/db)
- [Durable Streams GitHub](https://github.com/durable-streams/durable-streams)
