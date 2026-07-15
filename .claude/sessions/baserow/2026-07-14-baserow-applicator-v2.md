---
session: Revised Baserow architecture — applicator v2 implementation
project: sertantai-legal
status: closed
opened: 2026-07-14
closed: 2026-07-14
outcome: success
commits: [cc0f694]

summary: >
  Built three-layer Baserow architecture: Client (pure API) → SchemaManager (4-phase creation) →
  Applicator (template resolution). Foundation template now defines complete LRT/LAT schemas.
  Successfully applied 13 tables, 180 fields, 68 views to clean qq DB in one idempotent run.
  Architecture audit identified 5 data layer concerns to address before sync.

decisions:
  - what: Three-layer split — Client / SchemaManager / Provider
    why: Separation of concerns. Client is extractable as hex package, SchemaManager handles Baserow quirks, Provider holds sync formatters. When Airtable comes, only SchemaManager + Client change.
    result: 895-line Client, SchemaManager with 4-phase verify-create-validate, 730-line Provider

  - what: Templates own ALL field definitions including sync data fields
    why: Two sources of truth (templates + provider field_specs) caused naming conflicts and duplication
    result: Foundation template now has 21 LRT fields + 13 LAT fields. Provider field_specs to be deprecated in next session.

  - what: SchemaManager uses 4-phase creation with per-step verification
    why: Single-pass creation failed on formula deps, lookup deps, and reverse link collisions
    result: Phase 1 tables → Phase 2 simple+link → Phase 3 formula+lookup → Phase 4 views. Idempotent on re-run.

metrics:
  tables_created: 13
  fields_created: 180
  views_created: 68
  client_lines: 895
  provider_lines: 730
  tests: { total: 1485, failures: 0 }

lessons:
  - title: Four-phase creation solves formula and lookup dependency ordering
    detail: >
      Formulas reference fields by name — must exist first. Lookups reference fields on OTHER tables.
      Creating all simple fields across all tables before any formulas guarantees dependencies are met.
    tag: baserow

  - title: Idempotency comes from checking Baserow API, not local state
    detail: >
      SchemaManager queries Baserow for existing tables/fields before creating. Re-running after
      partial failure adds only what's missing. No --fresh flag needed.
    tag: baserow

  - title: Architecture audit before coding prevents compounding technical debt
    detail: >
      Before syncing data, audited the engine for architecture violations. Found 5 issues
      (direct Baserow refs, duplicated field names, schema in engine). Catching these before
      building the data layer prevents the same pattern of fix-and-retry.
    tag: baserow

artifacts:
  - backend/lib/sertantai_legal/baserow/client.ex
  - backend/lib/sertantai_legal/baserow/schema_manager.ex
  - backend/lib/sertantai_legal/sync/templates/foundation.ex

depends_on:
  - baserow/2026-07-14-baserow-primary-field-refactor.md

enables:
  - Baserow data sync layer (with proper separation of concerns)
  - post-apply QA (mix templates.verify)
  - Airtable adapter (add SchemaManager + Client, Applicator unchanged)
---

# Title: Revised Baserow architecture — applicator v2 implementation

**Started**: 2026-07-14
**Architecture**: docs/BASEROW-SYNC-ARCHITECTURE.md
**Depends on**: baserow/2026-07-14-baserow-primary-field-refactor.md

## Todo
- [x] Implement Phase 1: create tables + verify primary fields via API
- [x] Implement Phase 2: create simple fields + forward link_row fields (verify each)
- [x] Implement Phase 3: create formula + lookup fields (all deps exist)
- [x] Implement Phase 4: create views
- [x] Move sync data fields (Family, Title, Year etc.) into foundation template (D3)
- [x] Apply to qq DB (494412) — 13 tables, 180 fields, 68 views in one clean run
- [ ] Remove reverse link_row definitions from templates (D2) (carry forward)
- [ ] Deprecate ensure_fields in sync engine — validate only, don't create (D1) (carry forward)
- [ ] Update sync formatters to match new field names (carry forward)
- [ ] Engine: remove direct Baserow.* references, use provider behaviour (carry forward)
- [ ] Field names: single source of truth from templates, not duplicated in formatters (carry forward)
- [ ] Move Actors link_row creation from engine to foundation template (carry forward)
- [ ] Build post-apply QA: mix templates.verify (carry forward)
- [ ] Sync data to qq DB (carry forward)

## Done
- [x] Split Providers.Baserow → Baserow.Client (895 lines) + Providers.Baserow (730 lines)
  - Client: pure API wrapper, no domain knowledge
  - Provider: ProviderBehaviour + sync formatters, delegates to Client
  - All 1485 tests pass, no caller changes needed
- [x] Create Baserow.SchemaManager — 4-phase schema creation with verify-create-validate
  - Phase 1: tables + primary fields (verify existence via API)
  - Phase 2: simple fields + forward link_row (skip existing)
  - Phase 3: formula + lookup fields (all deps exist, skip lookup errors gracefully)
  - Phase 4: views
- [x] Add Applicator.build_table_specs/2 — converts template modules to SchemaManager format
- [x] Wire mix templates.apply to use SchemaManager instead of old applicator flow
- [x] All 1485 tests pass

## Notes
- Architecture doc has 5 decisions (D1-D5) from Gemini review
- Key: verify before create, validate after create, persist ID — for every resource
- Baserow is source of truth, local config is cache
- qq DB has leftover tables from failed runs — need cleaning before apply
- Client at `backend/lib/sertantai_legal/baserow/client.ex` — extractable as hex package later
- SchemaManager at `backend/lib/sertantai_legal/baserow/schema_manager.ex`
- Three-layer architecture: Applicator (template resolution) → SchemaManager (4-phase Baserow) → Client (HTTP)
- When Airtable comes: add Airtable.SchemaManager + Airtable.Client, Applicator unchanged
