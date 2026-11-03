---
session: Legal Register Hub — Phase 4
project: sertantai-legal
status: closed
opened: 2026-07-19
closed: 2026-07-19
outcome: success
commits: [52f65bd, 77f7567]

summary: >
  Built the Legal Register as the app's home page from the LRT table. Assessment Status
  with emoji lookups, Assess link to form via reverse link. Discovered single-quote
  requirement for complex App Builder formulas. CSS deferred pending QQ branding.

decisions:
  - what: Legal Register is a NEW page from LRT, not a repurposed Assessment Queue
    why: LRT and Assessments are different tables with different data. Repurposing the Assessment page meant fighting lookups through link_row. A fresh LRT-based page gives direct access to Title, Year, Family, Status.
    result: Clean page with 7 columns, all direct field references except Assessment Status (lookup)

  - what: Actions link removed — deferred to Phase 5 with rollup counts
    why: LRT → Assessments → Actions is a two-hop path. Can't link directly from Legal Register to Actions without an intermediate rollup. Phase 5 will build count fields that flow through.
    result: Legal Register links to Assessment only. Actions accessible from there.

  - what: CSS deferred — needs QQ branding guidelines
    why: Default Baserow styling is clean. Custom branding needs colour palette, logo, typography from the customer.
    result: Deferred to Phase 6 or customer onboarding step

metrics:
  columns: 7
  lookup_fields_created: 3
  emoji_statuses: 5

lessons:
  - title: App Builder formulas require single quotes for complex paths — double quotes crash the table
    detail: >
      get("current_record.field_X.*.value.value") with double quotes causes the entire
      table element to render blank with no error. The working syntax is
      get('current_record.field_X.*.value.value') with single quotes. Simple paths
      like get("current_record.field_X") work with either, but nested paths require singles.
    tag: baserow

  - title: Lookup of a single_select field needs .*.value.value — double unwrap
    detail: >
      A lookup field that targets a single_select returns [{id, value:{id, value, color}}].
      The path is .* (unwrap lookup array) then .value (get select object) then .value
      (get the text). Three levels deep. Discovered by adding the field via UI and
      inspecting the formula via API.
    tag: baserow

  - title: Don't repurpose existing pages — build new ones from the correct data source
    detail: >
      Initial attempt to turn Assessment Queue (Assessments table) into Legal Register
      (LRT table) failed because cross-table lookups don't work in App Builder column
      formulas. Building a fresh page from the right table is always cleaner.
    tag: baserow

artifacts:
  - backend/scripts/fix_legal_register_columns.exs

depends_on:
  - 2026-07-18-l2-assessment-cont.md
  - 2026-07-18-meta.md

enables:
  - Phase 5 Action Status Rollups
  - Phase 6 CSS/Branding
  - Customer onboarding with full app (Legal Register → Assessment → Actions → Hierarchy)
---

# Legal Register Hub — Phase 4

**Started**: 2026-07-19 12:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Reverted Assessment Queue page to original (was wrongly repurposed)
- [x] Create Legal Register page from LRT table (page 1071076, DS 1955715)
- [x] Table columns: Title, Year, Family, Status, Significance, Assessment Status
- [x] Legal Register set as home page (`/`), Assessment Queue moved to `/assess-queue`
- [x] Assessment_Status lookup field created on LRT table (9627086)
- [x] Emoji compliance statuses on Assessments table (✅⚠️❌⬜➖)
- [x] Assessment Status column working with single-quote formula
- [x] Assess link → Assessment Form (/assess/:id) with correct row ID via reverse link
- [x] Actions link removed (two-hop — deferred to Phase 5)
- [x] Assess link text set in UI
- [x] Published
- [ ] CSS styling — deferred, needs QQ branding guidelines (deferred)
- [x] Law Detail page created (`/law/:id`) — master→detail pattern
- [x] Legal Register table: 4 nav columns (Assess/Controls/Duties/Events) → 1 "View →" link
- [x] Hierarchy_Filter formula field on LRT: `concat(field('Hierarchy'), '')` — flattens link_row to filterable text
- [x] Hierarchy filterable via Filter/Sort/Search settings — no column needed, no CSS
- [x] View → link working (uses `current_record.id` not `field_id`)
- [x] Law Detail DS Row ID set to `page_parameter.id` via API (no manual step)
- [x] Test: View → navigates to Law Detail — title, metadata, sites, nav links all working
- [x] Legal Register Detail: all 4 nav links fixed to use field names not field IDs
- [x] Assessment Form: changed from `/assess/:id` (Get Row) to `/assess?law=NAME` (List Rows + link_row_contains filter)
- [x] All nav links now consistent: `?law=NAME` pattern (Controls, Duties, Events, Assess)
- [x] Data source formulas use `data_source.DS_NAME.FIELD_NAME` not `field_{ID}` syntax
- [ ] CSS styling — deferred, needs QQ branding guidelines
- [ ] Test: Assess → from Legal Register Detail loads correct assessment

## Design Changes

### Original: Assessment Queue repurpose (rejected)
Wrong approach — the Legal Register is a different data source (LRT table, not Assessments).

### Legal Register redesign (2026-07-21)
- **List page**: 8 columns (Title, Year, Family, Status, Significance, Assessment, Actions, View →)
- **Detail page**: `/law/:id` — full law info, sites, and nav links
- **Hierarchy filtering**: Hierarchy_Filter formula field (`concat(field('Hierarchy'), '')`) enabled in Filter/Sort/Search settings — no visible column needed
- **All nav links use `?law=NAME`**: Controls, Duties, Events, Assess — consistent pattern, no Baserow row IDs in URLs
- **Assessment Form**: changed from Get Row by `:id` path param to List Rows filtered by `link_row_contains Legal_Register` with `?law=` query param

## Notes
- LRT table: 1079905
- Legal Register Detail page: 1075303 (`/law/:id`)
- Data source formulas: use `data_source.DS_NAME.FIELD_NAME` (field names, not `field_ID`)
- Table column formulas: still use `current_record.field_ID` (different context)
- Assessment_Status lookup: field 9627086
- Single quotes required in App Builder formulas for complex paths like `.*.value.value`
