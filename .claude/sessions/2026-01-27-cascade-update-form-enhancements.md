# Title: Cascade Update Form Enhancements

**Started**: 2026-01-27T13:39:48Z
**Ended**: 2026-01-27T14:50:01Z

## Todo
- [x] Fix enacting parents still showing after update
- [x] Add parse workflow for "Not in Database" laws
- [x] Persist metadata across modal reopens
- [x] Add Full/Min reparse toggle for in-database laws
- [x] Filter reparsed laws via cascade processed status (replaced naive updated_at approach)

## Commits
- `07e5384` fix(migration): Re-parse 8 records with merged law blocks in JSONB
- `036a850` fix(cascade): Filter processed entries and add parse workflow for new laws
- `7962fba` feat(cascade): Persist metadata for not-in-db laws across modal reopens
- `88b8328` feat(cascade): Add Full/Min reparse toggle for in-database laws
- `48bf008` feat(cascade): Filter out recently reparsed laws from in-db list (reverted)
- `c27791f` fix(cascade): Use processed status instead of updated_at to filter reparsed laws

## Notes
- Enacting parents fix: `get_affected_laws_summary_from_db` now filters to pending-only.
- Not-in-DB workflow: Get Metadata + Parse & Review buttons. Metadata persisted to cascade entry.
- Reparse toggle: Default Min (amended_by + repeal_revoke). Switch to Full for all 7 stages.
- Reparsed filter: `confirm` endpoint now calls `mark_cascade_processed`. The pending-only filter in summary naturally excludes confirmed laws. Reverted updated_at approach (too naive - migrations touch updated_at).
