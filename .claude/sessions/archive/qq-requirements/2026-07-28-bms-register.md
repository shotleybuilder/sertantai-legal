---
session: BMS Register — Pre-Enhesa Site×Law Mappings
project: sertantai-legal
status: closed
opened: 2026-07-28
closed: 2026-07-28
outcome: success
commits: [61e8913]

summary: >
  Ingested QQ's pre-Enhesa BMS "UK Legislation Assurance Register" (21 sites, 361 laws)
  into sertantai. Matched 305 laws to uk_lrt, scraped 19 missing, added 223 BMS-only laws
  to QQ's org_applicabilities, built site×law matrix in SQLite, and synced 651 laws + 268
  hierarchy links to Baserow. Fixed a scraper bug where DB-backed session records lost type_code.

decisions:
  - what: New SQLite table bms_site_applicability rather than synthetic requirement rows
    why: BMS data is site×law only (no requirement text). Forcing it into the Enhesa requirements→lrt→site schema would create empty requirements. Separate table preserves both models cleanly.
    result: 3,999 rows, queryable alongside Enhesa data in same SQLite

  - what: Insert skeleton records into legal_register before creating scrape session
    why: mix lrt.create_session validates against legal_register. Laws not yet scraped need skeleton rows (name, type_code, year, number) first. Scraping via admin UI then populates metadata.
    result: 12 inserted, 3 already existed as skeletons. All 15 scraped successfully.

  - what: Tag BMS org_applicabilities with source=bms_import
    why: Need to distinguish BMS-sourced applicability from Enhesa-sourced for QA and audit. Source field already exists on org_applicabilities.
    result: 223 rows tagged, queryable by source

metrics:
  bms_entries: 361
  exact_matches: 305
  close_matches: 18
  fuzzy_matches: 27
  no_match: 11
  laws_scraped: 19
  bms_only_laws_added: 223
  qq_org_applicabilities_total: 711
  site_law_pairs: 3999
  baserow_lrt_total: 651
  baserow_hierarchy_updated: 268

lessons:
  - title: session_record_to_map must decompose law_name for StagedParser — DB-backed records lack type_code/Year/Number
    detail: >
      Records created via `mix lrt.create_session` are stored in scrape_session_records with
      only law_name. When `find_record_in_session` returns these to StagedParser.parse, type_code/Year/Number
      are nil, producing names like "UK__2019_17". The fix is decompose_law_name in storage.ex.
      JSON-backed records (from the scraper UI) don't hit this because the categorizer populates
      all fields. Only affects the DB→StagedParser path.
    tag: tooling

  - title: BMS site codes don't match Baserow hierarchy node names — verify against the Hierarchy table
    detail: >
      Ashford=QTS (not ASH), Rosneath=ROS (not HRN, which is Hurn), Malvern=MLV (not MAN,
      which is RAF Manorbier). The BMS CSV filenames are site names, not codes. The mapping
      must come from the Hierarchy table, not guessed from abbreviations.
    tag: data

  - title: baserow.hierarchy_apply_laws replaces rather than merges hierarchy links
    detail: >
      The task builds `%{"Hierarchy" => [ids]}` which replaces the full link_row field.
      Safe when starting from 0 links, but will wipe existing links if both BMS and Enhesa
      data apply. Needs a --merge mode that reads existing links first. Filed as known issue.
    tag: baserow

  - title: SequenceMatcher fuzzy matching at 0.85 threshold catches ~85% of BMS→LRT matches on first pass
    detail: >
      BMS register uses informal/shortened law titles. Python's difflib.SequenceMatcher with
      year filtering and 0.85 threshold matched 305/361 (84.5%) on first pass. The remaining
      needed manual resolution (fuzzy mismatches, composite entries, missing laws). Worth
      investing in the manual resolution — the 27 fuzzy matches were mostly wrong.
    tag: tooling

  - title: Pre-Enhesa registers cover defence domains (ordnance, maritime, aviation) that commercial vendors miss
    detail: >
      212 BMS-only laws not in Enhesa, heavily weighted to FIREARMS, MARITIME, ORDNANCE,
      AVIATION, RADIATION. These are QQ-specific as a defence contractor. Commercial EHS
      vendors don't cover weapons law, military maritime, or nuclear/radiological regulations.
      This gap is structural, not a vendor quality issue.
    tag: data

