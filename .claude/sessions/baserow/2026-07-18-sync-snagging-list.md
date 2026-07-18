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
- [ ] Fix single_select filter type — Baserow needs `single_select_equal` not `equal` for single_select fields (12 filter failures)
- [ ] Check for other tables with orphaned rows (no links)

## Notes
- Actor tuples extracted from all LAT provisions but Duties table is filtered (aggregated, governed, MEDIUM significance)
- Fix: pass `candidate_duties` into `ActorTupleSync.extract_tuples` SQL filter
- Moved `build_candidate_duties` earlier in engine chain (before actor tuples)
- Files changed: `actor_tuple_sync.ex`, `engine.ex`
