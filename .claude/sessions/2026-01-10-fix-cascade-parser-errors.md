# Title: fix-cascade-parser-errors

**Started**: 2026-01-10
**Issue**: None

## Summary

Implementing cascade review mode so that affected laws go through ParseReviewModal for manual review instead of auto-saving.

## Completed

### Cascade Review Mode (commit 78a7a5e)
- Added `reviewLaws` event to CascadeUpdateModal for review mode
- Added `handleReviewSelected()` and `handleReviewAll()` functions that emit laws for review
- Kept existing `batchReparse` functions for future auto-save mode
- Updated session page to handle `reviewLaws` event and open ParseReviewModal
- Convert `AffectedLaw[]` to `ScrapeRecord[]` format for modal compatibility

### Parse Loop Bug Fix
- **Root Cause**: When a parse error occurred, `lastParsedName` was reset to `null`, which triggered the reactive statement again causing an infinite retry loop
- **Fix**: Added `failedNames: Set<string>` to track names that failed to parse
- Reactive statement now checks `!failedNames.has(currentRecord.name)` before parsing
- Failed names are cleared when navigating away (allowing retry on return)
- All state properly reset when modal opens with new records

### Cascade Parse Fix (parse_one endpoint)
- **Root Cause**: `parse_one` endpoint required record to exist in session JSON storage, but cascade update records only exist in `uk_lrt`
- **Fix**: Added `build_record_from_name/1` helper that parses the name string (e.g., "uksi/2025/622" or "UK_uksi_2025_622") into a minimal record with `type_code`, `Year`, `Number` fields
- Now falls back to building record from name if not found in session

### Redundant Reparse on Confirm Fix
- **Root Cause**: `confirm` endpoint was calling `StagedParser.parse(record)` again, even though frontend already had parsed data from `parse_one`
- **Fix**: Modified `confirm` endpoint to require pre-parsed `record` parameter from frontend
- Frontend now sends `parseResult.record` when calling confirm
- Added 3 tests to prevent regression:
  - `returns 400 when record parameter is missing`
  - `persists record without re-parsing when record data is provided`
  - `merges family and overrides with pre-parsed record`

### Prior Session Fixes (commits 901849d - 8fb34c8)
- ChangeLogger only tracks keys present in new record (fixed corrupted change log)
- Handle lowercase title_en key from StagedParser
- Use persist_direct to skip redundant API fetch on save
- Add change logging to LawParser.update_record
- Exclude pdf_href, enacting_text, introductory_text from diff view
- Normalize name format and extract enacted_by names correctly
- Handle UK_ name format in batch_reparse
- Add Cascade Update button to session page header

## In Progress

None

---

**Ended**: 2026-01-16
**Committed**: 102391d

## Summary
- Completed: 2 of 2 todos (parser review + si_code fix)
- Files: `staged_parser.ex`, `scrape_controller.ex`, `docs/PARSER_REVIEW.md`
- Outcome: Fixed recurring si_code diff bug by adding metadata stage and unwrapping JSONB from DB for list-to-list comparison
- Next: Consider full ParsedLaw struct refactor per PARSER_REVIEW.md to eliminate scattered normalization

---

## Session Closed: 2026-01-13

## Flow

1. User clicks "Cascade Update" button on session page
2. CascadeUpdateModal opens showing affected laws
3. User selects laws and clicks "Review Selected" or "Review All"
4. Modal emits `reviewLaws` event with selected laws
5. Session page closes cascade modal and opens ParseReviewModal
6. User reviews each law with diff view and confirms/skips
7. After completing, the session data refreshes

## Files Modified

- `frontend/src/lib/components/CascadeUpdateModal.svelte` - Added review mode
- `frontend/src/routes/admin/scrape/sessions/[id]/+page.svelte` - Handle reviewLaws event
- `frontend/src/lib/components/ParseReviewModal.svelte` - (investigating loop bug)

## Notes

- Auto-save via batchReparse is kept for future use when parser is mature
- The parse loop bug existed before today's changes (per user confirmation)
- Parse loop bug was caused by Svelte reactivity: error handler reset `lastParsedName = null`, which re-triggered the reactive statement
