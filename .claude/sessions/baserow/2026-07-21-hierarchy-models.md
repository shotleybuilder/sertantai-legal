# Hierarchy Models — LRT → Hierarchy Link

**Started**: 2026-07-21
**Related**: `baserow-app/2026-07-19-hierarchy.md`, `baserow-app/2026-07-19-l1-legal-register.md`

## Problem

Laws in the Legal Register need to be linked to nodes in the Hierarchy table.
The Hierarchy table supports multiple classification trees in one table
(org, geo, finance, reporting). Different use cases require different links:

- **Geographic**: "Which laws apply at this site?" — filter LRT by geo nodes
- **Organisational**: "Which laws apply to this org unit?" — filter LRT by org nodes
- A single site can have multiple org points; laws link to both independently

## Decision: Single link, not per-hierarchy-type columns

**Single `Hierarchy` link_row on LRT** → many-to-many to any hierarchy node.

Why: The hierarchy table supports unlimited classification trees (org, geo, finance,
reporting, plus customer-defined). Per-type columns (Location, Org_Unit, etc.) don't
scale — every new hierarchy type would spawn new columns across the DB, and adding a
hierarchy type would require schema changes. A single link is tree-agnostic.

Query "laws at site X" = `link_row_contains` where node X is a geo node. The filter
doesn't care which tree the node belongs to — `Hierarchy_Type` on the node itself
handles classification. "All geo nodes for this law" = filter linked nodes by
Hierarchy_Type = geo. No schema change when customer adds a new hierarchy.

**Controls `Org_Unit` + `Location` is a mis-step** — should eventually be refactored
to a single `Hierarchy` link. Tech debt for later, not this session.

## Build Pattern (reference)

- **Source defines the link_row** → Baserow auto-creates reverse on target
- Never define both sides (causes name collision)
- Four-phase build: Phase 1 tables → Phase 2 fields + link_rows → Phase 3 formulas/lookups → Phase 4 views
- Template `requires()` controls dependency order — foundation currently requires `[]`
- Foundation would need `requires: [:hierarchy]` to ensure hierarchy table exists at Phase 2

## Decision: M:M pattern — direct link vs join table

- **Direct link_row**: when the relationship is purely structural, no metadata on the
  link itself. Law↔Hierarchy, Law↔Assessment. Baserow handles M:M natively.
- **Join table**: when the relationship carries its own attributes. ControlMappings
  has Strength (Primary/Supporting/Ancillary) — that describes the *mapping*, not
  either end.

