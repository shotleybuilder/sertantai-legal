# Issue #23: Build legislation_text (LAT) table

**Started**: 2026-02-22
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/23

## Todo
- [x] Phase 1: Ash resource + migration for `lat` table (31 cols) — `9266349`
- [x] Phase 2: CSV import pipeline — 95,854 rows from 443 laws imported — `2d4e0d5`
- [x] Phase 3: New law parser (replaces legacy `~/Desktop/legl/legl`) — `26ae99f`
- [x] Phase 4: Amendment annotations table — 13,329 rows from 117 laws — `aa27c61`
- [x] Phase 4b: CommentaryParser — extract annotations from body XML — `7d5bf59`
- [x] Phase 5: AI sync endpoints (LAT + annotations) — `7f6cae8`
- [x] Phase 6: ElectricSQL sync for LAT + annotations — `1fe2e4a`

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

### Phase 3: New Law Parser
- **Goal**: Parse legislation.gov.uk XML into LAT rows, combined with Taxa in a single pass
- **Previous workflow**: Scraper fetches law → Taxa parser runs → if Taxa confirms "making" → scrapes AND parses again for full text. Two scrapes, two parses.
- **New workflow**: Single pass — parse law structure into LAT rows, run Taxa on content, persist LAT rows only if Taxa confirms the law is "making"
- Files created:
  - `backend/lib/sertantai_legal/scraper/lat_parser.ex` — 589-line XML→LAT parser (Acts, SIs, schedules, parallel extents, amendments)
  - `backend/lib/sertantai_legal/scraper/lat_persister.ex` — batch upsert with conflict resolution on section_id
  - `backend/test/sertantai_legal/scraper/lat_parser_test.exs` — 428-line test suite
  - `backend/test/fixtures/body_xml/` — 4 XML fixtures (simple_act, simple_si, with_schedules, parallel_extents)
- Files modified:
  - `backend/lib/sertantai_legal/scraper/staged_parser.ex` — integrated LAT+Taxa combined pipeline
  - `backend/lib/sertantai_legal/scraper/taxa_parser.ex` — refactored for single-pass reuse
- Reuses `transforms.ex` functions (citation building, sort_key, hierarchy) for both CSV import and live parsing

### Phase 4: Amendment Annotations Table
- **Goal**: Import amendment footnotes (F-codes) from Airtable CSV exports, linking to LAT sections
- Source: 17 `*-Amendments-EXPORT.csv` files in `~/Documents/Airtable_Exports/` (14,302 rows, all F-codes)
- 3 CSV header variants handled (UK column, UK (from Articles) column, no UK column)
- Files created:
  - `backend/lib/sertantai_legal/legal/amendment_annotation.ex` — Ash resource (text PK, FK to uk_lrt)
  - `backend/lib/sertantai_legal/legal/amendment_annotation/code_type.ex` — Ash.Type.Enum (amendment, modification, commencement, extent_editorial)
  - `backend/lib/sertantai_legal/legal/amendment_annotation/transforms.ex` — pure transform functions
  - `backend/test/sertantai_legal/legal/amendment_annotation/transforms_test.exs` — 36 tests
  - `scripts/data/import_amendment_annotations_from_csv.exs` — import script (gitignored)
  - `backend/priv/repo/migrations/20260222180417_add_amendment_annotations.exs`
- Files modified:
  - `backend/lib/sertantai_legal/api.ex` — registered AmendmentAnnotation resource
- Import stats: 14,302 CSV rows → 13,329 inserted, 6 pre-1900 laws skipped (973 rows), 0 errors
- Section resolution: 13,170 legacy_id → section_id resolved, 835 unresolved (kept as `legacy:` prefix)
- 12,291 annotations have affected_sections, 1,038 have none (annotation not linked to specific sections)
- Data dump: `~/Desktop/sertantai-data/amendment_annotations_data.sql` (3.9MB)
- Tests: 988 pass, 0 failures (36 new transforms tests)

