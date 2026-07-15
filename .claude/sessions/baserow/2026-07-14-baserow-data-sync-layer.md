# Title: Baserow data sync layer — proper separation of concerns

**Started**: 2026-07-14
**Architecture**: docs/BASEROW-SYNC-ARCHITECTURE.md
**Depends on**: baserow/2026-07-14-baserow-applicator-v2.md

## Todo
- [x] Engine: remove direct Baserow.* calls, use provider behaviour (18 → 2 in dispatch only)
- [x] Update sync formatters to use template field names (underscores throughout)
- [x] LAT formatter: text-based Legal_Register link (law_name, not row ID)
- [x] Actors link: text-based array linking (Name strings, not row IDs)
- [x] All link_row fields now use text values — zero row IDs in entire sync pipeline
- [ ] Remove provider field_specs (lrt_field_specs etc.) — templates own schema
- [ ] Move Actors link_row creation from engine to foundation template
- [ ] Deprecate ensure_fields — validate only, don't create (D1)
- [ ] Remove reverse link_row definitions from templates (D2)
- [ ] Sync data to qq DB — LRT, LAT, Actors, Controls, Control Mappings
- [ ] Verify text-based linking works end-to-end in Baserow

## Architecture violations to fix (from audit)
1. Engine calls `Baserow.format_lrt_row`, `Baserow.lrt_field_specs` etc. directly — not provider-agnostic
2. Field name strings duplicated between templates and formatters — rename in one breaks the other silently
3. `lrt_field_specs`, `lat_field_specs`, `controls_field_specs` in Provider AND in templates — two sources of truth
4. Engine creates `Actors` link_row field on LAT at sync time — schema management in data sync
5. `ensure_fields` still called by engine — creates fields instead of validating

## Notes
- qq DB has 13 tables with correct schema from applicator v2
- Data sync should only populate rows, not create/modify fields
- All link_row fields use text values matching target table Name primary field
