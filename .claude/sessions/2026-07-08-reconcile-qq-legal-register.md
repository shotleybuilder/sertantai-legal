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
- [x] Build claude skills: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- [x] New zenoh signature from fractalaw — no code change needed (upsert handles partial publishes)
- [x] Complete LRT parse session — cleaned 70 -> 23 records, all parsed and confirmed
- [x] Fix: DRRP vocab conversion (Obligation/Liberty -> Duty/Right/Responsibility/Power)
- [x] Fix: making_detector tier 0 EU signals crash (reason/signal key mismatch)
- [x] Fix: staged_parser title_en overwrite (XML value replaces dirty session title)
- [x] Fix: significance_parts column type mismatch (jsonb -> jsonb[] migration)
- [x] Fix: persister filter_update_attrs blocking live status updates
- [x] Fix: persister always_update_fields for all relationship/amendment data
- [x] Admin layout full-width (remove max-w-7xl)
- [x] Organizations table + Zenoh customer discovery queryable
- [x] Customer laws queryable includes live status
- [x] LAT session UI shows live status column
- [x] Postgrex timeout bumped 60s -> 120s for large Acts
- [x] Audit 50 revoked QQ laws — 5 restored to Part Revoked (false positives from old persister)
- [x] Cleaned revoked law LAT (4,600+ rows deleted)
- [x] LAT parse session built: `lat-parse-qq-missing-2026-07-09` (109 records)
- [x] NAS snapshot exported
- [ ] Data repair: re-derive duty_type for 189+ laws with Obligation/Liberty vocab
- [ ] Parse remaining LAT session records (109 pending)
- [ ] Large Act LAT persistence (#115 — Companies Act, Comms Act, T&CP Act)
- [ ] Update Baserow with new QQ register state

## Notes
- QQ register: 334 -> 488 laws (154 added)
- Root cause: Enhesa coding errors (type_code wrong, S.I. ref as number, year as number)
- Key pattern: Acts coded as `uksi` with S.I. ref instead of `ukpga`/`asc`/`asp` with chapter number
- Scrape session: started 70 records, cleaned to 23 (47 removed — already in LRT or bad creds)
- DRRP bug: fractalaw sends Obligation/Liberty in duty_type but structured entries in correct DRRP columns; fix derives duty_type from entries
- Live status bug: persister's filter_update_attrs blocked live updates on existing records; 5 laws falsely marked revoked
- Persister fix: @always_update_fields now includes live, relationships, dates, stats — identity fields still protected
- significance_parts: Ash schema was {:array, :map} (jsonb[]) but DB column was jsonb; migration 20260708000001 fixed
- Large Act timeout: Postgrex 60s timeout too short for Companies Act (97s), bumped to 120s; #115 raised for proper fix
- Bug filed: #114 — `asc` type code missing from monthly scrape `@type_codes`
- Bug filed: #115 — Large Act LAT persistence optimisation
- Skills created: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- CSVs: `backend/data/qq/legal-register-uk-{unmatched,in-lrt,not-in-lrt,fixable,not-found,resolved}.csv`
