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
- [x] Build claude skill: `lrt-create-session`
- [x] Build claude skill: `db-schema-changes`
- [x] New zenoh signature from fractalaw — no code change needed (upsert handles partial publishes)
- [x] Complete LRT parse session — cleaned 70 -> 23 records, all parsed and confirmed
- [x] Fix: DRRP vocab conversion (Obligation/Liberty -> Duty/Right/Responsibility/Power)
- [x] Fix: making_detector tier 0 EU signals crash (reason/signal key mismatch)
- [x] Fix: staged_parser title_en overwrite (XML value replaces dirty session title)
- [x] Fix: significance_parts column type mismatch (jsonb -> jsonb[] migration)
- [x] Admin layout full-width (remove max-w-7xl)
- [ ] Data repair: re-derive duty_type for 189+ laws with Obligation/Liberty vocab
- [ ] Parse LAT for new QQ laws missing LAT
- [ ] Update Baserow with new QQ register state

## Notes
- QQ register: 334 -> 488 laws (154 added)
- Root cause: Enhesa coding errors (type_code wrong, S.I. ref as number, year as number)
- Key pattern: Acts coded as `uksi` with S.I. ref instead of `ukpga`/`asc`/`asp` with chapter number
- Scrape session: started 70 records, cleaned to 23 (47 removed — already in LRT or bad creds)
- DRRP bug: fractalaw sends Obligation/Liberty in duty_type but structured entries in correct DRRP columns; fix derives duty_type from entries
- significance_parts: Ash schema was {:array, :map} (jsonb[]) but DB column was jsonb; migration 20260708000001 fixed column to jsonb[]
- Bug filed: #114 — `asc` type code missing from monthly scrape `@type_codes`
- Skills created: `lrt-create-session`, `db-schema-changes`
- CSVs: `backend/data/qq/legal-register-uk-{unmatched,in-lrt,not-in-lrt,fixable,not-found,resolved}.csv`
