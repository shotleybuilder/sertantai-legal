# Data Sync Phase 3: Snapshot Rotation + Prod Deploy

**Started**: 2026-04-11
**Plan**: `.claude/plans/DATA-SYNC.md` — Phase 3 + prod deploy carry-over

## Todo
- [x] Catch up prod migrations — deployed via `/deploy`, migrations ran automatically
- [ ] First delta export + apply to prod
- [ ] Post-promotion hook: auto-generate new NAS snapshot after successful prod sync
- [ ] Archive previous snapshot with timestamp
- [ ] Add snapshot age check to `sert-legal-start` — warn if snapshot is >7 days old

## Notes
- Prod deploy carried over from Phase 2 session
- Need SSH tunnel to prod PostgreSQL for migration + delta apply
