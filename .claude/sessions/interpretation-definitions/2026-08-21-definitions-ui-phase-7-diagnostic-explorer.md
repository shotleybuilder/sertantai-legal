---
session: Definitions UI Phase 7 — Diagnostic Explorer
status: pending
opened: 2026-08-21
---

# Session: Definitions UI Phase 7 — Diagnostic Explorer (PENDING)

## Problem

Need a standalone diagnostic drilldown view that lets you explore failure categories, distinguish actionable from ceiling items, and navigate to specific affected definitions. This replaces the CLI-based `Diagnostic.run |> summarise |> print_summary` workflow.

## Todo

- ⬜ Create route: `frontend/src/routes/admin/definitions/diagnostic/+page.svelte`
- ⬜ Category breakdown visualization (horizontal bar chart or summary cards)
- ⬜ Actionable vs ceiling category distinction (greyed-out for ceiling: parent_revoked, internal_ref, international_convention)
- ⬜ GridLite: findings filtered by selected category
- ⬜ Family filter dropdown
- ⬜ Columns: law name, term, citation, target law, nearest_term, detail
- ⬜ Click finding → navigate to definition in browse page
- ⬜ Top parents view: most-referenced unresolved parent laws
- ⬜ Run diagnostic button with family scope selector

## Dependencies

- ⬜ Phase 1 — Backend API (diagnostic endpoint returns findings)
- ⬜ Phase 3 — Family Dashboard (nav structure)
- ⬜ Phase 4 — Law Browser (link target for click-through)
