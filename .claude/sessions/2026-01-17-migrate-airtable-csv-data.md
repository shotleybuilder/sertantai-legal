# Title: migrate-airtable-csv-data

**Started**: 2026-01-17
**Issue**: None

## Context
Migrate missing data from Airtable export CSV into dev database. Reference LRT-SCHEMA.md for columns with "No" or "Minimal" data.

## Completed

### Metadata Migration Script

Created `scripts/data/update_uk_lrt_metadata.exs` to import:
- `si_code` - JSONB with values array
- `md_subjects` - JSONB with values array
- `md_total_paras`, `md_body_paras`, `md_schedule_paras`, `md_attachment_paras`, `md_images` - integers
- `md_enactment_date`, `md_made_date`, `md_coming_into_force_date`, `md_dct_valid_date`, `md_restrict_start_date` - dates

### Metadata Migration Results

```
Updated:      18441
No data:      658 (no Metadata fields)
Errors:       0
Duration:     31.2s
```

### Role GVT Article Columns

Added `role_gvt_article` and `article_role_gvt` columns to schema and updated taxa script.

### Taxa Migration Results

```
Updated:      7778
No data:      11321 (no Taxa fields)
Errors:       0
Duration:     28.5s

New columns populated:
  role_gvt_article: 4974
  article_role_gvt: 4974
  role_article: 4986
  article_role: 4986
```

### leg_gov_uk_url Generated Column

Converted `leg_gov_uk_url` to PostgreSQL generated column computed from `type_code`, `year`, `number`.
- Before: 4 rows
- After: 14,165 rows (auto-generated)

## Todo

### Completed
- [x] Identify CSV columns available (109 columns)
- [x] Compare CSV to LRT-SCHEMA.md for missing data
- [x] Create script for metadata columns (si_code, md_subjects, dates, paras)
- [x] Run metadata script and verify
- [x] Add role_gvt_article columns to schema
- [x] Run taxa script with new columns
- [x] Convert leg_gov_uk_url to generated column
- [x] Update LRT-SCHEMA.md with stats data counts

### Data Gaps - Pending Review

#### Credentials
- [x] `number_int` - Converted to generated column from `number` (19,088 records, 1 NULL for regnal year format)
- [x] `old_style_number` - Imported 99 records from CSV

#### Domain (renamed from secondary_class)
- [x] Renamed `secondary_class` to `domain` and changed type from `text` to `text[]`
- [x] Created script to populate `domain` from CSV "Class" column
  - environment: 7,176
  - health_safety: 1,876
  - human_resources: 195
  - Total: 9,247 records
- [x] (Later) Update parser to derive domain from family emoji (💚=environment, 💙=health_safety, 💜=human_resources)

#### Metadata
- [ ] `latest_change_date` - CSV has `md_change_log` (176 rows) but it's a change log format, not a simple date. Would need parsing to extract. Low priority.

#### Function/Relationships
- [ ] `enacted_by_meta` - New column, not yet populated (from parser, not CSV)
- [x] Update parser to store `enacted_by` in canonical name format (`UK_ukpga_2000_5`) instead of legislation.gov.uk URI format (`ukpga/2000/5`). Check if other relationship columns (`enacting`, `amending`, `amended_by`, `rescinding`, `rescinded_by`) have the same issue.

#### Function/Linked (Graph Edges)
- [x] `linked_enacted_by` - Populated 7,839 rows (98.4% resolution rate)
- [x] `linked_amending` - Populated 9,673 rows (79.4% resolution rate)
- [x] `linked_amended_by` - Populated 6,180 rows (74.5% resolution rate)
- [x] `linked_rescinding` - Populated 2,014 rows (55.4% resolution rate)
- [x] `linked_rescinded_by` - Populated 5,600 rows (91.0% resolution rate)

Script: `scripts/data/populate_linked_columns.exs`
- Resolves relationships to existing uk_lrt records
- enacted_by uses URI format (ukpga/2021/30) converted to name format
- Other columns already use name format (UK_ukpga_2021_30)
- Unresolved refs are laws outside our regulatory database scope

#### Taxa
- [x] `article_popimar_clause` - CSV has column but no data (0 rows). No action needed.
- [ ] `purpose` - Empty, no CSV source (deprecated or future use?)

## Relationship Maintenance - Architecture Gaps

The current system has significant gaps in relationship maintenance:

### Current State
- **One-way flow**: Data flows legislation.gov.uk → database via StagedParser
- **No re-scraping mechanism**: Existing laws aren't updated when new amendments affect them
- **Manual linked_* updates**: `populate_linked_columns.exs` must be run manually after imports
- **Database triggers**: Only `latest_amend_date` and `latest_rescind_date` auto-update

### Future Work Needed
- [ ] Scheduled job to re-scrape laws with recent amendments on legislation.gov.uk
- [ ] Change detection mechanism (compare md_modified dates?)
- [ ] Auto-populate `linked_*` columns when relationships change (trigger or Ash callback?)
- [ ] Cascade update when a new law declares `enacted_by` an existing law (enacting[] should update)

## Stats Columns Analysis

DB already has significant data in stats columns (15,000+ rows). No action needed.

### Naming Mismatch Note
- CSV uses: `revoking` / `revoked_by`
- DB uses: `rescinding` / `rescinded_by`

## Existing Scripts

Location: `scripts/data/`

| Script | Purpose |
|--------|---------|
| `update_uk_lrt_metadata.exs` | si_code, md_subjects, dates, paras |
| `update_uk_lrt_taxa.exs` | Taxa columns (role, holders, popimar, article mappings) |
| `update_uk_lrt_function.exs` | Function field |
| `update_uk_lrt_extent.exs` | Geographic extent |
| `update_uk_lrt_amending.exs` | Amending relationships |
| `update_uk_lrt_enacting.exs` | Enacting relationships |
| `update_uk_lrt_md_modified.exs` | md_modified date |
| `update_uk_lrt_duty_type.exs` | Duty type field |

## Notes
- Match on `Name` column (CSV) to `name` column (DB)
- CSV Name format: `UK_uksi_2024_123` matches DB format
- 474 records in CSV not found in DB (likely newer Airtable entries)

**Ended**: 2026-01-17
