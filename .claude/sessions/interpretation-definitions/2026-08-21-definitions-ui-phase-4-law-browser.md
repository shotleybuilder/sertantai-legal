---
session: Definitions UI Phase 4 — Law Definitions Browser
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Built split-pane law definitions browser at /admin/definitions/browse. Left panel
  shows searchable law list with def counts and linked ratios, right panel shows
  definitions table with type badges and link status. All data from PGLite.

decisions:
  - what: Use PGLite queries instead of backend API for browse page data
    why: >
      Definitions (83K rows) and definition_links (2.8K rows) are already synced
      to PGLite via ElectricSQL. PGLite queries avoid network round-trips and work
      offline. The law list join query runs locally in milliseconds.
    result: Zero backend API calls for the browse page, fully offline-capable
  - what: Three-state link status instead of binary linked/unlinked
    why: >
      Cross-ref definitions have three meaningful states — linked (root found),
      citation only (citation extracted but root not found), and unlinked (no
      citation extracted). This matches the diagnostic categories and gives the
      user actionable information at a glance.
    result: Green/amber/red status indicators matching diagnostic semantics

metrics:
  ui:
    table_columns: 5
    law_list_fields: 4
    type_errors: 0

artifacts:
  - frontend/src/routes/admin/definitions/browse/+page.svelte

depends_on:
  - 2026-08-21-definitions-ui-phase-2-electricsql-shape
  - 2026-08-21-definitions-ui-phase-3-family-dashboard
  - 2026-08-21-definitions-admin-ui

enables:
  - 2026-08-21-definitions-ui-phase-5-definition-detail
  - 2026-08-21-definitions-ui-phase-6-action-triggers
---

# Session: Definitions UI Phase 4 — Law Definitions Browser (CLOSED)

## Problem

Need a per-law definition browser showing all definitions for a selected law with diagnostic context. Split-pane layout: law list on the left, definitions grid on the right. This is where the connection between records and diagnostic results becomes visible. The dashboard (Phase 3) links here with `?family=` query param.

## Todo

- ✅ Create route: `frontend/src/routes/admin/definitions/browse/+page.svelte`
- ✅ Left panel: law list filtered by family, showing title, def count, year, linked/cross-ref ratio
- ✅ Right panel: definitions table for selected law (term, definition, section, type, status)
- ✅ Definition type indicator: substantive / cross-ref / citation (color-coded badges)
- ✅ Link status: linked / citation only / unlinked (green/amber/red)
- ✅ Family filter dropdown + text search within law list
- ✅ URL state: `?family=` and `?law=` query params preserved via replaceState
- ✅ Type check (0 errors) + production build pass
- ✅ Data source: PGLite queries on synced definitions + laws + definition_links tables

## Dependencies

- ✅ Phase 1 — Backend API (stats + diagnostic endpoints)
- ✅ Phase 2 — ElectricSQL Shape (definitions + links in PGLite)
- ✅ Phase 3 — Family Dashboard (nav structure, click-through link)
