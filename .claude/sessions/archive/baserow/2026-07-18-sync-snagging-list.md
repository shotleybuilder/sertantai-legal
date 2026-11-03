---
session: Baserow sync snagging list
project: sertantai-legal
status: closed
opened: 2026-07-18
closed: 2026-07-18
outcome: partial
commits: [7171e9a, 0852a23]

summary: >
  Fixed five Baserow sync bugs: duplicate row dedup in list_all_rows, actor tuple scoping
  to candidate_duties, ControlMappings formula (join/lookup/isblank for link_row fields),
  duplicate view prevention, and view filter/sort/group implementation (was TODO stubs).
  Two items deferred: single_select filter type and orphaned row audit.

decisions:
  - what: list_all_rows returns Name → [row_ids] list instead of Name → row_id map
    why: Multiple syncs or format changes create duplicate Baserow rows with the same Name. Map.put silently keeps only the last row_id, so delete reconciliation misses duplicates.
    result: Controls went from 1,754 deletes (first pass) to 3,508 deletes (caught all duplicates)

  - what: Move build_candidate_duties before actor_tuples in sync chain
    why: Actor tuples need the same duty scoping as controls — without it, 70% of tuples had no matching duties in the customer's filtered register
    result: 499 → 151 tuples (348 orphaned rows removed)

metrics:
  actor_tuples: { before: 499, after: 151, removed: 348, reduction_pct: 70 }
  controls_dedup: { first_pass_deletes: 1754, second_pass_deletes: 3508, remaining: 1178 }
  duplicate_views_deleted: 146
  views_recreated: 86
  filter_failures: 12

lessons:
  - title: Baserow link_row fields need join() in formulas — they return arrays not strings
    detail: >
      field('Duties') on an empty link_row doesn't return '' — isblank() on it also fails.
      Must wrap in join(): isblank(join(field('Duties'), '')). Same for concat — use
      join(field(...), ', ') or join(lookup(...), ', ') to coerce to text. Two rounds of
      debugging to discover this.
    tag: baserow

  - title: Map-based CUD silently loses duplicate Baserow rows
    detail: >
      list_all_rows built a Name → row_id map. When multiple Baserow rows share the same Name
      (from successive syncs or format changes), Map.put keeps only the last. Delete
      reconciliation then deletes one copy per Name, leaving duplicates. Fix: Name → [row_ids]
      list, split_cud takes first for update, rest become delete candidates.
    tag: sync

  - title: Baserow single_select fields need single_select_equal filter type, not equal
    detail: >
      The equal filter type is incompatible with single_select fields in Baserow API.
      12 filter creation failures across views. Needs a field-type-aware filter type mapper.
      Deferred.
    tag: baserow

  - title: SchemaManager view creation had no idempotency — TODO stubs for filters/sorts/groups
    detail: >
      Phase 4 created views without checking if they existed (unlike Phase 2 which checks fields).
      Filters, sorts, and group_bys were TODO stubs that returned :ok. Three separate bugs
      in one area: no dedup, no filter impl, no sort/group impl.
    tag: baserow

artifacts:
  - backend/lib/sertantai_legal/baserow/client.ex
  - backend/lib/sertantai_legal/baserow/schema_manager.ex
  - backend/lib/sertantai_legal/sync/actor_tuple_sync.ex
  - backend/lib/sertantai_legal/sync/engine.ex
  - backend/lib/sertantai_legal/sync/templates/control_mappings.ex
  - backend/scripts/fix_mapping_formula.exs
  - backend/scripts/dedup_views.exs
  - backend/scripts/rebuild_views.exs

depends_on:
  - 2026-07-16-evidence-layer.md
  - 2026-07-14-sync-engine-redesign.md

enables:
  - Clean Baserow views with working filters/sorts/groups
  - Reliable delete reconciliation for all sync tables
  - Customer-scoped actor tuples matching duty filters
---

# Baserow Sync Snagging List

**Started**: 2026-07-18 08:45

## Todo
- [x] Filter Actor Tuples to candidate_duties (499 → 151, 70% reduction)
- [x] Test sync Actors table — 348 deleted, 151 kept, 352 LAT provisions linked
- [x] Controls table had stale rows — re-synced: 1,178 scoped controls, 1,754 deleted
- [x] Fix list_all_rows dedup bug — Name → [row_ids] list instead of single row_id. split_cud returns duplicate_ids, find_deletes merges orphans + duplicates
- [x] Controls re-synced: 3,508 deleted (was 1,754 — caught all duplicates), 1,178 remain
- [x] Fix ControlMappings Mapping formula — `join()` needed for link_row fields in Baserow formulas, `lookup('Controls', 'Title')` instead of UUID, `isblank(join(field(...), ''))` for empty check
- [x] Fix duplicate views — SchemaManager phase_4 now checks existing views before creating. 146 duplicates cleaned. Added `list_views` + `delete_view` to Client.
- [x] Implement view filters/sorts/groups — was TODO stubs. 86 views recreated. Filters/sorts/groups now applied via Baserow API.
- [x] Fix single_select filter type — field type-aware resolve_filter_type/2, views rebuilt with 0 filter failures (1 group_by on link_row unsupported)
- [ ] Check for other tables with orphaned rows (no links) (deferred)

## Notes
- Actor tuples extracted from all LAT provisions but Duties table is filtered (aggregated, governed, MEDIUM significance)
- Fix: pass `candidate_duties` into `ActorTupleSync.extract_tuples` SQL filter
- Moved `build_candidate_duties` earlier in engine chain (before actor tuples)
- Files changed: `actor_tuple_sync.ex`, `engine.ex`
