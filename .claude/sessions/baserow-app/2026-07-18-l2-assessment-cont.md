---
session: Assessment App — Phase 1 Continuation
project: sertantai-legal
status: closed
opened: 2026-07-18
closed: 2026-07-18
outcome: success
commits: [1a1bfd8]

summary: >
  Completed the Assessment App end-to-end: fixed Law column, built form page with
  data source/elements/workflow actions, published to sertantai-compliance.baserow.site.
  Comprehensively documented Baserow SaaS API capabilities and limitations for App Builder.

decisions:
  - what: Document API limitations explicitly in the build script, not work around them silently
    why: Baserow SaaS API is a subset — parent_element_id, service PATCH, link text are all broken. These could change with Baserow updates. Explicit documentation means we'll know what to test when upgrading.
    result: 4 manual steps documented in script header, full API reference in session doc

  - what: Publish via API using .baserow.site subdomain
    why: Publishing must be automatable for customer onboarding. The domain+publish API works despite other App Builder API gaps.
    result: Fully automated create domain → publish async flow

metrics:
  api_endpoints_working: 12
  api_endpoints_broken: 3
  manual_steps_required: 4
  app_url: "https://sertantai-compliance.baserow.site"

lessons:
  - title: Baserow SaaS API is a strict subset of the open-source API for App Builder
    detail: >
      parent_element_id and place_in_container are completely absent from API responses —
      not nil, not returned at all. The open-source codebase has these fields. This means
      element nesting (putting inputs inside form containers) is UI-only on SaaS. Same for
      workflow action service config (PATCH returns 500). Self-hosting would give full API.
    tag: baserow

  - title: Baserow publish requires a domain first — subdomain format is xxx.baserow.site
    detail: >
      Publishing is a 2-step API flow: POST /api/builder/{id}/domains/ to create a
      domain (type sub_domain, domain_name xxx.baserow.site), then POST
      /api/builder/domains/{domain_id}/publish/async/ (returns 202). Without a domain,
      the app only works in preview mode.
    tag: baserow

  - title: Workflow action ordering matters — Update Row must execute before Open Page
    detail: >
      Form submit actions execute sequentially top-to-bottom. If Open Page (navigate)
      runs before Update Row, the page navigates away before the update completes and
      the change doesn't persist. The API creates actions in insertion order but the
      UI allows drag-reorder.
    tag: baserow

  - title: Reverse-engineering UI-configured API payloads is essential for undocumented APIs
    detail: >
      For the Update Row service config, we configured it in the UI then inspected via
      GET to learn the correct field_mappings format (field_id + formula referencing
      form_data.{element_id}). This pattern — configure in UI, inspect via API, codify —
      is the reliable workflow for undocumented App Builder features.
    tag: tooling

artifacts:
  - backend/scripts/build_assessment_app.exs
  - backend/scripts/seed_assessments.exs
  - docs/compliance/l2-risk-prioritisation/baserow-app-api-snapshot.txt

depends_on:
  - 2026-07-18-l2-assessment.md
  - 2026-07-18-scoping.md

enables:
  - Customer onboarding with Assessment App (seed + build + publish)
  - Phase 2 Hierarchy App (same API patterns)
  - Self-hosted Baserow evaluation (would unlock full API)
---

# Assessment App — Phase 1 Continuation

**Started**: 2026-07-18 14:00
**Meta**: `baserow-app/2026-07-18-meta.md`
**Previous**: `baserow-app/2026-07-18-l2-assessment.md`

## Todo
- [x] Fix Law column — `.*.value` for link_row (field_9564708 not field_9564837)
- [x] Page 2: Get Row data source created (id: 1952801, row_id from page_parameter.id)
- [x] Page 2: elements created — back link, heading (law name), form_container, 2x choice (status/risk), 2x input_text (gap/notes)
- [x] Page 2: notification + navigate actions configured
- [x] Update Row configured via UI (API blocked — see blockers below)
- [x] End-to-end workflow working: Queue → Review → Form → Submit → Update → Notify → Navigate back
- [x] Codify into repeatable script (`scripts/build_assessment_app.exs`) — idempotent, with documented manual steps
- [x] Publish App — https://sertantai-compliance.baserow.site (domain_id: 53423)

