# Title: Create Separate Endpoint for Cascade Parse Management

**Started**: 2026-01-21 18:47
**Issue**: None (standalone session)

## Goal
Create a standalone page for asynchronous cascade parse management. Users work through the "leaves and branches" of an initiating law before moving to the next law.

## Current System
- `cascade_affected_laws` table stores pending updates tied to sessions
- Modal works synchronously after parsing completes
- Two update types: `:reparse` (amending/rescinding) and `:enacting_link` (parent laws)

## Commits

1. **562fee2** - feat(cascade): Add standalone cascade management page
2. **1724abf** - feat(cascade): Add two-step workflow for new laws

## Implementation Summary

### Backend Changes

**New Controller**: `CascadeController` (`backend/lib/sertantai_legal_web/controllers/cascade_controller.ex`)

Endpoints:
- `GET /api/cascade` - List pending entries, grouped by type (reparse/enacting) and DB status (in-db/missing)
- `GET /api/cascade/sessions` - List sessions with pending cascade counts
- `POST /api/cascade/reparse` - Batch re-parse selected entries by ID
- `POST /api/cascade/update-enacting` - Update enacting links on parent laws
- `POST /api/cascade/add-laws` - Add missing laws to database
- `DELETE /api/cascade/:id` - Remove single entry
- `DELETE /api/cascade/processed` - Clear processed entries

**CascadeAffectedLaw Resource Updates**:
- Added `all_pending` read action - queries pending entries across all sessions
- Added `sessions_with_pending` read action - gets distinct session IDs with pending work

### Frontend Changes

**New Page**: `/admin/scrape/cascade/+page.svelte`

Features:
- Session filter dropdown (default: all sessions, can filter to specific session)
- Summary stats cards showing pending counts by category
- Four collapsible sections:
  1. **Laws to Re-parse** (in DB) - select and batch re-parse
  2. **New Laws to Add** (not in DB) - two-step workflow with metadata preview
  3. **Parent Laws - Update Enacting** (in DB) - update enacting arrays
  4. **Parent Laws - Not in Database** - add missing parent laws
- Operation results banner showing per-entry status
- Select all/deselect all for each section
- Remove individual entries

**Navigation**: Added "Cascade" link to admin layout navigation

### Two-Step Workflow for New Laws (commit 1724abf)

Reuses existing session parse endpoints - no backend changes needed.

**Step 1: Get Metadata**
- User selects entries and clicks "Get Metadata"
- Frontend calls existing `POST /api/sessions/:session_id/parse-one` API
- UI shows columns: Status, Title, Type, Year, Number, SI Codes, Source
- Status indicators: Pending -> Parsing -> Ready -> Error
- Green highlight for rows with metadata ready, red for errors

**Step 2: Add to Database**
- "Add to Database" button only enabled for entries with metadata
- Frontend calls existing `POST /api/sessions/:session_id/confirm` API
- Cascade entry is deleted after successful persist
- Query is refetched to update the list

### API Client & Query Hooks

Added to `frontend/src/lib/api/scraper.ts`:
- `getCascadeIndex()` - fetch cascade entries
- `getCascadeSessions()` - fetch sessions list
- `cascadeReparse()` - batch re-parse
- `cascadeUpdateEnacting()` - update enacting links
- `cascadeAddLaws()` - add missing laws
- `deleteCascadeEntry()` - remove entry
- `clearProcessedCascade()` - clear processed

Added to `frontend/src/lib/query/scraper.ts`:
- `useCascadeIndexQuery()` - query hook with session filter
- `useCascadeSessionsQuery()` - sessions query hook
- Mutation hooks for all operations

## User Workflow
1. Parse new law(s) via existing scrape workflow
2. Navigate to `/admin/scrape/cascade`
3. See affected laws organized by type and DB status
4. Work through re-parses (updates existing laws)
5. For new laws: Get Metadata first, review, then Add to Database
6. Update enacting parents
7. Move to next initiating law

## Additional Commits

3. **bbc9217** - fix: Prevent reparse when Cancel is clicked on ParseReviewModal
4. **7772705** - feat(cascade): Selective stage parsing for cascade re-parse
5. **4f90540** - fix(parse-stream): Use whitelist map for stages parameter
6. **69a3755** - feat(parse-review): Merge DB record with parsed changes for display
7. **2ec45f0** - fix(parser): Add blank lines between law blocks in stats fields

## Session Continuation (from compacted context)

### Fast Metadata Endpoint
- Added `POST /api/sessions/:id/parse-metadata` - uses `Metadata.fetch` directly (fast)
- Added `IdField.normalize_to_slash_format/1` helper for name format conversion
- "Get Metadata" now uses fast endpoint; "Add to Database" runs full parse

### Self-Reference Filtering
- Fixed cascade showing law in its own affected list
- Added defense-in-depth filter in `add_affected_laws_to_db` comparing normalized names

### ParseReviewModal Integration
- Cascade "Re-parse Selected" now uses same `ParseReviewModal` as session workflow
- Provides diff view and user confirmation before saving

### Selective Stage Parsing
- Wired `stages` prop through `ParseReviewModal` to `parseOneStream`
- Cascade re-parse only runs stages 4+5 (amendments, repeal_revoke)
- Non-selected stages shown as 'skipped' in progress UI
- Faster re-parse: only updates amended_by/rescinded_by fields

### Stages Parameter Atom Fix
- `String.to_existing_atom` failed when atoms hadn't been used yet
- Replaced with whitelist map for safe string-to-atom conversion

### Sparse Record Display Fix
- Selective stage parsing caused anaemic display (most fields empty)
- Backend now returns full `duplicate.record` (no scraped_keys filtering)
- Frontend `displayRecord` merges DB record with parsed changes
- User sees complete record with parsed updates overlaid; diff shows only actual changes

### Stats Field Formatting Fix
- Legacy data has `\n\n` (blank line) between law blocks in per_law stats
- Current parser used single `\n`, causing false diffs
- Fixed `build_count_per_law_summary` and `build_count_per_law_detailed` to use `\n\n`

### Update Enacting Workflow Improvements (commit 5c58b06)
- **Review-then-remove pattern**: Entries no longer auto-removed after update
- **Current Enacting display**: Shows actual law names (comma-separated) instead of "X laws"
- **Sorted enacting array**: New laws sorted by year/number descending (newest first)
- **Reactive UI update**: Uses `queryClient.setQueryData` to show changes immediately
- **Bulk Remove button**: Select entries and remove with confirmation after reviewing

## Notes
- Existing modal retained for users who prefer synchronous workflow
- New page better for large cascade trees or async processing
- Session-scoped by default prevents confusion across unrelated parses
- Two-step workflow reuses existing parseOne/confirmRecord APIs (no duplication)

**Ended**: 2026-01-22 10:45
