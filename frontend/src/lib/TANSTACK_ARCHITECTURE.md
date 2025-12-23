# TanStack Architecture - Reference Implementation

This is the **complete TanStack stack** for local-first applications with real-time sync.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│          UI Components (Svelte)         │
│     Uses: useCasesQuery() hook         │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│       TanStack Query (v5)               │
│  - Reactive queries with caching        │
│  - Auto refetch on invalidation         │
│  - Loading/error states                 │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│       Svelte Stores (Bridge)            │
│  - casesStore, agenciesStore           │
│  - Immediate reactivity                 │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│       TanStack DB (v0.5 beta)           │
│  - Collections with localStorage        │
│  - Client-side persistence              │
│  - Insert/update/delete operations      │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│       ElectricSQL (v1.x)                │
│  - Real-time sync from PostgreSQL       │
│  - HTTP Shape API                       │
│  - Change streams (insert/update/del)   │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│       PostgreSQL (with logical rep)     │
│  - Source of truth                      │
│  - WAL-based replication                │
└─────────────────────────────────────────┘
```

## Data Flow (Sync from PostgreSQL)

1. **PostgreSQL** - Data changes in database
2. **ElectricSQL** - Detects changes via logical replication
3. **Sync Layer** (`lib/electric/sync.ts`) - Receives change messages
4. **TanStack DB** - Persists changes locally (offline-capable)
5. **Svelte Store** - Updates reactive state
6. **TanStack Query** - Cache invalidated, triggers refetch
7. **UI Components** - Automatically re-render with new data

## Data Flow (Query from UI)

1. **Component** - Uses `useCasesQuery()` hook
2. **TanStack Query** - Checks cache, runs query function
3. **Query Function** - Reads from Svelte store
4. **Svelte Store** - Returns current data (kept in sync by ElectricSQL)
5. **TanStack Query** - Returns reactive result with loading/error states
6. **Component** - Renders with `$casesQuery.data`

## Key Files

### Setup

- `lib/query/client.ts` - QueryClient configuration
- `routes/+layout.svelte` - QueryClientProvider setup

### Queries

- `lib/query/cases.ts` - Case queries (useCasesQuery, useCaseQuery)
- `lib/query/*.ts` - Add more entity queries as needed

### Storage

- `lib/db/index.client.ts` - TanStack DB collections
- `lib/db/schema.ts` - TypeScript schemas

### Sync

- `lib/electric/sync.ts` - ElectricSQL → TanStack DB → Store → Query
- `lib/stores/cases.ts` - Svelte stores for reactivity bridge

## Usage Example

```svelte
<script lang="ts">
	import { useCasesQuery } from '$lib/query/cases';
	import { startSync } from '$lib/electric/sync';
	import { onMount } from 'svelte';

	// TanStack Query hook
	const casesQuery = useCasesQuery();

	// Start sync on mount
	onMount(async () => {
		await startSync();
	});
</script>

<!-- Loading state -->
{#if $casesQuery.isLoading}
	<p>Loading...</p>

	<!-- Error state -->
{:else if $casesQuery.isError}
	<p>Error: {$casesQuery.error.message}</p>

	<!-- Success state -->
{:else}
	<p>Found {$casesQuery.data.length} cases</p>
	{#each $casesQuery.data as case_}
		<div>{case_.case_reference}</div>
	{/each}
{/if}
```

## Benefits

✅ **Offline-First** - TanStack DB persists data locally
✅ **Real-Time** - ElectricSQL syncs changes instantly
✅ **Reactive** - TanStack Query auto-updates UI
✅ **Type-Safe** - Full TypeScript support
✅ **Caching** - Smart query caching and invalidation
✅ **SSR-Safe** - Browser-only initialization with guards

## Adding New Entities

1. **Define schema** in `lib/db/schema.ts`
2. **Create collection** in `lib/db/index.client.ts`
3. **Add sync function** in `lib/electric/sync.ts`
4. **Create store** in `lib/stores/entity.ts`
5. **Create queries** in `lib/query/entity.ts`
6. **Use in components** with `useEntityQuery()`

## Testing

```bash
# Frontend tests
cd frontend
npm test

# Integration testing
# 1. Add data to PostgreSQL
# 2. Check ElectricSQL sync (port 3001)
# 3. Verify UI updates automatically
```

## Notes

- TanStack DB v0.5 is **beta** - API may change
- Svelte store bridge is temporary until TanStack DB matures
- Query invalidation ensures consistency between layers
- All browser-only code uses dynamic imports with guards

---

**This is the reference implementation for all sertantai-\* projects!** 🚀
