---
session: Dynamic select options — ensure options exist before batch_create
project: sertantai-legal
status: closed
opened: 2026-07-14
closed: 2026-07-14
outcome: success
commits: []

summary: >
  Implemented auto-ensure select options in Client.batch_create — scans rows for unique values,
  adds missing options to Baserow fields before posting data. All 5 tables synced successfully
  to qq DB: 428 LRT, 2539 LAT, 499 Actors (352 linked), 1754 Controls. Control Mappings
  blocked by sync ordering issue (needs controls mappings saved before CM sync runs).

decisions:
  - what: ensure_select_options lives inside Client.batch_create, always runs
    why: Client is the Baserow expert. Robustness over performance. No opt-in flags.
    result: Dynamic options auto-created — 13 Duty_Types, 90 Actors, 84 holders, all added automatically

  - what: Two-layer filtering — formatter cleans data, Client filters option names
    why: Formatter removes "none" from data values. Client rejects nil/empty as option names.
    result: clean_select and clean_multi_select in formatter, @invalid_option_values in Client

lessons:
  - title: Baserow number fields need explicit decimal_places in templates
    detail: >
      Template defined Year and Significance_Score as :number without opts. Baserow defaults to
      0 decimal places. Floats get rejected. Must always specify number_decimal_places in template.
    tag: baserow

  - title: sync_row_mappings must be cleared when database_id changes
    detail: >
      Stale mappings from old DB caused delta detector to see 428 rows as "unchanged" when the
      new DB was empty. Mappings are DB-specific — must be invalidated on DB switch.
    tag: sync

  - title: Control Mappings sync depends on Controls mappings existing first
    detail: >
      CM sync extracts law_names from controls sync_row_mappings. If controls were just created
      in the same run, mappings may not be queryable yet, or the ordering is wrong.
      Inherent sync design issue — needs dedicated session to fix.
    tag: sync

artifacts:
  - backend/lib/sertantai_legal/baserow/client.ex
  - backend/lib/sertantai_legal/sync/providers/baserow.ex
  - backend/lib/sertantai_legal/sync/templates/foundation.ex

depends_on:
  - baserow/2026-07-14-baserow-data-sync-layer.md

enables:
  - Sync engine redesign (ordering, mapping lifecycle, idempotent re-runs)
  - Control Mappings sync fix
---

# Title: Dynamic select options — ensure options exist before batch_create

**Started**: 2026-07-14
**Depends on**: baserow/2026-07-14-baserow-data-sync-layer.md

## Todo
- [ ] Design: where does ensure_options_from_data live? (Client vs SchemaManager vs Engine)
- [ ] Implement: scan formatted rows, extract unique values per select field
- [ ] Implement: add missing values as Baserow select options before batch_create
- [ ] Handle both single_select and multi_select fields
- [ ] Handle "none" and other invalid values (filter before option creation)
- [ ] Test: LAT sync to qq DB with dynamic DRRP types, Duty_Type values
- [ ] Test: LRT sync with dynamic holder vocabularies
- [ ] Verify all 5 tables sync successfully

## Problem
Baserow rejects row values that don't exist as select options. Templates define empty
options `[]` for dynamic fields (holders, DRRP types, duty sub-types). The data has
values that only exist in Postgres. Need a mechanism to ensure options exist before
writing data — at the right architectural layer.

## Decision (Gemini reviewed)
- **batch_create handles it** — not a separate call. Client is the Baserow expert.
- **Always check** — no opt-in flag. Robustness over performance.
- **Two-layer filtering**: formatter cleans data ("none"→nil), Client filters option names defensively before PATCH
- **Performance**: one field list + occasional PATCHes per batch, negligible vs failed syncs

## Notes
- Affected fields: Duty_Type, Type (DRRP), Regulated_Actors, Duty_Holder, Power_Holder, Rights_Holder, Domain, Geographic_Region, Purpose, Function
- Once common options established, PATCH frequency drops to near zero
- Client at `backend/lib/sertantai_legal/baserow/client.ex`
