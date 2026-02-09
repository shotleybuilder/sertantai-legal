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
| **409** | Stale shape handle (shape was deleted/recreated) | Yes -- client automatically retries with new handle |
| **400** | Broken offset (shape exists but internal state is corrupted) | **No** -- requires manual intervention |

## The Fix: Three Components

### 1. Server-Side: Enable Shape Deletion API

In `docker-compose.dev.yml`, set:

```yaml
ELECTRIC_ENABLE_INTEGRATION_TESTING: "true"
```

This enables the `DELETE /v1/shape?table=<table>` endpoint, which allows clients to delete broken shapes so Electric creates fresh ones.

**Production note**: This flag is for development. In production, consider a different strategy (e.g., restarting Electric with a clean state or using the Electric admin API).

### 2. Client-Side: onError Handler in TanStack DB

In `frontend/src/lib/db/index.client.ts`, the Electric shape config includes an `onError` handler:

```typescript
onError: async (error: unknown) => {
  if (
    error instanceof Error &&
    'status' in error &&
    (error as { status: number }).status === 400 &&
    !shapeResetAttempted
  ) {
    shapeResetAttempted = true;
    // Delete the broken shape via HTTP API
    await fetch(`${ELECTRIC_URL}/v1/shape?table=uk_lrt`, { method: 'DELETE' });
    await new Promise((resolve) => setTimeout(resolve, 1000));
    return {}; // Retry -- returning {} tells TanStack DB to retry the shape
  }
  // If already tried once, give up
  return;
}
```

Key behaviors:
- `return {}` from `onError` retries the shape request (but does NOT clear internal `_lastOffset` or `_shapeHandle`)
- A `shapeResetAttempted` flag prevents infinite retry loops
- The flag resets to `false` once data starts flowing (recordCount > 0)

### 3. Startup Script: Health Check Polling

`scripts/development/sert-legal-start` now:
- Starts Electric alongside postgres using `--no-deps` flag
- Polls `http://localhost:3002/v1/health` for up to 30 seconds before continuing
- Reports Electric URL in the startup summary

## Key Files

| File | Role |
|------|------|
| `docker-compose.dev.yml` | `ELECTRIC_ENABLE_INTEGRATION_TESTING=true` env var |
| `frontend/src/lib/db/index.client.ts` | `onError` handler with shape deletion and retry |
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
# Look for: "[TanStack DB] Broken shape detected (400), deleting and retrying"
```

## Gotchas

- `progressive` syncMode maps to `on-demand` internally in TanStack DB
- In `on-demand` mode, offset defaults to `now`; in `progressive` mode, offset defaults to `void` (which becomes `-1`)
- `return {}` from `onError` does NOT clear `_lastOffset` or `_shapeHandle` -- it retries with the same internal state, but after deleting the server-side shape, the server issues a new handle
- The `--no-deps` flag on `docker compose up -d --no-deps electric` is critical to avoid Docker recreating the postgres container (which can cause data loss)
