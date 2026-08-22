---
session: Definitions UI Phase 7 — Diagnostic Explorer
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Built the diagnostic explorer page at /admin/definitions/diagnostic. On-demand
  diagnostic run with optional family filter, category bar chart with actionable/ceiling
  distinction, filterable findings table, and top unresolved parent laws section.
  Completes all 7 phases of the definitions admin UI.

decisions:
  - what: On-demand diagnostic run rather than pre-loaded results
    why: >
      Diagnostic.run/1 builds indexes and scans all unlinked cross-refs — takes a few
      seconds. Pre-loading on page mount would make the page feel slow on every visit.
      Explicit "Run Diagnostic" button sets user expectations and allows scoping by family.
    result: Page loads instantly, diagnostic runs only when requested
  - what: Cap findings table at 200 rows with overflow message
    why: >
      Full diagnostic can produce 3000+ findings. Rendering all in a DOM table would be
      sluggish. 200 rows covers the actionable categories for any single family filter.
      Users can narrow with category filter to see specific subsets.
    result: Snappy table rendering, category filter for drilling deeper

metrics:
  ui:
    summary_cards: 5
    category_bar_chart: true
    findings_table_cap: 200
    top_parents_cap: 20
    type_errors: 0

artifacts:
  - frontend/src/routes/admin/definitions/diagnostic/+page.svelte

depends_on:
  - 2026-08-21-definitions-ui-phase-1-backend-api
  - 2026-08-21-definitions-ui-phase-3-family-dashboard
  - 2026-08-21-definitions-ui-phase-4-law-browser
  - 2026-08-21-definitions-admin-ui

enables:
  - "Definitions admin UI complete — all 7 phases delivered"
---

# Session: Definitions UI Phase 7 — Diagnostic Explorer (CLOSED)

## Problem

Need a standalone diagnostic drilldown view that lets you explore failure categories, distinguish actionable from ceiling items, and navigate to specific affected definitions. This replaces the CLI-based `Diagnostic.run |> summarise |> print_summary` workflow.

## Todo

- ✅ Create route: `frontend/src/routes/admin/definitions/diagnostic/+page.svelte`
- ✅ Run diagnostic button with optional family text filter
- ✅ Summary cards: total unlinked, actionable, ceiling, citation resolved, genuinely unresolved
- ✅ Category breakdown with horizontal bar chart, click to filter, actionable vs ceiling styling
- ✅ Findings table filtered by selected category (law, term, category, citation, detail)
- ✅ Click law name → link to browse page
- ✅ Top parents section: 20 most-referenced unresolved parent laws
- ✅ Type check (0 errors) + production build pass

## Dependencies

- ✅ Phase 1 — Backend API (diagnostic endpoint returns findings + summary)
- ✅ Phase 3 — Family Dashboard (nav structure with Diagnostic link)
- ✅ Phase 4 — Law Browser (link target for click-through)
