# Title: persisted-count-diff-ui

**Started**: 2026-01-04
**Completed**: 2026-01-04
**Issue**: None
**Deferred from**: 2026-01-04-scraping-bug-fix.md

## Summary

Implemented two features:
1. **Accurate "In DB" count**: Session detail page now shows how many records from the session already exist in uk_lrt database
2. **Diff viewer**: When parsing a record that already exists in DB, shows a collapsible diff of what fields changed

## Completed Tasks
- [x] Research npm libraries for diff visualization
- [x] Install jsondiffpatch (lightweight, no React dependency)
- [x] Extend backend check_duplicate to return full existing record
- [x] Create RecordDiff.svelte component using jsondiffpatch
- [x] Update ParseReviewModal to show diff when duplicate exists
- [x] Add backend GET /api/sessions/:id/db-status endpoint
- [x] Add frontend useSessionDbStatusQuery hook
- [x] Update session detail UI with "In DB" count (X / total)

## Changes Made

### Backend
- `lib/sertantai_legal_web/controllers/scrape_controller.ex`:
  - Extended `check_duplicate/1` to return full existing record as `record` field
  - Added `existing_record_to_map/1` helper to convert Ash struct to map
  - Added `db_status/2` action - returns count of session records in uk_lrt
- `lib/sertantai_legal_web/router.ex`:
  - Added route `GET /api/sessions/:id/db-status`

### Frontend
- `src/lib/components/RecordDiff.svelte`: New component
  - Uses jsondiffpatch Differ for object comparison
  - Uses formatters/html for visual diff output
  - Collapsible panel showing changed field count
  - Green/red/yellow styling for added/deleted/modified
- `src/lib/components/ParseReviewModal.svelte`:
  - Import and use RecordDiff component
  - Show diff below "Existing Record Found" warning
- `src/lib/api/scraper.ts`:
  - Added `DbStatusResult` interface
  - Added `getSessionDbStatus()` function
- `src/lib/query/scraper.ts`:
  - Added `sessionDbStatus` query key
  - Added `useSessionDbStatusQuery()` hook
- `src/routes/admin/scrape/sessions/[id]/+page.svelte`:
  - Added dbStatusQuery
  - Stats grid now 6 columns: added "In DB" (X / total) and "This Session"

## Library Choice

Used **jsondiffpatch** instead of json-diff-kit because:
- Differ class is standalone pure JS (no React)
- Built-in HTML formatter outputs standard HTML
- Mature, well-documented library
- Simple CSS customization for Svelte

## Notes
- The "In DB" count queries groups 1 and 2 only (group 3 is excluded laws)
- Diff view is collapsible to avoid overwhelming the modal
- No changes detected shows green "record is identical" message

## Deferred Tasks (Completed)
- [x] Add backend tests for `db_status/2` endpoint (scrape_controller_test.exs)
- [x] Add backend tests for `check_duplicate/1` returning full record
- [x] Add frontend tests for RecordDiff.svelte component (diff logic)

### Tests Added
- **Backend** (`scrape_controller_test.exs`): 8 new tests for `db_status` endpoint
  - 404 when session not found
  - Zero counts when no group files
  - Correct counts with group files
  - Identifies records existing in uk_lrt
  - Includes both group 1 and 2
  - Excludes group 3 records
  - Handles string keys in JSON
- **Frontend** (`RecordDiff.test.ts`): 21 tests for diff logic
  - Basic diff detection (identical, added, removed, modified)
  - Nested object diffs
  - Array diffs
  - Type changes
  - Changed fields extraction
  - HTML formatter output
  - Realistic UK LRT record scenarios

**Ended**: 2026-01-04
