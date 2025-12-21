# TanStack Mutations Guide

## Overview

This guide explains how to implement CRUD mutations with optimistic updates in the local-first TanStack stack.

**Stack:** Svelte 4 + TanStack Query v5 + TanStack DB v0.5 + ElectricSQL v1.0

## Architecture

```
User Action
  ↓
[Instant] Optimistic Update
  ├─ Temporary data added to Svelte store
  ├─ UI updates immediately (local-first!)
  └─ User sees change right away
  ↓
[Background] API Request
  ├─ POST/PATCH/DELETE to Phoenix backend
  └─ Ash creates/updates/deletes in PostgreSQL
  ↓
[Success Path]
  ├─ Replace temp ID with real server ID
  ├─ ElectricSQL syncs from PostgreSQL via logical replication
  ├─ TanStack DB gets authoritative data
  └─ UI shows final state
  ↓
[Error Path]
  ├─ Rollback optimistic update
  ├─ Restore previous state
  ├─ Show error message
  └─ User can retry
```

## Mutation Pattern: Create

### 1. Define Types

```typescript
export interface CreateEntityInput {
  field1: string
  field2?: string
  // ... your fields
}

interface CreateEntityResponse {
  success: boolean
  data: Entity
}
```

### 2. Create Mutation Function

```typescript
async function createEntityMutation(input: CreateEntityInput): Promise<Entity> {
  const response = await fetch('http://localhost:4002/api/entities', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(input),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result: CreateEntityResponse = await response.json()
  return result.data
}
```

### 3. Create Mutation Hook with Optimistic Updates

```typescript
export function useCreateEntityMutation() {
  return createMutation({
    mutationFn: createEntityMutation,

    // OPTIMISTIC UPDATE - Instant UI feedback
    onMutate: async (newEntity: CreateEntityInput) => {
      // 1. Cancel outgoing refetches (prevent race conditions)
      await queryClient?.cancelQueries({ queryKey: entityKeys.all })

      // 2. Snapshot previous state (for rollback)
      const previousEntities = get(entitiesStore)

      // 3. Create optimistic entity with temp ID
      const optimisticEntity: Entity = {
        id: `temp-${Date.now()}`,
        ...newEntity,
        inserted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      } as Entity

      // 4. Update store immediately (instant UI update!)
      addEntity(optimisticEntity)

      // 5. Return context for success/error handlers
      return { previousEntities, optimisticEntity }
    },

    // SUCCESS - Replace optimistic with real data
    onSuccess: (serverEntity, _variables, context) => {
      if (!context) return

      // Add real entity from server
      addEntity(serverEntity)

      // Invalidate queries (ElectricSQL will sync the real data)
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },

    // ERROR - Rollback to previous state
    onError: (_error, _variables, context) => {
      if (!context) return

      // Restore previous state
      entitiesStore.set(context.previousEntities)

      // Invalidate to refetch
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },
  })
}
```

### 4. Use in Component

```svelte
<script lang="ts">
  import { useCreateEntityMutation } from '$lib/query/entities'

  const createMutation = useCreateEntityMutation()

  let field1 = ''
  let field2 = ''

  function handleSubmit() {
    $createMutation.mutate(
      {
        field1,
        field2,
      },
      {
        onSuccess: () => {
          // Redirect or show success message
          goto('/entities')
        },
      }
    )
  }
</script>

<form on:submit|preventDefault={handleSubmit}>
  <!-- Success Message -->
  {#if $createMutation.isSuccess}
    <div class="success-banner">
      Entity created successfully!
    </div>
  {/if}

  <!-- Error Message -->
  {#if $createMutation.isError}
    <div class="error-banner">
      {$createMutation.error?.message || 'Failed to create entity'}
    </div>
  {/if}

  <!-- Form Fields -->
  <input bind:value={field1} required />
  <input bind:value={field2} />

  <!-- Submit Button -->
  <button
    type="submit"
    disabled={$createMutation.isPending || $createMutation.isSuccess}
  >
    {#if $createMutation.isPending}
      Creating...
    {:else if $createMutation.isSuccess}
      Created!
    {:else}
      Create Entity
    {/if}
  </button>
</form>
```

## Mutation Pattern: Update

### Update Hook Example

```typescript
export interface UpdateEntityInput {
  id: string
  field1?: string
  field2?: string
}

export function useUpdateEntityMutation() {
  return createMutation({
    mutationFn: updateEntityMutation,

    onMutate: async (updatedEntity: UpdateEntityInput) => {
      await queryClient?.cancelQueries({ queryKey: entityKeys.all })
      const previousEntities = get(entitiesStore)

      // Optimistically update in store
      const currentEntities = get(entitiesStore)
      const optimisticEntities = currentEntities.map(e =>
        e.id === updatedEntity.id
          ? { ...e, ...updatedEntity, updated_at: new Date().toISOString() }
          : e
      )
      entitiesStore.set(optimisticEntities)

      return { previousEntities }
    },

    onSuccess: () => {
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },

    onError: (_error, _variables, context) => {
      if (context?.previousEntities) {
        entitiesStore.set(context.previousEntities)
      }
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },
  })
}
```

