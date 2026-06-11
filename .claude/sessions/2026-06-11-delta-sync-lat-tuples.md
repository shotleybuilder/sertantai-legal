# Title: Delta Sync for LAT and Actor Tuples

**Started**: 2026-06-11 21:00

## Todo
- [x] LAT sync: already had DeltaDetector, added mapping timestamp updates after batch_update
- [x] Actor Tuples sync: added DeltaDetector (create new, delete orphaned, skip unchanged)
- [ ] Verify idempotency: re-run without --clean produces 0 creates, 0 deletes

## Notes
- LRT delta sync already done (previous session)
- LAT delta was already wired but missing timestamp updates on update path
- Actor Tuples were blind batch_create — now uses delta detect + orphan deletion
- Tuples are immutable identity rows — no "update" needed, only create/delete
- Re-link LAT→tuples runs every sync (idempotent)
- 1453 tests, 0 failures
