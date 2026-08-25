---
session: "Progressive Sync & Filter Redesign (#155)"
status: pending
opened: 2026-08-25
github_issue: 155
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
---

# Session: Progressive Sync & Filter Redesign (#155) (PENDING)

## Problem

Hitting `/admin/definitions/browse` cold syncs the full 83K+ definitions dataset via Electric before the page is usable. The only filter is a Family dropdown that operates client-side after the full sync. Need a progressive sync strategy (bounded initial shape, e.g. recent 12 months) and a richer filter bar (family, recency, parse state, link state) with URL-persisted selections.

## Todo

- ⬜ Design sync strategy: tiered shapes (fast core + background full) vs dynamic shape subscription
- ⬜ Parameterise definitions Electric shape with `where` clause for bounded cold start
- ⬜ Redesign filter bar: family + recency + parse state + link state
- ⬜ Persist filter state in URL query params (shareable/bookmarkable)
- ⬜ Shape re-subscription on filter change (tear down + re-subscribe)
- ⬜ Sync status indicator (rows synced, whether more loading)
- ⬜ Verify warm-start delta sync not regressed

## Dependencies

- ✅ Electric shape sync working (`frontend/src/lib/pglite/sync.ts`)
- ✅ Definitions browse page built
