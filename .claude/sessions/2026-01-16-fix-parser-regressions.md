# Title: fix-parser-regressions

**Started**: 2026-01-16
**Issue**: None

## Context
Regressions introduced after ParsedLaw refactor (Phase 4). Screenshot shows diff between parsed output and DB values.

## Completed
- [x] **title_en**: Add `Helpers.title_clean` in `ParsedLaw.from_map` via `get_title` helper
- [x] **name**: Add `IdField.normalize_to_db_name` in `ParsedLaw.from_map` via `get_name` helper
- [x] **live_description**: Confirmed intentional - new metadata being populated
- [x] **geo_region**: Migrated from text to text[] array type
  - Migration: `string_to_array(geo_region, ',')`
  - Ash resource: `{:array, :string}`
  - ParsedLaw: `get_list` (keeps as list)
- [x] **enacted_by**: Dual storage for rich metadata + self-referential links
  - New column `enacted_by_meta` as `{:array, :map}` for rich objects
  - `enacted_by` remains as `{:array, :string}` for DB name links
  - ParsedLaw extracts both: `get_name_list` for names, `get_meta_list` for metadata

## Summary
All regressions fixed. 500 tests pass.

### Key Changes
1. `ParsedLaw.from_map` now normalizes:
   - `title_en` → strips "The " prefix and year suffix
   - `name` → converts `uksi/2025/622` to `UK_uksi_2025_622`
   - `geo_region` → keeps as list (DB is now text[])
   - `enacted_by` → extracts names from rich maps
   - `enacted_by_meta` → preserves full metadata maps

2. DB Migrations:
   - `geo_region`: text → text[]
   - `enacted_by_meta`: new JSONB array column

**Ended**: 2026-01-16
