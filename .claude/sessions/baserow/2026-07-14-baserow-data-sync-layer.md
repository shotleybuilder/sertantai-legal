---
session: Baserow data sync layer — proper separation of concerns
project: sertantai-legal
status: closed
opened: 2026-07-14
closed: 2026-07-14
outcome: partial
commits: [4ef081f]

summary: >
  Made engine provider-agnostic (18→2 direct Baserow refs), all formatters use underscore field names
  matching templates, all link_row fields use text-based linking (zero row IDs), engine loads specs
  from templates. Blocked on LAT sync — dynamic select options need a robust solution at the
  Client level, not a quick fix in the engine.

decisions:
  - what: Revert quick fix for dynamic select options
    why: Enriching specs with data values in the engine re-introduces the pattern we're removing. The right solution is at the Client/ensure_fields level.
    result: LAT sync blocked until proper solution built

lessons:
  - title: Dynamic select options need a first-class mechanism
    detail: >
      Baserow rejects row values that don't exist as select options. Template-defined options
      are static. Data has values (e.g. DRRP types like Duty, Responsibility, Rule) that only
      exist in the database. The Client needs an ensure_options_from_data step before batch_create.
    tag: baserow

artifacts:
  - backend/lib/sertantai_legal/sync/engine.ex
  - backend/lib/sertantai_legal/sync/providers/baserow.ex
  - backend/lib/sertantai_legal/sync/templates/foundation.ex
  - backend/lib/sertantai_legal/sync/actor_tuple_sync.ex

depends_on:
  - baserow/2026-07-14-baserow-applicator-v2.md

enables:
  - Dynamic select options architecture (ensure_options_from_data in Client)
  - Full data sync to qq DB once select options are resolved
---

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
- [x] Refactor engine to load field specs from templates via load_template_specs() (not provider)
- [x] Move Actors link_row creation from engine to foundation template
- [x] Deprecate ensure_fields — validate-only mode (warns on missing, updates select options, no creation)
- [x] Remove reverse link_row definitions from templates (D2) — verified already clean for active 14
- [ ] Sync data to qq DB — LRT ✓, Controls ✓, LAT blocked by select options, Actors blocked by LAT
- [ ] Verify text-based linking works end-to-end in Baserow

## Blocking issue: dynamic select options
LAT sync fails because multi_select fields (Duty_Type, Type/DRRP) have values in the data
that don't exist as select options in Baserow. Template defines empty options `[]` for dynamic fields.
The old provider field_specs queried the DB to build options. Now that templates own schema,
there's no mechanism to populate dynamic options before batch_create.

**Quick fix tried and reverted** — enriching specs with data values in the engine. Wrong approach.

**Right approach**: `ensure_fields` (or a new `ensure_select_options`) should accept formatted rows,
auto-extract unique values for each select/multi_select field, and add them as Baserow select options
BEFORE batch_create. This is a `Baserow.Client` responsibility — it should handle the "ensure options
exist before writing data" concern at the API level.

## Architecture violations to fix (from audit)
1. Engine calls `Baserow.format_lrt_row`, `Baserow.lrt_field_specs` etc. directly — not provider-agnostic
2. Field name strings duplicated between templates and formatters — rename in one breaks the other silently
3. `lrt_field_specs`, `lat_field_specs`, `controls_field_specs` in Provider AND in templates — two sources of truth
4. Engine creates `Actors` link_row field on LAT at sync time — schema management in data sync
5. `ensure_fields` still called by engine — creates fields instead of validating

## Principles
- We're building a stable, tolerant, extendable way of working with db-as-spreadsheet services
- Not finding the fastest path to getting data into Baserow
- Refactor properly — templates are the single source of truth for field specs
- Engine loads field specs from templates, not from provider-specific functions
- No shortcuts that create technical debt we'll need to undo later

## Notes
- qq DB has 13 tables with correct schema from applicator v2
- Data sync should only populate rows, not create/modify fields
- All link_row fields use text values matching target table Name primary field
