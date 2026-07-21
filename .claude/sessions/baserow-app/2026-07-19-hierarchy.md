---
session: Hierarchy App — Phase 2
project: sertantai-legal
status: closed
opened: 2026-07-19
closed: 2026-07-19
outcome: success
commits: [e2019f5]

summary: >
  Built the Hierarchy (Organisation) page on the Compliance Workbench with a same-page
  create+edit pattern. Single form always does Update Row — "Add Node" creates a blank row
  first then navigates to edit it. Discovered `Previous action > Create a row > Id` for
  chaining action results. Published to sertantai-compliance.baserow.site.

decisions:
  - what: Same-page create+edit instead of two-page queue→form pattern
    why: Hierarchy is reference data setup, not a review workflow. Users need to see the node list while adding/editing. Simpler UX than navigating between pages.
    result: Single page with table + form, query param ?edit=ROW_ID toggles mode

  - what: Form always does Update Row — no Create Row on the form
    why: Baserow App Builder has no conditional workflow actions (formula visibility is on the roadmap, GitLab #2472). Using only Update Row eliminates the need for create/edit mode switching.
    result: Zero conditional logic. "Add" creates blank row via button, then edits it. Clean pattern.

metrics:
  manual_steps: 10
  elements_created: 8
  data_sources: 2
  workflow_actions: 5

lessons:
  - title: "Previous action > Create a row > Id" chains action results in Baserow workflows
    detail: >
      When a button click triggers Create Row followed by Open Page, the navigate action
      can reference the new row's ID via Previous action > Create a row > Id. This is the
      formula for passing data between sequential workflow actions. Not documented in
      Baserow's public docs — discovered by building in UI and inspecting.
    tag: baserow

  - title: Same-page create+edit avoids conditional action visibility (which Baserow doesn't support yet)
    detail: >
      Formula-based element/action visibility conditions are on Baserow's roadmap (GitLab #2472)
      but not available. The "always Update Row" pattern sidesteps this — Add creates a blank
      row then navigates to edit it, so the form always operates in edit mode. Cleaner than
      the Assessment App's two-page pattern.
    tag: baserow

  - title: Page PATCH endpoint is /api/builder/pages/{id}/ not /api/builder/page/{id}/
    detail: >
      The page update endpoint uses plural "pages" while data sources and elements use
      singular "page". Inconsistent API naming — pages/PATCH vs page/GET.
    tag: baserow

  - title: Record selector element uses data_source_id for its options list
    detail: >
      The record_selector element type needs a data_source_id property pointing to a
      List Rows data source. It then shows those rows as selectable options with search.
      Used for the Parent Node selector (self-referential hierarchy link).
    tag: baserow

artifacts:
  - backend/scripts/build_hierarchy_page.exs

depends_on:
  - 2026-07-18-l2-assessment-cont.md
  - 2026-07-18-meta.md

enables:
  - Phase 3 Actions App (same create+edit pattern)
  - Repeatable customer onboarding (seed + build + publish)
---

# Hierarchy App — Phase 2

**Started**: 2026-07-19 08:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Review Hierarchy template schema — 6 fields, 1 existing row, table 1079904
- [x] Create page /org on Compliance Workbench via API
- [x] Data source + table element (Node, Hierarchy, Type, Parent, Description columns)
- [x] Form container + 5 inputs (Name, Hierarchy choice, Type choice, Parent record_selector, Description)
- [x] Workflow actions: Create Row, Notification, Refresh data source
- [x] Same-page edit: query param `edit`, Get Row data source, Edit link in table, form defaults bound to edit DS
- [x] Full round-trip: Add Node (create blank → edit) + Edit existing node both working
- [x] Re-published to sertantai-compliance.baserow.site
- [x] Codified: `scripts/build_hierarchy_page.exs` (idempotent, manual steps documented)
- [x] Clean up 2 empty test rows in Hierarchy table

## Manual UI Steps (after running build script)

1. Drag Node Name, Hierarchy, Node Type, Parent Node, Description INTO the Form container
2. Configure "Update a row" on Form submit:
   - Row ID: Query parameter > edit
   - Map: Name ← Node Name, Hierarchy_Type ← Hierarchy, Type ← Node Type, Parent ← Parent Node, Description ← Description
3. Configure "Create a row" on "+ Add Node" button:
   - Table: Hierarchy (leave all fields empty — creates blank row)
4. Configure "Open Page" on "+ Add Node" button:
   - Navigate to: Organisation /org?edit=#
   - edit = Previous action > Create a row > Id
5. Set Edit link text to "Edit" in table column config
6. Set Edit column edit param to: Data source: All Nodes > Id
7. Set "Edit Node" data source Row ID to: Query parameter > edit
8. Reorder form actions: Update Row → Notification → Refresh
9. Test Add + Edit workflows
10. Re-publish

## Same-page Create+Edit Pattern (Update Row only)

Architecture: form ALWAYS does Update Row. "Add" creates a blank row first, then navigates to edit it.

- **"+ Add Node" button**: click → Create Row (blank) → Open Page with `?edit=NEW_ROW_ID`
- **Form**: submit → Update Row → Notification → Refresh data source
- **Edit link** in table: navigates to same page with `?edit=ROW_ID`
- **Edit Node data source** (Get Row): row_id = query_parameter.edit → feeds form defaults
- **Key formula**: `Previous action > Create a row > Id` chains create → navigate

## IDs
- Page: 1070626 (/org)
- Data sources: All Nodes = 1954771, Edit Node = 1954869
- Table element: 14056080
- Form: 14056081
- Button: 14056466
- Elements: name=14056082, hierarchy=14056083, type=14056084, parent=14056085, desc=14056086

## Notes
- Adding to existing Compliance Workbench app, not a separate app
- Hierarchy = adjacency list (self-referential Parent field), no tree view in Baserow
- Node types: Organisation, Division, Department, Function, Site, Building, etc.
- Hierarchy types: org, geo, finance, reporting
- Same API patterns as Phase 1 — same SaaS limitations (parent_element_id, service PATCH)
