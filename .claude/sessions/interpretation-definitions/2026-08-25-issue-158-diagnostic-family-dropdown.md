---
session: "Diagnostic Family Dropdown (#158)"
status: pending
opened: 2026-08-25
github_issue: 158
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
---

# Session: Diagnostic Family Dropdown (#158) (PENDING)

## Problem

The family filter on `/admin/definitions/diagnostic` is a free-text `<input>` requiring the user to type the exact family name including emoji prefix (e.g. `💙 FIRE`). The browse page already uses a `<select>` dropdown populated from PGlite. The diagnostic page should match.

## Todo

- ⬜ Replace text input with `<select>` dropdown
- ⬜ Populate from synced PGlite data (same query as browse page)
- ⬜ Default "All Families" option passes no family param
- ⬜ Verify family param still passed correctly to diagnostic API

## Dependencies

- ✅ Diagnostic page built
- ✅ PGlite sync includes family data
