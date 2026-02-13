# Remove Legacy Stats Columns

**Started**: 2026-02-02 14:50 UTC
**Issue**: None (cleanup from previous consolidation sessions)

## Columns Removed

### Amended By (🔻) - 4 columns
- `amended_by_stats_affected_by_count_per_law`
- `amended_by_stats_affected_by_count_per_law_detailed`
- `rescinded_by_stats_rescinded_by_count_per_law`
- `rescinded_by_stats_rescinded_by_count_per_law_detailed`

### Amending (🔺) - 4 columns
- `amending_stats_affects_count_per_law`
- `amending_stats_affects_count_per_law_detailed`
- `rescinding_stats_rescinding_count_per_law`
- `rescinding_stats_rescinding_count_per_law_detailed`

## Todo

- [x] Identify where columns are used (UkLrt, ParsedLaw, frontend)
- [x] Create migration to drop columns
- [x] Remove from UkLrt resource
- [x] Remove from ParsedLaw struct
- [x] Remove from frontend sync/schema
- [x] Run tests
- [x] Commit: `78fa4e2`

## Notes

- These were replaced by `*_per_law` JSONB fields in previous consolidation
- Also removed `build_count_per_law_summary/1` and `build_count_per_law_detailed/1` helper functions
- Removed 13 legacy tests for the removed functions
- All 684 backend tests pass, all 95 frontend tests pass
- Updated docs/LRT-SCHEMA.md to v1.1 with removed columns noted

**Ended**: 2026-02-02 15:35 UTC
