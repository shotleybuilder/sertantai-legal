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

## Design Change
Original plan was to repurpose the Assessment Queue. Wrong approach — the Legal Register
is a different data source (LRT table, not Assessments table). The Assessment and Actions
pages remain as-is, linked FROM the Legal Register hub.

## Notes
- LRT table: 1079905
- Assessment_Status lookup: field 9627086 (through Assessments reverse link 9564709, target Compliance_Status 9564710)
- Assess link uses: `get('current_record.field_9564709.0.id')` — first Assessment row ID
- Single quotes required in App Builder formulas for complex paths like `.*.value.value`
- Created Law_Title (9627030) and Law_Year (9627031) lookup fields on Assessments table
