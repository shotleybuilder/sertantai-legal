# TanStack DB, PGLite & the ElectricSQL Stack

> **Status**: Not yet adopted. Two-phase migration planned.
> **Last reviewed**: 2026-03-29

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
Today:    Electric → PGLite → custom Svelte stores → UI
Tomorrow: Electric → PGLite → TanStack DB → UI
```

| Layer | Current tool | Package |
|---|---|---|
| Server → Client sync | ElectricSQL shapes | `@electric-sql/client` |
| Local storage + SQL | PGLite (WASM Postgres) | `@electric-sql/pglite` |
| Shape → PGLite pipe | pglite-sync (alpha) | `@electric-sql/pglite-sync` |
| Reactive UI | PGLite `live.query()` + custom Svelte stores | `@electric-sql/pglite/live` |
| Grid data layer | GridLite (builds SQL, queries PGLite) | `@shotleybuilder/svelte-gridlite-kit` |
| Stateless API calls | TanStack Query | `@tanstack/svelte-query` |

### What we rolled ourselves — and why

The reactive layer — `frontend/src/lib/pglite/live-store.ts` (~260 lines) — wraps PGLite's native live queries into Svelte stores:

- `createLiveQuery` — static SQL, incremental diff subscription
- `createDynamicLiveQuery` — swappable SQL, incremental diff
- `createQueryStore` — one-shot query with manual `refresh()`
- `createDynamicQueryStore` — swappable SQL, manual refresh
- `createLiveCount` — single count value, live subscription

**We didn't roll this by choice — PGLite has no Svelte adapter.** It ships hooks for [React](https://pglite.dev/docs/framework-hooks/react) (`@electric-sql/pglite-react` v0.3.2) and [Vue](https://pglite.dev/docs/framework-hooks/vue) (`@electric-sql/pglite-vue` v0.3.2). There is **no `@electric-sql/pglite-svelte`** — it doesn't exist on npm and there's no open issue on the [PGLite monorepo](https://github.com/electric-sql/pglite/tree/main/packages).

TanStack DB replaces this custom reactive layer entirely — it provides the Svelte reactivity we had to build ourselves.

## GridLite Strategy: Extend, Not Fork

GridLite (`svelte-gridlite-kit`) currently compiles its IR (`FilterNode[]`, `SortConfig[]`, `GroupConfig[]`) to parameterised SQL and executes against PGLite. The strategy is to **extend** GridLite with a TanStack DB adapter:

- **TanStack DB adapter** (default): GridLite compiles IR → TanStack DB query operators (`eq`, `ilike`, `groupBy`, etc.) for standard grid operations
- **PGLite SQL adapter** (specialist): GridLite compiles IR → SQL for cases that need raw SQL power (pgvector similarity, PostGIS geospatial, complex subqueries)

This keeps GridLite as a single library that works with both backends. Users choose based on their needs.

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

## The Dual-Source Problem

Using TanStack Query to cache data that's also synced by ElectricSQL creates staleness — Electric updates the local store, but TanStack Query's in-memory cache doesn't know. **We don't have this problem** — our live stores listen directly to PGLite via `live.incrementalQuery()`, and TanStack Query is only used for stateless API calls (admin mutations, scraper triggers). TanStack DB would formalise this separation, but we've already avoided it by design.

## Migration Plan

### Phase 1: Extract `pglite-svelte` (actionable now)

**Why**: Our `live-store.ts` is the missing Svelte equivalent of `pglite-react` and `pglite-vue`. Extracting it into a package eliminates the "rolled our own" concern, makes it reusable across sertantai services, and provides a clean interim solution while TanStack DB matures.

**Steps**:
1. Create `@shotleybuilder/pglite-svelte` package
2. Follow the API pattern of `pglite-react` / `pglite-vue`:
   - `PGliteContext` — Svelte context to provide PGLite instance
   - `usePGlite()` — retrieve instance from context
   - `useLiveQuery(sql, params)` — reactive Svelte store wrapping `live.query()`
   - `useLiveIncrementalQuery(sql, params, key)` — reactive store wrapping `live.incrementalQuery()`
3. Add extras the official adapters don't have:
   - `useDynamicLiveQuery(key)` — swappable SQL
   - `useQueryStore(sql, params)` — one-shot with `refresh()`
   - `useLiveCount(sql, params)` — single count value
4. Replace `live-store.ts` imports in sertantai-legal with the package
5. Consider opening issue/PR on `electric-sql/pglite` to contribute Svelte upstream

**Outcome**: Reusable across sertantai services. Replaced by TanStack DB's `@tanstack/svelte-db` in Phase 2.

### Phase 2: TanStack DB reactive layer + GridLite adapter (when TanStack DB reaches stable)

**Why**: TanStack DB provides the reactive orchestration layer that replaces our custom Svelte stores, with production-grade sync and optimistic mutations. GridLite gets extended with a TanStack DB adapter as the default query backend, keeping PGLite SQL available for specialist queries.

**Steps**:
1. Install `@tanstack/db`, `@tanstack/svelte-db`, `@tanstack/electric`
2. Wire PGLite as a TanStack DB collection source (via custom adapter or [tanstack-db-pglite](https://github.com/letstri/tanstack-db-pglite) pattern)
3. Replace `live-store.ts` / `pglite-svelte` reactive stores with `@tanstack/svelte-db`
4. Extend GridLite with TanStack DB query adapter:
   - `FilterNode[]` → TanStack DB `where()` expressions
   - `SortConfig[]` → `orderBy()` calls
   - `GroupConfig[]` → `groupBy()` with aggregation functions
   - Pagination → `limit()` / `offset()`
5. Set TanStack DB adapter as default in GridLite, PGLite SQL as opt-in for specialist use
6. Keep `@electric-sql/pglite` for SQL engine (pgvector, PostGIS, raw queries)
7. Keep `@tanstack/svelte-query` for stateless API calls

**Outcome**: PGLite stays as storage + specialist SQL. TanStack DB handles reactivity + default grid queries. GridLite works with both backends — users choose. Custom `live-store.ts` eliminated.

## Target Architecture

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
(reactive orchestration)            (specialist: pgvector, PostGIS)
    │                                  │
    ▼                                  ▼
GridLite TanStack DB adapter       GridLite PGLite adapter
(default for grid queries)         (opt-in for specialist SQL)
    │                                  │
    └────────────┬─────────────────────┘
                 ▼
        @tanstack/svelte-db
         (reactive UI stores)
                 │
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

### Until Phase 2 is complete

Use PGLite + `pglite-svelte` (Phase 1 package).

```markdown
# Skill: Electric + PGLite Data Layer

