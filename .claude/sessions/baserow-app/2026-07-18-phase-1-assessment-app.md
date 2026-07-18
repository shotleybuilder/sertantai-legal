---
session: Assessment App — Phase 1
project: sertantai-legal
status: closed
opened: 2026-07-18
closed: 2026-07-18
outcome: partial
commits: []

summary: >
  Seeded 428 assessment rows in Baserow and built the Assessment Queue page
  (Page 1) of the Compliance Workbench app via API. Form page (Page 2) deferred.
  Discovered Baserow App Builder API patterns: integration required, element PATCH
  endpoint is /api/builder/element/{id}/, link_row fields need .*.value in formulas.

decisions:
  - what: Build App programmatically via Baserow API, not manually in UI
    why: Must be repeatable for every new customer onboarding. Manual UI work doesn't scale.
    result: Script-driven app creation proven — pages, data sources, elements, columns all API-configurable

  - what: Explore API interactively first, codify into repeatable script after
    why: Baserow App Builder API is undocumented. Need to discover endpoints, payload formats, and quirks before writing production code.
    result: Key patterns discovered (integration, element PATCH, field formulas, link fields)

metrics:
  assessments_seeded: 428
  app_pages: 2
  queue_columns: 6
  api_endpoints_discovered: 5

lessons:
  - title: Baserow App Builder data sources require an integration — nil integration_id means no data
    detail: >
      Creating a data source with type local_baserow_list_rows and table_id is not enough.
      Must first create a local_baserow integration via POST /api/application/{id}/integrations/
      and set integration_id on the data source. Without it, "Incomplete configuration" error.
    tag: baserow

  - title: Table element field formulas for link_row fields need .*.value suffix
    detail: >
      get("current_record.field_XXXX") on a link_row field returns raw JSON {"id":N,"value":"..."}.
      Must use get("current_record.field_XXXX.*.value") to extract the display text.
      Single_select fields use .value (no *).
    tag: baserow

  - title: Table element link fields don't accept a value property
    detail: >
      Unlike text fields which use {"type":"text","value":{formula}}, link fields use
      {"type":"link","navigate_to_page_id":N,"navigation_type":"page","page_parameters":[...]}.
      The value property causes INVALID_FIELD_PROPERTY error.
    tag: baserow

  - title: Element PATCH endpoint is /api/builder/element/{id}/ not /api/builder/page/{page_id}/elements/{id}/
    detail: >
      Page-scoped element URLs return 404 for PATCH. The correct endpoint drops the page prefix.
      GET for listing elements uses the page-scoped URL, PATCH uses the element-scoped URL.
    tag: baserow

artifacts:
  - docs/compliance/l2-risk-prioritisation/ASSESSMENT-APP-DESIGN.md
  - backend/scripts/seed_assessments.exs
  - backend/scripts/build_assessment_app.exs

depends_on:
  - 2026-07-18-baserow-app-dashboards.md

enables:
  - Phase 1 continuation (form page, events, publish)
  - Repeatable app creation script for customer onboarding
---

# Assessment App — Phase 1

**Started**: 2026-07-18 12:30
**Design**: `docs/compliance/l2-risk-prioritisation/ASSESSMENT-APP-DESIGN.md`
**Meta**: `baserow-app/2026-07-18-meta.md`

## Todo
- [x] Seed Assessments table — 428 rows created (1 per law, Risk_Level from significance_rating, all "Not Assessed")
- [x] Build App skeleton: "Compliance Workbench" (builder_id: 497540)
- [x] Page 1 (Queue): heading + table element + "All Assessments" List Rows data source
- [x] Page 1: table columns configured (Law, Status, Risk, Owner, Review Due, Review → link to form)
- [ ] Fix Law column — shows raw JSON, needs `.*.value` suffix for link_row formula (deferred)
- [ ] Page 2 (Form): fix Get Row data source (row_id formula syntax) (deferred)
- [ ] Page 2: form elements (compliance status, risk, owner, dates, notes) (deferred)
- [ ] Page 2: events (On Submit → Update Row → Notification → Navigate) (deferred)
- [ ] Test end-to-end workflow (deferred)
- [ ] Publish App (deferred)

## IDs
- Builder app: 497540
- Queue page: 1069371 (/)
- Form page: 1069372 (/assess/:id)
- Shared page: 1069370
- Queue data source: 1952708
- Assessments table: 1079908

## Notes
- Design doc has full wireframes and element specs
- Law-level grain, simple risk scoring, linked personnel, workspace member auth
- Generic — not customer-specific
