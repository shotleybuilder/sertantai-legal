# Title: Reconcile QQ Legal Register with New Import

**Started**: 2026-07-08 15:02

## Todo
- [x] Compare CSV import against QQ legal register (334 laws)
- [x] Resolve 46 x-candidates by title matching
- [x] Split unmatched into in-LRT (476) and not-in-LRT (156)
- [x] Diagnose 156 not-in-LRT: 75 fixable coding errors, 81 genuinely missing
- [x] Create scrape session `import-qq-uk-not-in-lrt-2026-07-08` for 81 missing
- [x] Resolve x-numbers via legislation.gov.uk lookups (agent)
- [x] Fix wrongly persisted records (Equality Act, Building Scotland, etc.)
- [x] Add 3 major Acts to QQ register (Marine Coastal, Building Safety, Historic Environment Wales)
- [x] Systematic check: all site CSVs against QQ register
- [x] Add 119 + 2 + 30 laws from site CSVs to QQ register (334 -> 488)
- [x] Build claude skills: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- [x] New zenoh signature from fractalaw — no code change needed
- [x] Complete LRT parse session — cleaned 70 -> 23 records, all parsed
- [x] Fix: DRRP vocab conversion (Obligation/Liberty -> Duty/Right/Responsibility/Power)
- [x] Fix: convert_duty_type fallback to record's existing entries
- [x] Fix: making_detector tier 0 EU signals crash
- [x] Fix: staged_parser title_en overwrite
- [x] Fix: significance_parts column type mismatch (migration)
- [x] Fix: persister filter_update_attrs blocking live/relationship updates
- [x] Fix: delta_detector NaiveDateTime vs DateTime comparison crash
- [x] Admin layout full-width
- [x] Organizations table + Zenoh customer discovery queryable
- [x] Customer laws queryable includes live status
- [x] LAT session UI shows live status column
- [x] Postgrex timeout 60s -> 120s; LAT persister dynamic timeout + batch 500->2000
- [x] Audit 50 revoked QQ laws — 5 restored to Part Revoked
- [x] Cleaned revoked law LAT (4,600+ rows deleted)
- [x] LAT parse session: `lat-parse-qq-missing-2026-07-09` (109 records parsed)
- [x] Data repair: fractalaw republished 364 laws, 0 remaining with stale Obligation/Liberty vocab
- [x] NAS snapshot exported (x2)
- [x] Baserow sync: 428 LRT, 2564 duties, 27 actor tuples (incremental delta)

## Done
- [ ] Large Act LAT persistence (#115 — Companies Act, Comms Act timeout even with fix)
- [ ] 8 QQ laws still missing LAT (4 EU directives, 2 UK SIs non-making, 2 large Acts)

## Notes
- QQ register: 334 -> 488 laws (154 added)
- Enhesa coding errors: type_code wrong, S.I. ref as number, year as number
- DRRP bug: fractalaw sends Obligation/Liberty; fix derives duty_type from structured entries + record fallback
- Live status bug: persister blocked updates on existing records; @always_update_fields for live, relationships, stats
- Delta detector: NaiveDateTime from DB vs DateTime from mappings; added conversion clauses
- Bugs filed: #114 (asc type_code missing), #115 (large Act LAT persistence)
- Skills created: `lrt-create-session`, `db-schema-changes`, `lat-session-build`
- Baserow sync: incremental delta — 154 new LRT, 181 new duties, 2383 updated, 17 deleted
