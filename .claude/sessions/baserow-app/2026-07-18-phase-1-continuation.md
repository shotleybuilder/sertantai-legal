# Assessment App — Phase 1 Continuation

**Started**: 2026-07-18 14:00
**Meta**: `baserow-app/2026-07-18-meta.md`
**Previous**: `baserow-app/2026-07-18-phase-1-assessment-app.md`

## Todo
- [x] Fix Law column — `.*.value` for link_row (field_9564708 not field_9564837)
- [x] Page 2: Get Row data source created (id: 1952801, row_id from page_parameter.id)
- [x] Page 2: elements created — back link, heading (law name), form_container, 2x choice (status/risk), 2x input_text (gap/notes)
- [x] Page 2: notification + navigate actions configured
- [x] Update Row configured via UI (API blocked — see blockers below)
- [x] End-to-end workflow working: Queue → Review → Form → Submit → Update → Notify → Navigate back
- [x] Codify into repeatable script (`scripts/build_assessment_app.exs`) — idempotent, with documented manual steps
- [ ] Publish App

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

## Notes
- API patterns: see meta session for endpoint/formula reference
