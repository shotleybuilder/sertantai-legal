---
session: Definitions UI Phase 6 — Action Triggers
status: pending
opened: 2026-08-21
---

# Session: Definitions UI Phase 6 — Action Triggers (PENDING)

## Problem

Need UI buttons to trigger definition operations (parse, resolve, diagnose) that currently require CLI access. Operations should show progress/status and update the synced data when complete.

## Todo

- ⬜ Reparse button on law list (single law) — calls POST /api/admin/definitions/parse
- ⬜ Reparse button on family dashboard (batch by family)
- ⬜ Resolve button on dashboard — calls POST /api/admin/definitions/resolve
- ⬜ Diagnose button on dashboard and diagnostic page
- ⬜ Loading spinner during operation
- ⬜ Success/error toast notifications
- ⬜ Display last-run timestamps (definitions_parsed_at, last resolved, last diagnosed)
- ⬜ Confirmation dialog for batch operations
- ⬜ Disable buttons during in-progress operations (prevent double-submit)

## Dependencies

- ⬜ Phase 1 — Backend API (parse/resolve/diagnose endpoints)
- ⬜ Phase 3 — Family Dashboard (button placement)
- ⬜ Phase 4 — Law Browser (per-law reparse button)