artifacts:
  - backend/scripts/qq/match_bms_xindex.py
  - backend/scripts/qq/build_site_law_matrix.py
  - backend/data/imports/qq/bms_law_hierarchy_mappings.csv
  - backend/data/qq/Extracted csv/outputs/bms_xindex_matches.json
  - backend/data/qq/Extracted csv/outputs/bms_site_law_matrix.csv
  - backend/data/qq/Extracted csv/outputs/bms_vs_enhesa_by_site.json
  - backend/lib/sertantai_legal/scraper/storage.ex
  - backend/test/sertantai_legal/scraper/storage_test.exs

depends_on:
  - qq-requirements/2026-07-22-qq-requirements-mapping.md
  - qq-requirements/2026-07-22-unmatched-triage.md
  - baserow/2026-07-21-hierarchy-models.md

enables:
  - Refactor skill QA bash chains into mix tasks (#130)
  - Site-level compliance dashboards in Baserow (filter LRT by hierarchy node)
---

# BMS Register — Pre-Enhesa Site×Law Mappings

**Started**: 2026-07-28
**Context**: QQ's own "UK Legislation Assurance Register" — per-site CSVs predating Enhesa

## Source Data
- `backend/data/qq/Extracted csv/` — 21 site CSVs + 1 xIndex
- ~379 unique laws across ~21 sites, categorised (ENVIRONMENT, AVIATION, etc.)
- Format: Category, Law Title, Year, applicability flag per site

## Todo
- [x] Parse xIndex into canonical law list (category + title + year)
- [x] Match BMS laws → sertantai uk_lrt (type_code+year+number)
- [x] Identify gaps: laws in BMS not in sertantai or QQ corpus
- [x] Scrape session created: `bms-missing-2026-07-28` (15+4 laws)
- [x] Scraped via admin UI — all 19 laws now have metadata
- [x] Family assignments corrected for all 15 original + 4 rescrapes
- [x] Match BMS laws → QQ corpus (org_applicabilities)
- [x] Add 223 BMS-only laws to QQ org_applicabilities (source: bms_import)
- [x] Fix NI mis-match: UK_nisr_1998_422 → UK_uksi_2004_2516
- [x] Fix scraper bug: session_record_to_map missing type_code/Year/Number (61e8913)
- [x] Parse site CSVs to build site×law matrix (3,999 rows, 21 sites)
- [x] SQLite `bms_site_applicability` table populated (3,665 matched, 334 unmatched)
- [x] BMS vs Enhesa per-site comparison: 1,182 overlap, 2,394 BMS-only, 2,849 Enhesa-only
- [x] Baserow sync: 223 new LRT rows created, 428 updated (651 total)
- [x] Hierarchy apply: 266 + 134 (QTS/Ashford) = 400 LRT rows linked to BMS sites

## Scripts (reusable)

| Script | Purpose | Usage |
|--------|---------|-------|
| `backend/scripts/qq/match_bms_xindex.py` | Match BMS xIndex titles → uk_lrt by fuzzy title+year | `/usr/bin/python3 backend/scripts/qq/match_bms_xindex.py` |
| `backend/scripts/qq/build_site_law_matrix.py` | Parse site CSVs, build matrix, cross-ref SQLite, export CSV | `/usr/bin/python3 backend/scripts/qq/build_site_law_matrix.py` |

## Output Files

| File | Content |
|------|---------|
| `backend/data/qq/Extracted csv/outputs/bms_xindex_matches.json` | Full match results (361 entries) |
| `backend/data/qq/Extracted csv/outputs/bms_xindex_review.csv` | Non-exact matches for human review |
| `backend/data/qq/Extracted csv/outputs/bms_xindex_analysis.md` | Match analysis with manual corrections |
| `backend/data/qq/Extracted csv/outputs/bms_missing_laws.txt` | 15 law names for scrape session |
| `backend/data/qq/Extracted csv/outputs/bms_site_law_matrix.csv` | Full site×law grid (Y/blank) |
| `backend/data/qq/Extracted csv/outputs/bms_vs_enhesa_by_site.json` | Per-site BMS vs Enhesa comparison |
| `backend/data/qq/Extracted csv/outputs/bms_only_laws_by_site.csv` | BMS-only laws per site with category |
| `backend/data/imports/qq/bms_law_hierarchy_mappings.csv` | hierarchy_node,lrt_name for Baserow apply |

## Reproduction Steps

### 1. xIndex matching
```bash
/usr/bin/python3 backend/scripts/qq/match_bms_xindex.py
# Outputs: bms_xindex_matches.json, bms_xindex_review.csv
# Requires: PostgreSQL on port 5436, psycopg2
```

### 2. Scrape missing laws
```bash
cd backend
# Insert skeleton records for laws not in legal_register (see SQL in analysis)
mix lrt.create_session --name bms-missing-YYYY-MM-DD \
  --laws UK_ukpga_2015_6,UK_ukpga_1990_18,...  # see bms_missing_laws.txt
# Then scrape via admin UI at /admin/scraper
# Then manually assign families for unclassified laws
```

### 3. Add to QQ org_applicabilities
```sql
-- Insert BMS-only laws (those not already in org_applicabilities)
INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, notes, inserted_at, updated_at)
SELECT gen_random_uuid(), 'c075d56b-8420-4408-b695-ccfbc1ba15ec', b.name,
  'yes', 'bms_import', 'Pre-Enhesa BMS UK Legislation Assurance Register', NOW(), NOW()
FROM bms_laws b  -- temp table from match results
WHERE NOT EXISTS (SELECT 1 FROM org_applicabilities oa WHERE oa.law_name = b.name AND oa.organization_id = '...');
```

### 4. Site×law matrix + SQLite
```bash
/usr/bin/python3 backend/scripts/qq/build_site_law_matrix.py
# Creates bms_site_applicability table in qq_mapping.db
# Outputs: bms_site_law_matrix.csv, bms_vs_enhesa_by_site.json, bms_only_laws_by_site.csv
```

### 5. Baserow sync
```bash
cd backend
mix sync.run --direct                          # Push new LRT rows
mix baserow.hierarchy_apply_laws \
  --csv data/imports/qq/bms_law_hierarchy_mappings.csv  # Link laws to sites
```

## Results — xIndex Matching
- 361 unique BMS entries → 305 exact, 18 close, 27 fuzzy, 11 no-match
- 69 revoked laws (21%) — register unmaintained since pre-Enhesa
- ~25 laws genuinely not in sertantai (15 domestic, 10 WT subsidiary, 2 intl conventions, 2 EU)

## Results — QQ Corpus Cross-Reference
- BMS 330 matched laws vs QQ 488 Enhesa laws → 107 overlap, 223 BMS-only, 381 QQ-only
- 223 BMS-only added to org_applicabilities (source: `bms_import`, status: `yes`)
- QQ org_applicabilities now: 428 enhesa yes + 60 enhesa no + 223 bms = 711 total

## Results — Site×Law Matrix
- 3,999 BMS site×law rows across 21 sites (3,665 matched to uk_lrt)
- BMS vs Enhesa overlap: 1,182 pairs; BMS-only: 2,394; Enhesa-only: 2,849
- 212 unique BMS-only laws, 66 at all 21 sites, 55 site-specific (1-4 sites)

## Results — Baserow
- LRT: 223 created + 428 updated = 651 total in Legal Register
- Hierarchy: 400 LRT rows linked to BMS site nodes

## Bug Fix — Scraper session_record_to_map (commit 61e8913)
- `storage.ex:session_record_to_map` didn't decompose law_name into type_code/Year/Number
- StagedParser got nil type_code → built names like `UK__2019_17`
- Fix: added `decompose_law_name/2` + test in `storage_test.exs`
- Affects: any session created via `mix lrt.create_session` (DB-backed records)

## Known Issues
- `baserow.hierarchy_apply_laws` **replaces** hierarchy links (doesn't merge with existing). Safe when rows have 0 existing links, but will wipe Enhesa links if both sources apply to the same law. Task needs a `--merge` mode.
- 334 BMS entries unmatched to uk_lrt (Wireless Telegraphy subsidiaries, COLREGS, SOLAS, GDPR, REACH) — intentionally excluded as non-domestic or outside LRT scope
- 3 BMS laws skipped in hierarchy apply — likely fuzzy match mismatches from xIndex

## Notes
- Follows on from `2026-07-22-qq-requirements-mapping.md` and `2026-07-22-unmatched-triage.md`
- LEGAL & GOVERNANCE weakest category — LRT stronger on H&S/environment
- BMS covers defence/military domains (ordnance, maritime, aviation) Enhesa doesn't reach
- Ashford uses QTS hierarchy node (not ASH) — corrected in SQLite and scripts
