# Title: P2P zenoh - publish LRT/LAT/amendments to fractalaw

**Started**: 2026-02-26
**Commit**: 4b73387 (pushed to main)

## Todo
- [x] Add zenohex v0.7.2 dependency
- [x] Add config (dev: enabled, test: disabled, runtime: env var overrides)
- [x] Create Zenoh.Session GenServer (peer mode, retry logic)
- [x] Create Zenoh.DataServer (queryables for LRT, LAT, AmendmentAnnotation)
- [x] Create Zenoh.ChangeNotifier (pub/sub for data-changed events)
- [x] Create Zenoh.Supervisor (rest_for_one)
- [x] Wire into application.ex (conditional on :zenoh :enabled)
- [x] Fix dialyzer error (declare_queryable has no error return)
- [x] Update infrastructure .env.example with SERTANTAI_LEGAL_ZENOH_* vars
- [x] Push to main (all checks pass: compile, credo, dialyzer, 1110 tests)
- [ ] Live test with fractalaw querying the key expressions

## Notes
- New files: `backend/lib/sertantai_legal/zenoh/{supervisor,session,data_server,change_notifier}.ex`
- Key expressions: `fractalaw/@{tenant}/data/legislation/{lrt,lrt/*,lat/*,amendments/*}` + `events/data-changed`
- Env vars: `SERTANTAI_LEGAL_ZENOH_ENABLED`, `_TENANT`, `_CONNECT` (also short `ZENOH_*` for local dev)
- Infrastructure `.env.example` updated at `~/Desktop/infrastructure/docker/.env.example`
- Security issue: #28 (mTLS + ACL before production)
- Spec for fractalaw: `docs/ZENOH-SPEC.md`
- Skill: `.claude/skills/zenoh-p2p-publishing/SKILL.md`

**Ended**: 2026-02-26
