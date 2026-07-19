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