## Mutation Pattern: Delete

### Delete Hook Example

```typescript
export function useDeleteEntityMutation() {
  return createMutation({
    mutationFn: deleteEntityMutation,

    onMutate: async (id: string) => {
      await queryClient?.cancelQueries({ queryKey: entityKeys.all })
      const previousEntities = get(entitiesStore)

      // Optimistically remove from store
      const currentEntities = get(entitiesStore)
      entitiesStore.set(currentEntities.filter(e => e.id !== id))

      return { previousEntities }
    },

    onSuccess: () => {
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },

    onError: (_error, _variables, context) => {
      if (context?.previousEntities) {
        entitiesStore.set(context.previousEntities)
      }
      queryClient?.invalidateQueries({ queryKey: entityKeys.all })
    },
  })
}
```

### Delete with Confirmation

```svelte
<script lang="ts">
  import { useDeleteEntityMutation } from '$lib/query/entities'

  const deleteMutation = useDeleteEntityMutation()

  function handleDelete(id: string, name: string) {
    if (confirm(`Are you sure you want to delete "${name}"? This action cannot be undone.`)) {
      $deleteMutation.mutate(id)
    }
  }
</script>

<button
  on:click={() => handleDelete(entity.id, entity.name)}
  class="text-red-600 hover:text-red-900"
  disabled={$deleteMutation.isPending}
>
  {#if $deleteMutation.isPending}
    Deleting...
  {:else}
    Delete
  {/if}
</button>
```

## Best Practices

### 1. Always Use Optimistic Updates
✅ **DO**: Update UI immediately for instant feedback
```typescript
onMutate: async (newData) => {
  // Immediately update store
  addEntity(optimisticEntity)
  return { previousData }
}
```

❌ **DON'T**: Wait for server response
```typescript
// This creates lag and poor UX
onSuccess: (serverData) => {
  addEntity(serverData) // Too slow!
}
```

### 2. Always Provide Rollback
✅ **DO**: Save previous state and restore on error
```typescript
onMutate: async () => {
  const previousEntities = get(entitiesStore)
  return { previousEntities }
}

onError: (_error, _variables, context) => {
  entitiesStore.set(context.previousEntities) // Rollback
}
```

### 3. Cancel Outgoing Queries
✅ **DO**: Prevent race conditions
```typescript
onMutate: async () => {
  await queryClient?.cancelQueries({ queryKey: entityKeys.all })
  // ... rest of optimistic update
}
```

### 4. Invalidate Queries After Success
✅ **DO**: Trigger refetch to get ElectricSQL data
```typescript
onSuccess: () => {
  queryClient?.invalidateQueries({ queryKey: entityKeys.all })
}
```

### 5. Use Temporary IDs
✅ **DO**: Use unique temporary IDs
```typescript
const optimisticEntity = {
  id: `temp-${Date.now()}`,
  ...newData
}
```

❌ **DON'T**: Use random or duplicate IDs
```typescript
id: 'temp' // Could conflict!
id: Math.random().toString() // Not guaranteed unique
```

## Debugging Tips

### Check Optimistic Updates
```javascript
// In browser console
console.log('[Mutation] Optimistic update:', optimisticEntity)
console.log('[Mutation] Previous state:', previousEntities)
```

### Monitor Store Changes
```svelte
<script>
  // Add to your component for debugging
  $: console.log('Store updated:', $entitiesStore)
</script>
```

### Test Error Rollback
```typescript
// Temporarily make API fail to test rollback
async function createEntityMutation(input) {
  throw new Error('Test error') // Should trigger rollback!
}
```

## Common Patterns

### Pattern: Redirect After Success
```svelte
<script>
  $createMutation.mutate(data, {
    onSuccess: () => {
      setTimeout(() => goto('/entities'), 500)
    }
  })
</script>
```

### Pattern: Toast Notifications
```svelte
<script>
  import { toast } from '$lib/toast'

  $createMutation.mutate(data, {
    onSuccess: () => toast.success('Entity created!'),
    onError: (error) => toast.error(error.message)
  })
</script>
```

### Pattern: Form Reset
```svelte
<script>
  function handleSubmit() {
    $createMutation.mutate(formData, {
      onSuccess: () => {
        // Reset form
        field1 = ''
        field2 = ''
      }
    })
  }
</script>
```

## Reference Implementation

See `frontend/src/lib/query/cases.ts` for complete working examples of:
- ✅ Create mutation with optimistic updates
- ✅ Update mutation with optimistic updates
- ✅ Delete mutation with optimistic updates
- ✅ Type-safe interfaces
- ✅ Error handling and rollback
- ✅ ElectricSQL integration

## Further Reading

- [TanStack Query Mutations](https://tanstack.com/query/latest/docs/framework/svelte/guides/mutations)
- [TanStack Query Optimistic Updates](https://tanstack.com/query/latest/docs/framework/svelte/guides/optimistic-updates)
- [ElectricSQL Documentation](https://electric-sql.com/docs)
- [TanStack DB Documentation](https://tanstack.com/db/latest)