Law→Hierarchy is structural (a law applies at a node, or it doesn't). Direct link_row.

## Decision: Auto-populate from customer data (CSV + JSON)

Manual linking of 400+ laws to hierarchy nodes is not feasible. Two-step flow:

### Step 1: Sites upload → Hierarchy table

Customer provides a CSV of their geographical locations. The import task creates
hierarchy nodes. CSV schema:

```csv
name,type,parent,hierarchy_type,description
UK,Country,,,Root country node
Scotland,Region,UK,,
England,Region,UK,,
Wales,Region,UK,,
Aberdeen,Site,Scotland,,Offshore support base
Manchester,Site,England,,Distribution centre
Penrith,Site,Wales,,Processing facility
```

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| name | yes | — | Becomes Hierarchy `Name` (primary field) |
| type | yes | — | Must match @node_types (Site, Region, Building, etc.) |
| parent | no | (root) | Parent node name. Empty = root node |
| hierarchy_type | no | geo | Defaults to `geo` for sites upload |
| description | no | — | Free text |

Import resolves parent names → row IDs. Requires top-down ordering (countries before
regions before sites) or the task does a topological sort.

### Step 2: Law mapping → LRT Hierarchy link

Accepts CSV or JSON. Links laws to hierarchy nodes.

**CSV format:**
```csv
hierarchy_node,lrt_name
Aberdeen,UK_uksi_2004_3391
Manchester,UK_uksi_2005_1140
```

**JSON format** (QQ already has this as `matched.json` per site directory):
```json
{"matched": [{"lrt_name": "UK_uksi_2004_3391", "vendor_id": "15", ...}]}
```

The task resolves `hierarchy_node` → hierarchy row ID and `lrt_name` → LRT row ID,
then PATCHes the `Hierarchy` link_row on each LRT row.

No value converting QQ's JSON to CSV — support both formats.

### QQ data analysis

- 20 sites across 3 UK regions (England, Scotland, Wales)
- 955 distinct laws across all sites, 551 at all sites
- **5 distinct applicability profiles** — driven entirely by region:
  - 13 England sites: 652 laws (identical sets)
  - 6 Scotland sites: 556 laws
  - 3 Wales sites: 599 laws
  - BSC, FRN: minor variants
- `matched.json` files have 100% match rate to `lrt_name`
- QQ data in `backend/data/imports/qq/` — 24 site directories with matched.json

## Current State

- `foundation.ex`: `Hierarchy` link_row added, `requires: [:hierarchy]` set
- `legal_register.yml`: Hierarchy column added
- Controls template still has `Org_Unit` + `Location` (tech debt, not this session)
- QQ matched.json data ready to use as-is for law mapping

## Todo
- [x] Decide: single `Hierarchy` link (not per-type columns) — scales with new hierarchy types
- [x] Decide: direct link_row (not join table) — no metadata on the mapping
- [x] Add single `Hierarchy` link_row field to `foundation.ex` LRT spec (target: :hierarchy)
- [x] Add `:hierarchy` to Foundation `requires()`
- [x] `Hierarchy_Filter` formula field on LRT — `concat(field('Hierarchy'), '')` for App Builder filtering
- [x] Legal Register: Hierarchy column CSS-hidden but filterable, View → link to Law Detail
- [x] Update `legal_register.yml` recipe — Hierarchy_Filter + View link, 4 nav columns removed
- [x] Analyse QQ site data — 5 profiles, region-driven, matched.json 100% match
- [x] Design CSV schema for sites upload (name, type, parent, hierarchy_type, description)
- [x] Build `mix baserow.hierarchy_import` — CSV sites → Hierarchy table rows (28 nodes created, idempotent)
- [x] Build `mix baserow.hierarchy_apply_laws` — JSON/CSV law mappings → LRT Hierarchy link (276/428 LRT rows updated)
- [x] `mix templates.apply --templates foundation` — Hierarchy link_row created on LRT (1 field)
- [x] Update Legal Register app page — Sites column reverted (Hierarchy is backend data, not a user-facing column)
- [ ] Explore Baserow Dashboards: "Laws at Site X" — first dashboard use case
  - Widget: select a hierarchy node → show count/list of applicable laws
  - Dashboard better than app columns for cross-cutting queries
  - See meta session: Dashboard was deferred until assessment data exists
- [ ] Check: does Hierarchy app page show reverse "Legal Register (via Hierarchy)" automatically?
- [ ] Future: refactor Controls `Org_Unit` + `Location` → single `Hierarchy` link

## Patterns Discovered

### Filterable link_row fields in App Builder
App Builder table Filter UI does NOT support link_row fields natively. Workaround:
1. Add a **formula field** in the backend table: `concat(field('Link_Field'), '')` — flattens to filterable text
2. In the table element's **Filter/Sort/Search settings**, tick Filter on that formula field
3. **No column needed** — the settings expose ALL data source fields, not just rendered columns
4. Users filter via "has value containing" — server-side, works across all rows

No CSS hiding required. The formula field is a filter-only backend field.

### Table column API format
- Text columns: `value` at top level (not nested under `config`)
- Link columns: `navigate_to_page_id`, `link_name`, `page_parameters` at top level
- Row ID reference: `get('current_record.id')` (not `get('current_record.field_id')`)
- Formula fields render raw JSON unless you use `.*.value` accessor

## Notes
- The reverse link (auto-created on Hierarchy) would show which laws are linked to each node
- This enables the query from the Hierarchy app page too: click a site → see its laws
- Assessment, Controls, Duties already link to LRT — this adds the spatial/org dimension
- link_row PATCH replaces (not appends) — task must read existing links before adding
- For QQ: could auto-generate the mapping from Geographic_Extent + Region, but CSV/JSON
  is the generic pattern that works for any customer