## Root Cause: Baserow SaaS API doesn't expose App Builder nesting/service fields

Confirmed by inspecting elements after UI drag-and-drop: `parent_element_id` and `place_in_container` are **not in the API response at all** — not nil, not empty, completely absent. The SaaS REST API is a subset of the open-source Baserow API.

This explains both blockers:
1. **Can't nest elements** — `parent_element_id` silently ignored on create/PATCH
2. **Can't configure Update Row** — service sub-object PATCH returns 500

The open-source Baserow codebase has these fields. The SaaS tier either strips them or uses a different API version.

### Options
- **Self-host Baserow** — get the full API including nesting and service config
- **UI-first, API-second** — build the form via UI, use API only for data sources/actions that work
- **Raise with Baserow** — ask if SaaS API will expose these fields

## Blocker: Update Row service config
The workflow action `update_row` creates fine, but PATCHing its `service` sub-object to set `row_id`, `field_mappings`, `integration_id`, `table_id` returns HTTP 500. 
- Creating with full service config also fails (400: row_id formula needs app context)
- Creating with integration+table works, but PATCH to add row_id/mappings → 500
- Notification and navigate actions PATCH fine — only update_row service breaks
- May be a Baserow SaaS bug or undocumented API limitation
- Workaround: configure Update Row action in Baserow UI, then inspect the result to learn the correct API format

## IDs (from previous session)
- Builder app: 497540
- Queue page: 1069371 (/)
- Form page: 1069372 (/assess/:id)
- Integration: 182002
- Queue data source: 1952708
- Table element: 14046134
- Assessments table: 1079908

## API Patterns Discovered

### What works via API (fully automatable)
- Create builder app: `POST /api/applications/workspace/{id}/` with `type: "builder"`
- Create integration: `POST /api/application/{app_id}/integrations/` with `type: "local_baserow"`
- Create pages: `POST /api/builder/{app_id}/pages/` with path params
- Create data sources: `POST /api/builder/page/{page_id}/data-sources/`
- PATCH data source row_id: `PATCH /api/builder/data-source/{id}/`
- Create elements: `POST /api/builder/page/{page_id}/elements/`
- PATCH element config: `PATCH /api/builder/element/{id}/` (NOT page-scoped)
- Table element fields/columns: PATCH with `fields` array
- Create workflow actions: `POST /api/builder/page/{page_id}/workflow_actions/`
- PATCH notification/open_page actions: `PATCH /api/builder/workflow_action/{id}/`
- Create domain: `POST /api/builder/{app_id}/domains/` with `{domain_name: "xxx.baserow.site", type: "sub_domain"}`
- Publish: `POST /api/builder/domains/{domain_id}/publish/async/` → 202

### What DOESN'T work via SaaS API (requires UI)
- `parent_element_id` / `place_in_container` — completely absent from API responses, silently ignored on create/PATCH. Elements can't be nested inside containers (form_container, columns) via API.
- Workflow action `service` sub-object PATCH → 500. Can't set `row_id`, `field_mappings` on update_row actions after creation.
- Table link field `value` property — rejected on create. Link text must be set via UI.

### Formula syntax
- Link_row fields: `get("current_record.field_XXXX.*.value")`
- Single_select fields: `get("current_record.field_XXXX.value")`
- Scalar fields: `get("current_record.field_XXXX")`
- Page parameters: `get("page_parameter.id")`
- Data source fields: `get("data_source.{ds_id}.field_XXXX.*.value")`
- Form data: `get("form_data.{element_id}")`

### Domain/publish
- Subdomain format: `{name}.baserow.site` (NOT `.baserow.io`)
- Domain type: `sub_domain` for Baserow-hosted, `custom_domain` for own domain
- Publish is async (202) — takes a few seconds to propagate

## Notes
- API patterns: see meta session for endpoint/formula reference
