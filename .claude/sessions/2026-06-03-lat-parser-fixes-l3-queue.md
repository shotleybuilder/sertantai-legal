# Title: LAT Parser Fixes + L3 Queue Filter for POC

**Started**: 2026-06-03 15:15
**Issues**: #88, #73, #90

## Todo
- [ ] #88 — Fix LAT parser 0 rows for 6 laws with valid body XML (older SI format)
- [ ] #73 — Fix sort_key duplicates from nested regulation structures
- [ ] #90 — LAT queue: filter by customer L3 applicability (org yes-laws)
- [ ] Re-parse affected laws and re-sync LAT to Baserow

## Notes
- #88: 6 laws have NumberOfProvisions > 0 but parser returns 0 LAT rows
- #73: 4 laws have minor sort_key duplicates (1-3 per law)
- #90: ~170 QQ yes-laws still need LAT parsing — no way to surface in queue
- Goal: best possible LAT data for Baserow POC sync

**Ended**: 2026-06-03 16:30
**Commits**: `0521cff`, `f384944`, `ba37e51`, `ebc289a`, `d867e3c`

## Summary
- Completed: 3 of 4 todos (#88 closed as transient, #73 fixed, #90 implemented). Re-parse todo deferred.
- Files: transforms.ex, lat_parser.ex, lat_admin_controller.ex, router.ex, queue/+page.svelte
- Outcome: Sort key duplicates eliminated (Roman numeral conversion + position tiebreaker). L3 applicability dropdown added to LAT queue so remaining ~170 QQ yes-laws can be parsed. #88 was transient failures not a parser bug.
- Next: Parse remaining QQ L3 laws via queue, re-sync LAT to Baserow, NAS/prod sync
