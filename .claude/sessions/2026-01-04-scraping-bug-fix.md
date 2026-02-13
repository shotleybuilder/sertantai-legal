# Title: scraping-bug-fix

**Started**: 2026-01-04
**Issue**: None

## Todo
- [x] Bug 1: Title_EN getting "The " prefix from XML metadata
- [x] Bug 2: name pattern should be UK_typecode_year_number
- [x] Bug 3: md_date not being persisted to database
- [x] Bug 4: Rate limiting for HTTP requests
- [x] Bug 5: Navigation highlighting and routing

## Deferred

### Feature: Persisted count and diff UI
- **Problem**: UI shows "Persisted: 0" even when laws exist in DB because 'saved' tag is only added to JSON after enrichment parse
- **Current behavior**: JSON only tracks what was saved in current session, not what exists in DB
- **Desired behavior**: 
  - UI should check DB for existing records and show accurate "Persisted" count
  - When re-parsing a previously saved law, show a diff: fields unchanged / fields changed
- **Scope**: Significant feature - requires DB lookup during session display and diff logic
- **Action**: Defer to dedicated session

## Completed

### Bug 1: Title_EN prefix issue
- **Problem**: Title_EN saved with "The " prefix and year suffix
- **Cause**: `merge_metadata/2` in `law_parser.ex:290` overwrote original Title_EN with XML formal title
- **Fix**: Preserve original Title_EN before merge, restore after
- **File**: `backend/lib/sertantai_legal/scraper/law_parser.ex:290-313`

### Bug 2: name pattern regression
- **Problem**: name field using `typecode/year/number` instead of `UK_typecode_year_number`
- **Cause**: `new_laws.ex:60` used inline string interpolation instead of `IdField.build_uk_id/3`
- **Why no test caught it**: Test at `new_laws_test.exs:35` was asserting the wrong format
- **Fix**: 
  - `new_laws.ex:60-63` - Use `IdField.build_uk_id/3` for name generation
  - `new_laws_test.exs:35-40` - Fixed test to expect `UK_uksi_2024_1001` format

### Bug 3: md_date not persisted
- **Problem**: md_date (primary date) calculated in metadata.ex but not persisted
- **Cause**: `build_attrs/1` in `law_parser.ex` missing `md_date` and `md_dct_valid_date` fields
- **Fix**: Added `md_date` and `md_dct_valid_date` to `build_attrs/1`
- **File**: `backend/lib/sertantai_legal/scraper/law_parser.ex:448-449`
- **Tests added**:
  - `law_parser_test.exs` - "includes md_date (primary date) from metadata"
  - `law_parser_test.exs` - "persists md_date to database"
- **Also fixed**: Updated test for "updates existing record" to expect preserved Title_EN (consequence of Bug 1 fix)

### Bug 4: Rate limiting for HTTP requests
- **Problem**: HTTP requests to legislation.gov.uk made too rapidly, risking blacklisting
- **Fix**: Added 2 second delay between requests in Client module
- **File**: `backend/lib/sertantai_legal/scraper/legislation_gov_uk/client.ex`
- **Implementation**:
  - Added `@default_delay_ms 2000` constant
  - Added `rate_limit_delay/0` helper called before each `fetch_html` and `fetch_xml`
  - Delay disabled in test mode for fast test execution
  - Configurable via `config :sertantai_legal, :scraper_request_delay_ms, 2000`

### Bug 5: Navigation highlighting
- **Problem**: Navigation buttons incorrectly highlighted (e.g., Sessions highlighted when on /admin/scrape)
- **Cause**: `isActive()` function wasn't reactive - `$page` store changes weren't triggering re-evaluation
- **Fix**: 
  - Made pathname reactive with `$: pathname = $page.url.pathname`
  - Pass pathname as parameter to `isActive()` function to ensure reactivity
  - Added `exact` flag for "New Scrape" to only match exact path
- **File**: `frontend/src/routes/admin/+layout.svelte`

## Notes
- Session: `backend/priv/scraper/2025-11-01-to-30`
- Both `IdField.build_name` (slash format) and `IdField.build_uk_id` (UK_ format) exist - use UK_ format for `name` field
- Airtable-imported records have md_date populated (116/161 for 2025) - these came from prior import
- Scraped records had md_made_date but md_date was NULL due to missing field in build_attrs
