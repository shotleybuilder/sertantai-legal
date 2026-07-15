# Title: Revised Baserow architecture — applicator v2 implementation

**Started**: 2026-07-14
**Architecture**: docs/BASEROW-SYNC-ARCHITECTURE.md
**Depends on**: baserow/2026-07-14-baserow-primary-field-refactor.md

## Todo
- [ ] Implement Phase 1: create tables + verify primary fields via API
- [ ] Implement Phase 2: create simple fields + forward link_row fields (verify each)
- [ ] Implement Phase 3: create formula + lookup fields (all deps exist)
- [ ] Implement Phase 4: create views
- [ ] Move sync data fields (Family, Title, Year etc.) into foundation template (D3) ← NEXT
- [ ] Remove reverse link_row definitions from templates (D2)
- [ ] Deprecate ensure_fields in sync engine — validate only, don't create (D1)
- [ ] Build post-apply QA: mix templates.verify (check all tables have expected fields)
- [ ] Apply to qq DB (494412) — all 14 tables in one clean run
- [ ] Sync data to qq DB

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