### Phase 4b: CommentaryParser (body XML → annotations)
- **Goal**: Extend LAT parser pipeline to extract `<Commentaries>` block from body XML and persist to amendment_annotations — completing single-pass: one body XML fetch → LAT rows + annotations
- Commentary@Type mapping: F→amendment, C/M→modification, I→commencement, E/X→extent_editorial
- Commentary@id is internal key (e.g., `key-abc123`), not sequential F1/F2 codes
- CommentaryRef@Ref in body sections maps annotations to LAT section_ids
- Files created:
  - `backend/lib/sertantai_legal/scraper/commentary_parser.ex` — parses Commentaries block, builds ref→section mapping, assigns sequential IDs
  - `backend/lib/sertantai_legal/scraper/commentary_persister.ex` — DELETE+INSERT per law (source='lat_parser' only, preserves CSV imports)
  - `backend/test/sertantai_legal/scraper/commentary_parser_test.exs` — 22 tests
- Files modified:
  - `backend/lib/sertantai_legal/scraper/lat_parser.ex` — `collect_commentary_refs/1` returns raw ref IDs per row (new `commentary_refs` field)
  - `backend/lib/sertantai_legal/scraper/staged_parser.ex` — `maybe_run_commentary_substage` called after LAT persistence
  - `backend/test/fixtures/body_xml/simple_act.xml` — added Commentaries block (F/C/I types) + CommentaryRef pointers
  - `backend/test/sertantai_legal/scraper/lat_parser_test.exs` — 4 new tests for commentary_refs field
- Tests: 1014 pass, 0 failures (26 new tests)

### Phase 5: AI Sync Endpoints
- **Goal**: Pull-based incremental sync for AI service (LanceDB/embeddings) — 1-way, AI service polls our endpoints
- Endpoints: `GET /api/ai/sync/lat`, `GET /api/ai/sync/annotations`
- Auth: `X-API-Key` header (same `:api_ai` pipeline as DRRP clause queue)
- Sync strategy: `?since=<ISO8601>` timestamp filter (default 30 days), `?law_name=` for targeted re-sync
- Pagination: limit/offset (max 2000), standard envelope with `sync_timestamp` for cursor tracking
- LAT response denormalizes `law_title`, `law_type_code`, `law_year` from uk_lrt; excludes embedding/token fields
- Files created:
  - `backend/lib/sertantai_legal_web/controllers/ai_sync_controller.ex` — two actions, raw SQL with uk_lrt JOIN
  - `backend/test/sertantai_legal_web/controllers/ai_sync_controller_test.exs` — 23 tests
  - `.claude/skills/endpoint-api-ai-sync-lat-annotations/SKILL.md` — endpoint skill documentation
- Files modified:
  - `backend/lib/sertantai_legal_web/router.ex` — 2 routes added to `:api_ai` scope
- Tests: 1037 pass, 0 failures (23 new tests)

### Phase 6: ElectricSQL Sync for LAT & Annotations
- **Goal**: Enable real-time sync of LAT and amendment_annotations to frontend via ElectricSQL
- Migration: `REPLICA IDENTITY FULL` for `amendment_annotations` (LAT already had it)
- Backend: Added `lat` + `amendment_annotations` to electric proxy controller `@allowed_tables`
- Frontend schemas: `lat-schema.ts` (27 cols, excludes embedding/token), `annotation-schema.ts` (10 cols)
- Frontend collections: per-law shape subscriptions via `getLatCollection(lawName)` and `getAnnotationCollection(lawName)`
- Both collections include shape recovery (400→DELETE+retry) and auth redirect (401→hub)
- All 3 synced tables confirmed `REPLICA IDENTITY FULL`: uk_lrt, lat, amendment_annotations
- Tests: 1037 backend + 95 frontend, 0 failures

**Ended**: 2026-02-22
