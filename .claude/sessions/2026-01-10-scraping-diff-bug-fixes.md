# Title: scraping-diff-bug-fixes

**Started**: 2026-01-10
**Issue**: None

## Completed
- [x] Fix Ash.NotLoaded serialization error - filter out unloaded calculations in existing_record_to_map
- [x] Fix name format mismatch in diff - normalize uksi/2025/622 to UK_uksi_2025_622
- [x] Fix credential key casing - Year->year, Number->number, Title_EN->title_en for diff comparison
- [x] Exclude created_at from diff - immutable timestamp shouldn't show as deleted
- [x] Normalize geo fields - geo_region list->string, remove extent/extent_regions/geo_country
- [x] Add word-wrap to RecordDiff - CSS fixes for long strings in diff view
- [x] Fix session list undefined regression - split enrich_type_fields vs enrich_type_fields_for_diff
- [x] Fix amending_stats detailed format - output "count - title\nurl\n details" with single-space indent
- [x] Fix amending_stats summary format - output "name - count\ntitle\nurl" on 3 lines
- [x] Filter existing record to scraped keys only - avoids false "deleted" for unscraped fields like is_commencing
- [x] Drop intermediate fields from diff - section_extents, revoked_element not in DB schema
- [x] Redesign RecordDiff component - grouped by category, sorted by change type (deleted/updated/added)
- [x] Filter empty values from diff - hide added/deleted fields with empty arrays, strings, null values
- [x] Drop more intermediate fields from diff - taxa_text_*, revoked_title_marker, partially_revoked, document_status, *_details, revoked
- [x] Add md_modified column to DB schema - migration 20260110114216_add_md_modified.exs
- [x] Import md_modified data from UK-EXPORT.csv - 17,858 of 19,090 records updated
- [x] Drop legacy SICode field from diff - duplicate of si_code
- [x] Normalize link fields (enacted_by, etc.) - convert JSON objects to UK_type_year_number format
- [x] Fix link field normalization bug - preserve already-correct UK_type_year_number format from Amending module
- [x] Fix TaxaParser to use body text for role extraction - was incorrectly using introduction only, missing actors like "Ind: Worker"
- [x] Fix Amending 404 stats map missing keys - incomplete stats caused crash before taxa stage could run
- [x] Add live integration tests for role parsing - verifies TaxaParser uses body text and StagedParser populates role

## Todo
- None pending

## Additional Fixes (Session 2)
- [x] Clear bad change log entry for UK_uksi_2025_622 test record
- [x] Add 'reviewed' to diff exclusion list (not in db schema)
- [x] Fix enacted_by extraction - extract_enacted_by_names/1 extracts name strings from map objects
- [x] Fix name normalization - normalize_name/2 converts slash format to canonical UK_ format, preventing duplicate records
- [x] Delete duplicate uksi/2025/622 records created by bug

**Ended**: 2026-01-10T19:45:00Z

## Fixes 13/01/2026

Summary of Issues

| # | Field | DB (existing) | Parser (incoming) | Root Cause | Fix |
|---|-------|---------------|-------------------|------------|-----|
| 1 | `enacted_by` | `["ukpga/2008/29"]` | `["UK_ukpga_2008_29"]` | Format inconsistency - DB has slash format | Updated `parse_law_id_to_map()` to use `IdField.normalize_to_db_name()` |
| 2 | `duty_type` | `"Interpretation..."` (CSV string) | `["Amendment"]` (array) | Type mismatch - DB stores as CSV string | Changed to JSONB `{"values": [...]}`, created migration + import script |
| 3 | `role` | `["Ind: Worker"]` | `[]` | Empty not persisting - stale data preserved | Changed filter to only reject `nil`, added taxa fields to `build_attrs()` |
| 4 | `role_gvt` | `{"Gvt: Minister": true}` | `["Gvt: Minister"]` | Format mismatch - DB uses `{key: true}` | Added `list_to_key_map()` helper for holder fields |
| 5 | `popimar` | `{"Policy": true}` | `null` | Not in `build_attrs()` | Added to `build_attrs()` with `list_to_key_map()` conversion |
| 6 | `si_code` | `null` | `"INFRASTRUCTURE PLANNING"` | `list_to_map()` didn't handle strings | Added string handling, removed duplicate CSV format in `new_laws.ex` |
| 7 | `md_total_paras` | `9.000000000` (decimal) | `9` (integer) | Type mismatch | Changed schema to `:integer`, created migration |
| 8 | `dct_valid` | field name | `md_dct_valid_date` | Field name mismatch | Fixed field names in `staged_parser.ex`


## Notes
- IdField.normalize_to_db_name/1 added for URL->DB name conversion
- build_count_per_law_detailed outputs title+URL format matching DB, falls back to name for tests
- build_count_per_law_summary outputs name+count, title, URL on 3 separate lines
- RecordDiff now groups fields matching schema alignment doc (Credentials, Description, Status, Geographic Extent, Metadata, Function, Roles, etc.)
- Link fields (enacted_by, enacting, amended_by, amending, rescinded_by, rescinding) normalized from JSON objects to UK_type_year_number format for self-referential consistency

