# Title: Phase 1.5 — Frontend Generalisation

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo

### Electric/PGlite — move country handling from proxy to frontend
- [x] Add `country` to `UK_LRT_ALL_COLUMNS` and `UK_LRT_ADMIN_COLUMNS` in `sync.ts`
- [x] Update `syncShapeToTable` to request `table: 'legal_register_uk'` directly
- [x] Remove proxy table rewrite (`@table_rewrites`) from `ElectricProxyController`
- [x] Remove proxy PK injection (`@extra_pk_columns`) from `ElectricProxyController`
- [x] Update Electric proxy allowed/public table lists → `legal_register_uk`, `legal_articles_uk`
- [x] Update Electric proxy tests (33 pass)

### API calls — switch to new routes
- [x] Update `authFetch` calls from `/api/uk-lrt/` → `/api/laws/` (8 refs in 6 files)
- [x] No `country=uk` param needed yet — all queries return all countries (only UK exists)

### Types and naming
- [x] Add `country` + `source_url` fields to `UkLrtRecord` type, keep `leg_gov_uk_url` as alias
- [x] Update column metadata (`uk-lrt-columns.ts`) — added `country`
- [x] Add `source_url` to sync column list and PGlite schema (v15)
- [x] Update schema test with new fields
- [x] Type rename to `LegalRecord` deferred — too many imports to touch, no value until Phase 2

### Verify
- [x] All 131 frontend tests pass
- [x] All 1,211 backend tests pass
- [x] Frontend syncs and displays correctly (hard refresh needed for schema v15)

## Notes
- Country selector/filter UI deferred to Phase 2 (no second country yet)
- External link generalisation deferred (legislation.gov.uk hardcoded OK for now)
- Focus: remove proxy workarounds, point frontend at real table names and new API routes

**Ended**: 2026-05-18
**Commits**: `bf66e70`
