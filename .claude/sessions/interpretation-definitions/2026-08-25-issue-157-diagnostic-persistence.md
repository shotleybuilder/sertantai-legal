---
session: "Diagnostic Result Persistence (#157)"
status: pending
opened: 2026-08-25
github_issue: 157
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
---

# Session: Diagnostic Result Persistence (#157) (PENDING)

## Problem

Running the diagnostic on `/admin/definitions/diagnostic` is expensive (full table scan of 66K+ definitions). Results are stored entirely in Svelte `$state()` — navigating away loses everything. There is no signal that underlying data has changed since the last run, so the user cannot judge whether displayed results are still valid.

## Todo

- ⬜ Choose persistence strategy: localStorage cache vs PGlite table vs server-side
- ⬜ Persist `{summary, findings, ranAt, familyFilter}` across navigation
- ⬜ Restore cached results on page mount
- ⬜ Implement stale-data detection (`MAX(updated_at)` comparison)
- ⬜ Show "data changed since last run" banner when stale
- ⬜ Display "Diagnostic run at..." timestamp with relative time
- ⬜ No auto-re-run on stale detection (user-initiated only)

## Dependencies

- ✅ Diagnostic page built (UI phase 7)
- ✅ Diagnostic backend endpoint and logic exist
