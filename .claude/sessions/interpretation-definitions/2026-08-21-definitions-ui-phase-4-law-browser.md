---
session: Definitions UI Phase 4 — Law Definitions Browser
status: pending
opened: 2026-08-21
---

# Session: Definitions UI Phase 4 — Law Definitions Browser (PENDING)

## Problem

Need a per-law definition browser showing all definitions for a selected law with diagnostic context. Split-pane layout: law list on the left, definitions grid on the right. This is where the connection between records and diagnostic results becomes visible.

## Todo

- ⬜ Create route: `frontend/src/routes/admin/definitions/browse/+page.svelte`
- ⬜ Left panel: law list filtered by family, showing def count + resolution %
- ⬜ Right panel: GridLite of definitions for selected law
- ⬜ Definition type column: substantive / cross-ref / citation / internal-ref
- ⬜ Diagnostic status column: linked / term_not_found / no_citation / etc.
- ⬜ Family filter dropdown
- ⬜ Search/filter within definitions grid
- ⬜ Click definition row → opens detail panel (Phase 5)
- ⬜ URL state: preserve selected family + law in query params

## Dependencies

- ⬜ Phase 2 — ElectricSQL Shape (definitions in PGLite)
- ⬜ Phase 3 — Family Dashboard (nav structure)
- ⬜ Phase 1 — Backend API (diagnostic status per definition)