## Files Modified
- `backend/lib/sertantai_legal/scraper/id_field.ex` - normalize_to_db_name/1
- `backend/lib/sertantai_legal/scraper/staged_parser.ex` - build_count_per_law_summary/detailed format fixes, fixed enacted_by name format, fixed md_dct_valid_date/md_restrict_start_date field names
- `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex` - field normalization, key filtering, link field normalization
- `backend/lib/sertantai_legal_web/controllers/uk_lrt_controller.ex` - added list_to_jsonb_map helper for duty_type
- `backend/test/sertantai_legal/scraper/staged_parser_test.exs` - updated tests for new formats
- `frontend/src/lib/components/RecordDiff.svelte` - complete redesign with grouping and sorting
- `backend/lib/sertantai_legal/legal/uk_lrt.ex` - added md_modified attribute, changed md_total_paras to integer, changed duty_type to map
- `backend/priv/repo/migrations/20260110114216_add_md_modified.exs` - migration for md_modified column
- `backend/priv/repo/migrations/20260113191838_change_md_total_paras_to_integer.exs` - migration for md_total_paras type
- `backend/priv/repo/migrations/20260113192227_change_duty_type_to_jsonb.exs` - migration for duty_type to JSONB
- `scripts/data/update_uk_lrt_md_modified.exs` - import script for md_modified from CSV
- `scripts/data/update_uk_lrt_duty_type.exs` - import script for duty_type from CSV to JSONB format
- `backend/lib/sertantai_legal/scraper/taxa_parser.ex` - use body text as primary source for role extraction
- `backend/lib/sertantai_legal/scraper/amending.ex` - fix 404 stats map missing keys
- `backend/lib/sertantai_legal/scraper/law_parser.ex` - added taxa fields to build_attrs(), added list_to_key_map() helper, changed filter to only reject nil, added string handling to list_to_map()
- `backend/lib/sertantai_legal/scraper/new_laws.ex` - removed duplicate si_code CSV handling
- `backend/test/sertantai_legal/scraper/staged_parser_live_test.exs` - live integration tests for role parsing, enacted_by format test
- `backend/test/sertantai_legal/scraper/law_parser_test.exs` - si_code persistence test

---

## Proposal: Holistic Change Log for Record Diffs

### Current State

The DB has two text-based change log columns:
- `amending_change_log` - tracks changes to amending-related fields
- `amended_by_change_log` - tracks changes to amended_by-related fields

Format:
```
date
field_name
old_value -> new_value
```

#### Existing Change Log Data

**Database (19,090 records):**
| Column | Records with data |
|--------|------------------|
| amending_change_log | 287 (1.5%) |
| amended_by_change_log | 302 (1.6%) |

**CSV Export (19,573 records):**
| Column | Records with data |
|--------|------------------|
| Live?_change_log | 203 (1.0%) |
| md_change_log | 176 (0.9%) |
| amending_change_log | 287 (1.5%) |
| amended_by_change_log | 302 (1.6%) |

**Note:** The CSV has two additional change log columns (`Live?_change_log`, `md_change_log`) not currently in the DB schema.

**Recommendation:** With less than 2% of records having existing change log data, it's feasible to parse and migrate the existing text-based logs into the new structured `record_change_log` JSONB column as part of the migration. This would consolidate all four change log types into a single structured format.

### Proposed Design

#### 1. New Column: `record_change_log`

Add a new JSONB column to capture all field changes when persisting scraped records:

```elixir
attribute :record_change_log, :map do
  allow_nil? true
  description "Holistic change log for all record field changes"
end
```

#### 2. Change Log Entry Structure

```json
{
  "entries": [
    {
      "timestamp": "2026-01-10T12:34:56Z",
      "source": "scraper",
      "session_id": "2025-05-01-to-31",
      "changes": {
        "added": {
          "md_modified": "2024-03-15"
        },
        "updated": {
          "role": {
            "old": ["Ind: Worker"],
            "new": []
          },
          "geo_region": {
            "old": "E+W+S",
            "new": "E+W+S+NI"
          }
        },
        "deleted": {
          "old_field": "some_value"
        }
      },
      "summary": "3 fields changed (1 added, 1 updated, 1 deleted)"
    }
  ]
}
```

#### 3. Implementation Approach

**Option A: Compute on Persist (Recommended)**
- When persisting a record via `LawParser.parse_record/2` with `persist: true`
- Compute diff between existing DB record and incoming scraped record
- Append new entry to `record_change_log` JSONB array
- Preserves full history with timestamps

**Option B: Store Latest Diff Only**
- Only store the most recent diff result
- Simpler but loses history
- Could use `last_change_log` column instead

#### 4. Integration Points

1. **Persister Module** (`backend/lib/sertantai_legal/scraper/persister.ex`)
   - Before update, compute diff using same logic as diff view
   - Build change log entry
   - Append to existing `record_change_log` or create new

2. **ScrapeController** (`scrape_controller.ex`)
   - Already computes diff for UI display
   - Extract diff computation to shared module for reuse

3. **New Module: `ChangeLogger`**
   ```elixir
   defmodule SertantaiLegal.Scraper.ChangeLogger do
     def build_change_entry(existing, incoming, opts \\ [])
     def append_to_log(existing_log, new_entry)
     def format_summary(changes)
   end
   ```

#### 5. Migration Strategy

1. Add `record_change_log` column (JSONB, nullable)
2. Keep existing `amending_change_log` and `amended_by_change_log` for backwards compatibility
3. New persists write to all three columns during transition
4. Eventually deprecate the old text-based columns

#### 6. Benefits

- **Structured data**: JSONB allows querying, filtering, aggregation
- **Full history**: Append-only log preserves all changes
- **Source tracking**: Know if change came from scraper, manual edit, or import
- **Session linking**: Connect changes to specific scrape sessions
- **Consistent format**: Matches the diff view UI output

#### 7. Future Enhancements

- API endpoint to query change history for a record
- UI to display change history timeline
- Bulk change reports across sessions
- Rollback capability using change log data
