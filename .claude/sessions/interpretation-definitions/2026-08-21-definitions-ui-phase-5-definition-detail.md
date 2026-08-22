---
session: Definitions UI Phase 5 — Definition Detail
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Added inline definition detail panel to the browse page. Clicking a definition
  row shows full text, metadata, extracted citation, and root definitions (from
  PGLite definition_links join). Includes legislation.gov.uk links for both
  child and root laws.

decisions:
  - what: Inline bottom panel in browse page instead of separate route or modal
    why: >
      A slide-over or modal would obscure the definitions table context. An inline
      panel below the split-pane keeps the selected row visible and highlighted (blue)
      while showing the detail. Toggle on/off by clicking the same row again.
    result: Detail panel integrates naturally into the browse workflow
  - what: Root definition lookup via PGLite join, not backend API
    why: >
      definition_links and definitions are both synced to PGLite. A local JOIN
      on child_definition_id is instant, no network call needed. Falls back to
      an amber message if the root is linked but not found in local sync.
    result: Zero-latency root definition display

metrics:
  ui:
    detail_sections: 4
    type_errors: 0

artifacts:
  - frontend/src/routes/admin/definitions/browse/+page.svelte

depends_on:
  - 2026-08-21-definitions-ui-phase-4-law-browser
  - 2026-08-21-definitions-ui-phase-2-electricsql-shape
  - 2026-08-21-definitions-admin-ui

enables:
  - 2026-08-21-definitions-ui-phase-6-action-triggers
---

# Session: Definitions UI Phase 5 — Definition Detail (CLOSED)

## Problem

Need a detail view showing the full cross-reference chain for a single definition: child definition → extracted citation → parent law → root definition. This is the key insight view — understanding *why* a definition is linked or unlinked. Opens from clicking a definition row in the Phase 4 browse page.

## Todo

- ✅ Create detail panel integrated into browse page (bottom panel, toggleable)
- ✅ Show: term, full definition text, section_id, scope, type badge, link status
- ✅ If cross-ref with citation: show extracted citation text in grey box
- ✅ If linked: show root definition(s) with text, law title, section, green box
- ✅ Wire into browse page — click row opens detail, click again closes, blue highlight
- ✅ Link to legislation.gov.uk source (child law + each root law)
- ✅ Type check (0 errors) + production build pass

## Dependencies

- ✅ Phase 4 — Law Browser (detail opens from definition row click)
- ✅ Phase 2 — ElectricSQL Shape (definition_links for root lookups)
- ✅ Phase 1 — Backend API (diagnostic endpoints)