## Stack
- @electric-sql/pglite — WASM Postgres (storage + SQL)
- @electric-sql/pglite-sync — Electric shapes → PGLite
- @shotleybuilder/pglite-svelte — Svelte reactive hooks for PGLite live queries
- @tanstack/svelte-query — stateless API calls only (auth, external APIs)

## Do NOT
- Use TanStack Query for data that syncs via Electric (dual-source problem)
- Copy raw live-store.ts from sertantai-legal — use the pglite-svelte package

## Pattern
1. Sync Electric shapes into PGLite tables
2. Use useLiveQuery() / useLiveIncrementalQuery() for reactive UI
3. Use PGLite SQL directly for grid/filter/sort queries
4. Use TanStack Query for auth, file uploads, external APIs
```

### After Phase 2 / when TanStack DB is stable

Use PGLite + TanStack DB together.

```markdown
# Skill: Electric + PGLite + TanStack DB Data Layer

## Stack
- @electric-sql/pglite — WASM Postgres (storage + specialist SQL)
- @tanstack/db + @tanstack/svelte-db — reactive orchestration layer
- @tanstack/svelte-query — stateless API calls only (auth, external APIs)

## Architecture
Electric → PGLite (storage) → TanStack DB (reactivity) → UI

## Do NOT
- Use TanStack Query for data that syncs via Electric (dual-source problem)
- Use PGLite live.query() directly for UI reactivity — use TanStack DB

## Pattern
1. Electric syncs into PGLite
2. TanStack DB collection reads from PGLite
3. Use @tanstack/svelte-db for reactive UI stores
4. GridLite uses TanStack DB adapter (default) or PGLite SQL adapter (specialist)
5. Use TanStack Query for auth, file uploads, external APIs
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
