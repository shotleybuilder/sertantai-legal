# Title: Reconcile QQ Legal Register with New Import

**Started**: 2026-07-08 15:02

## Todo
- [x] Compare CSV import against QQ legal register (334 laws)
- [x] Resolve 46 x-candidates by title matching
- [x] Split unmatched into in-LRT (476) and not-in-LRT (156)
- [x] Diagnose 156 not-in-LRT: 75 fixable coding errors, 81 genuinely missing
- [x] Create scrape session `import-qq-uk-not-in-lrt-2026-07-08` for 81 missing
- [x] Resolve x-numbers via legislation.gov.uk lookups (agent)
- [x] Fix wrongly persisted records (Equality Act, Building Scotland, Building Safety, Marine Coastal, Historic Environment)
- [x] Add 3 major Acts to QQ register (Marine Coastal, Building Safety, Historic Environment Wales)
- [x] Systematic check: all site CSVs against QQ register
- [x] Add 119 + 2 + 30 laws from site CSVs to QQ register (334 -> 488)
- [x] Build claude skill: `lrt-create-session` (capture learnings from this session)
- [x] New zenoh signature from fractalaw — no code change needed (upsert handles partial publishes)
- [x] Complete LRT parse session `import-qq-uk-not-in-lrt-2026-07-08` — 23 confirmed, 0 pending
- [ ] Parse LAT for new QQ laws missing LAT
- [ ] Update Baserow with new QQ register state

## Notes
- QQ register: 334 -> 488 laws (154 added)
- Root cause: Enhesa coding errors (type_code wrong, S.I. ref as number, year as number)
- Key pattern: Acts coded as `uksi` with S.I. ref instead of `ukpga`/`asc`/`asp` with chapter number
- Scrape session: started 70 records, cleaned down to 23 (47 removed — already in LRT or bad creds)
- CSVs written: `backend/data/qq/legal-register-uk-{unmatched,in-lrt,not-in-lrt,fixable,not-found,resolved}.csv`
- Bug fix: `staged_parser.ex` — title_en now replaced by XML value when different (was protected)
- Bug fix: `making_detector.ex` — tier 0 EU signals used `reason` not `signal` key
- Bug filed: #114 — `asc` type code missing from monthly scrape `@type_codes`
