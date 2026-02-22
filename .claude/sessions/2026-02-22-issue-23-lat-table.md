# Issue #23: Build legislation_text (LAT) table

**Started**: 2026-02-22
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/23

## Todo
- [x] Phase 1: Ash resource + migration for `lat` table (31 cols) — `9266349`
- [x] Phase 2: CSV import pipeline — 95,854 rows from 443 laws imported
- [ ] Phase 3: New law parser (replaces legacy `~/Desktop/legl/legl`)
- [ ] Phase 4: Amendment annotations table
- [ ] Phase 5: AI sync endpoint
- [ ] Phase 6: ElectricSQL sync

## Notes
- Table name: `lat` (Legal Articles Table)
- Schema docs: `docs/LAT-SCHEMA-FOR-SERTANTAI.md`, `docs/LAT-SCHEMA-CONTEXT.md`
- Transform reference: `docs/LAT-TRANSFORMS-FOR-SERTANTAI.md` — 16 transforms from Airtable CSV → new schema
- PK: `section_id` (citation-based text PK, not UUID)
- FK: `law_id` UUID → `uk_lrt.id`, plus denormalised `law_name`
- UK CSV source: `~/Documents/Airtable_Exports/` (Airtable exports), also `~/Downloads/Articles-📦 BASIC.csv` (46K rows, consolidated)
- CSVs use legacy Airtable schema (different column names, acronym-laden IDs) — needs full transform pipeline
- Non-UK CSVs: `~/Downloads/Articles-*.csv` (15 files, deferred)
- Existing parser: `~/Desktop/legl/legl`
- Exclude `UK_uksi_2016_1091` (broken annotations)
- This is a phased session — each phase gets its own commit(s)

### Phase 2: CSV Import Pipeline
- Files created:
  - `backend/lib/sertantai_legal/legal/lat/transforms.ex` — 16-step pure transform pipeline
  - `backend/test/sertantai_legal/legal/lat/transforms_test.exs` — 87 unit tests
  - `scripts/data/import_lat_from_csv.exs` — import script (--dry-run, --limit, --file flags)
- Import stats: 115,073 CSV rows → 95,854 content rows inserted, 15,960 annotations filtered, 1,320 excluded
- 443 laws matched, 10 unmatched (pre-1900 non-standard IDs)
- All 15 section_types populated, parallel provisions working, 0 errors
- Data dump: `~/Desktop/sertantai-data/lat_data.sql` (66MB)
- Tests: 899 pass, 0 failures (87 new transforms tests)

### Phase 3: New Law Parser — Context
- **Goal**: Parse legislation.gov.uk XML into LAT rows, combined with Taxa in a single pass
- **Current workflow**: Scraper fetches law → Taxa parser runs → if Taxa confirms "making" (sets duties/responsibilities) → **scrapes AND parses again** for full text. Two scrapes, two parses — doubly wasteful.
- **New workflow**: Single pass — parse law structure into LAT rows, run Taxa on content, persist LAT rows only if Taxa confirms the law is "making"
- **Approach**: Write new parser from scratch targeting the new LAT schema. Legacy parser (`~/Desktop/legl/legl`) generated the migrated data but is Elixir-legacy and tightly coupled to old schema. Study what it does, then build clean.
- **Legacy parser location**: `~/Desktop/legl/legl` — understand its approach but don't port it
- **Existing scraper in this project**: `backend/lib/sertantai_legal/scraper/` — already fetches metadata, legislation XML, handles sessions/groups
- **Reuse**: `transforms.ex` functions (citation building, sort_key, hierarchy, etc.) apply to both CSV import and live parsing
- **Key insight**: Taxa parsing already requires full law content — combining LAT persistence with Taxa avoids double-parsing
