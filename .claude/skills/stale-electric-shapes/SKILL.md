---
name: Stale ElectricSQL Shape Recovery
description: How stale/broken ElectricSQL shapes are detected and recovered after Electric restarts. Covers the root cause, client-side fix, and server-side prerequisites.
---

# Stale ElectricSQL Shape Recovery

## The Problem

After an ElectricSQL server restart, previously active shapes can become **permanently broken**. The shape handle is restored and works for `offset=-1` (initial request), but subsequent offsets return **400 "offset out of bounds"**. Data beyond chunk 0 never materializes.

### Error Types After Electric Restart

| HTTP Status | Meaning | Auto-handled? |
|-------------|---------|---------------|
| **409** | Stale shape handle (shape was deleted/recreated) | Yes — client automatically retries with new handle |
| **400** | Broken offset (shape exists but internal state is corrupted) | **No** — requires manual intervention |

## The Fix: Singleton Reset Pattern

The current architecture uses singleton collection factories (`getAdminCollection`, `getBrowseCollection`, `getLatQueueCollection`). Each factory has a shared `shapeErrorHandler` that:

1. Detects 400 errors (broken shape)
2. Throttles recovery attempts (30-second cooldown)
3. Deletes the broken shape via `DELETE /v1/shape`
4. Nulls out the singleton so the next call recreates a fresh collection

### Client-Side: `shapeErrorHandler` in index.client.ts

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
      if (now - resetAttemptedAt < 30_000) {
        console.error(`[TanStack DB] ${collectionId}: Shape recovery already attempted recently`);
        syncStatus.update((s) => ({
          ...s, error: 'Electric sync unavailable — try refreshing the page', syncing: false
        }));
        return;
      }
      resetAttemptedAt = now;

      // Delete the broken shape
      try {
        const colParam = encodeURIComponent(columns.join(','));
        await electricFetchClient(
          `${ELECTRIC_URL}/v1/shape?table=uk_lrt&columns=${colParam}`,
          { method: 'DELETE' }
        );
      } catch { /* DELETE may not be available */ }

      // Null out singleton — next getXxxCollection() call creates fresh
      resetSingleton();
      return;
    }

    console.error(`[TanStack DB] ${collectionId}: sync error:`, error);
  };
}
```

Each singleton factory passes its own reset callback:

```typescript
onError: shapeErrorHandler('uk-lrt-admin', UK_LRT_ADMIN_COLUMNS, () => {
  adminCollection = null;
})
```

### Server-Side: Enable Shape Deletion API

In `docker-compose.dev.yml`:

```yaml
ELECTRIC_ENABLE_INTEGRATION_TESTING: "true"
```

This enables the `DELETE /v1/shape?table=<table>` endpoint. Without it, the DELETE call returns 405 and recovery relies on Electric eventually cleaning up the shape.

## Key Files

| File | Role |
|------|------|
| `docker-compose.dev.yml` | `ELECTRIC_ENABLE_INTEGRATION_TESTING=true` env var |
| `frontend/src/lib/db/index.client.ts` | `shapeErrorHandler` with singleton reset |
| `scripts/development/sert-legal-start` | Electric container management and health polling |

## Debugging Stale Shapes

```bash
# Check if Electric is healthy
curl -s http://localhost:3002/v1/health

# Test shape API (should return data)
curl -s "http://localhost:3002/v1/shape?table=uk_lrt&offset=-1" | head -c 200

# Manually delete a broken shape
curl -s -X DELETE "http://localhost:3002/v1/shape?table=uk_lrt"
# Returns 202 if deletion API is enabled, 405 if not

# Check browser console for recovery messages
# Look for: "[TanStack DB] uk-lrt-admin: Broken shape (400), resetting"
```

## Gotchas

- `progressive` syncMode maps to `on-demand` internally in TanStack DB. In on-demand mode, offset defaults to `now`; in progressive, offset defaults to `void` (→ `-1`).
- The singleton reset pattern means the page must call `getXxxCollection()` again to get the fresh collection. Pages that hold a reference to the old collection won't automatically recover — a page refresh may be needed.
- The 30-second throttle prevents infinite recovery loops. If a shape is persistently broken, the user sees "Electric sync unavailable — try refreshing the page".
- The `--no-deps` flag on `docker compose up -d --no-deps electric` is critical to avoid Docker recreating the postgres container (which can cause data loss).
