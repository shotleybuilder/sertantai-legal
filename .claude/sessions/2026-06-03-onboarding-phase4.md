# Title: Customer Onboarding Phase 4 — Sync to Baserow

**Started**: 2026-06-03 00:30
**Meta-plan**: .claude/plans/customer-onboarding.md (Phase 4, excluding 4.5)

## Todo
- [x] 4.1 — QinetiQ org in auth, user linked as owner — c075d56b
- [x] 4.2 — Entitlement: 32 families, lrt_lat, standard — d72b5c2a
- [x] 4.3 — Sync profile (QQ Legal Register) + Baserow JWT config — 2b98afa
- [x] 4.4 — Initial sync: 106 L3 laws in Baserow, verified in UI — 2b98afa

## Housekeeping
- [ ] Fix complete_job — Ash.update return not propagating, job stays :running
- [ ] Rename Baserow table from default "Table" to "Legal Register" via API
- [ ] Clean Baserow table before sync — delete default empty rows + dummy columns (Notes, Active)
- [ ] Goal: customer just creates the DB, we handle the rest

## Notes
- Baserow database tokens can't create fields — switched to JWT auth (email/password)
- Engine fixes: Ash Query/Changeset API, UUID binary handling, NaiveDateTime checkpoint
- Applicability records migrated from test UUID to real org ID
- Auth on port 4000, DB on port 5438
