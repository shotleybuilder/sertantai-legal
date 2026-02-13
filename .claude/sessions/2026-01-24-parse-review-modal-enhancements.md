# Title: ParseReviewModal Enhancements - Diff-First Layout & Session-less Reparse

**Started**: 2026-01-24
**Issue**: None

## Completed
- [x] Add ParseReviewModal import to admin/lrt page
- [x] Add state variables for modal visibility and selected record
- [x] Add View button (eye icon) to actions column
- [x] Add ParseReviewModal component to page template
- [x] Update instructions to document View button

## ParseReviewModal Use Cases

### Core Principle
**No parsing should update DB without manual review of the diff.**

The modal handles all persistence. User must review and confirm before any changes are saved.

### Use Case Matrix

| Use Case | Entry Point | Data Source | Mode | Diff Against | Can Reparse? | Persistence |
|----------|-------------|-------------|------|--------------|--------------|-------------|
| New law parse | Session workflow | Parse stream | Create | Nothing (all new) | Yes (stages) | Confirm → DB insert |
| Existing law reparse | Session workflow | Parse stream | Update | DB record | Yes (stages) | Confirm → DB update |
| Cascade reparse | Cascade workflow | Parse stream | Update | DB record | Yes (limited stages) | Confirm → DB update |
| View existing record | LRT browser | DB record | Read | N/A | **TBD** | N/A (read-only) |

### Modal Layout by Mode

| Mode | Primary Content | Secondary Content | Actions |
|------|-----------------|-------------------|---------|
| **Create** | All parsed fields (STAGE 1-6) | Parse stage status | Confirm, Skip, Nav |
| **Update** | **Diff first** + credentials only | Full sections (collapsed) | Confirm, Skip, Nav |
| **Read** | Full record (all sections) | - | Close, (Reparse per section) |

**Key insight:** In Update mode, the diff IS the content. User needs to see what changed, not scroll through unchanged data.

### Current Endpoint Analysis

| Endpoint | Purpose | Session Required? | Updates DB? | Supports Stages? |
|----------|---------|-------------------|-------------|------------------|
| `POST /sessions/:id/parse-one` | Parse single record in session | Yes | No | Yes |
| `GET /sessions/:id/parse-stream` | SSE stream for parse progress | Yes | No | Yes |
| `POST /sessions/:id/confirm` | Save parsed record to DB | Yes | **Yes** | N/A |
| `POST /uk-lrt/:id/rescrape` | Full reparse existing record | No | **Yes** | No |
| `POST /cascade/reparse` | Batch reparse for cascade | No | **Yes** | Yes (hardcoded) |

### The Problem

For "View existing record" (Read mode) from LRT browser:
- Current `rescrape` endpoint updates DB immediately (no review)
- Parse endpoints require a session
- No endpoint exists for: "parse this existing record, return diff, but don't save"

### Proposed Solution: Simplify

Instead of creating new endpoints, **extend the modal to work with existing infrastructure**:

#### Option: Session-less Parse Preview

Add single new endpoint:
```
POST /api/uk-lrt/:id/parse-preview
  ?stages=metadata,taxa  (optional, defaults to all)
  
Returns: { parsed_data, db_record, diff, stages: {...} }
Does NOT update DB
```

Then in ParseReviewModal:
- Read mode shows DB record initially
- User clicks "Reparse Section" → calls parse-preview for that stage
- User can reparse multiple stages sequentially (each merges into accumulated state)
- User clicks "Reparse All" → calls parse-preview with no stages param (runs all)
- Modal shows diff between accumulated parsed data and DB record
- User clicks "Save Changes" → calls existing `PATCH /uk-lrt/:id` to update

#### Reparse Behavior

| Action | Endpoint Call | Result |
|--------|---------------|--------|
| Reparse single stage | `parse-preview?stages=metadata` | Merges stage result into current state |
| Reparse another stage | `parse-preview?stages=taxa` | Merges that stage too (accumulates) |
| Reparse All | `parse-preview` (no stages) | Replaces all with fresh full parse |

**Key: Accumulated state is held in modal until user saves or closes.**

Current modal already supports sequential stage reparses (waits for one to complete before allowing next). Need to add:
1. "Reparse All" button in header
2. Accumulated parsed state that persists across multiple stage reparses

This keeps:
- Modal as single source of truth for persistence decisions
- No session required for ad-hoc reparse
- Diff always shown before save
- Selective stage parsing supported
- Multiple sequential reparses accumulate changes

### Endpoint Consolidation Opportunity

Current state has some redundancy:

| What | Session-based | Session-less |
|------|---------------|--------------|
| Parse (no save) | `parse-stream` | **NEW: `parse-preview`** |
| Save after review | `confirm` | `PATCH /uk-lrt/:id` |
| Parse + immediate save | N/A | `rescrape` (remove?) |

Consider deprecating `rescrape` once `parse-preview` exists - it bypasses the review principle.

## Implementation Plan

### Phase 1: Backend - Parse Preview Endpoint - COMPLETED
- [x] Add `POST /api/uk-lrt/:id/parse-preview` 
- [x] Accept optional `stages` query param (comma-separated: metadata,extent,enacted_by,amending,amended_by,repeal_revoke,taxa)
- [x] Return `{ parsed, current, diff, stages, errors, has_errors }`
- [x] No DB writes
- [x] Add controller tests for parse-preview endpoint

**Commit:** `a7d83d2`

### Phase 2: Frontend - ParseReviewModal Layout Fix (Update Mode) - COMPLETED

**Problem solved:** In update mode, RecordDiff was shown AFTER all the full record sections (STAGE 1-6). User had to scroll through unchanged fields before seeing what matters.

**Fix implemented:**
- [x] Move RecordDiff to TOP of content area (after title)
- [x] Show compact credentials summary (name, year, type, family)
- [x] Add update notice with last updated timestamp
- [x] Collapse all sections by default in Update mode via `shouldExpand()` helper
- [x] Remove duplicate diff display from bottom of modal

**Commit:** `5cb5e57`

### Phase 3: Frontend - ParseReviewModal Read Mode Enhancement - COMPLETED
- [x] Add `recordId` prop for read mode (enables reparse)
- [x] Enable `showReparse` on sections when `recordId` is set
- [x] Add accumulated parse state (`readModeAccumulatedData`) separate from display
- [x] New `reparseStageReadMode(stage)` function using parse-preview endpoint
- [x] Merges stage result into accumulated state
- [x] Diff computed between accumulated data and original record
- [x] Add "Reparse All" button in modal header
- [x] "Reparse All" calls `reparseAllReadMode()` - replaces accumulated state
- [x] "Save Changes" button calls `updateUkLrtRecord()` with accumulated changes
- [x] "Discard Changes" resets accumulated state to original record
- [x] Add `parsePreview` and `updateUkLrtRecord` API functions
- [x] Use `handleSectionReparse` to route to correct function based on mode

**Commit:** `f5d63fc`

### Phase 4: Integration with admin/lrt - COMPLETED
- [x] Pass `recordId` to ParseReviewModal (already have `record.id`)
- [x] Test selective reparse from View modal

**Commit:** `e8e2c73`

### Phase 5: Replace Rescrape Button with ParseReviewModal Workflow - COMPLETED
The rescrape button in admin/lrt previously called `POST /uk-lrt/:id/rescrape` which parsed and saved to DB immediately without review. This violated the core principle: "No parsing should update DB without manual review of the diff."

**Old flow (deprecated):**
1. User clicks rescrape button
2. `rescrapeRecord()` calls `POST /uk-lrt/:id/rescrape`
3. Backend parses and immediately updates DB
4. User sees alert "Rescrape complete"

**New flow (Parse & Review):**
1. User clicks "Parse & Review" button (refresh icon)
2. Open ParseReviewModal with `autoReparse=true` prop
3. Modal auto-triggers `reparseAllReadMode()` on open
4. `parsePreview()` fetches parsed data + diff (no DB write)
5. Modal shows diff for review
6. User clicks "Save Changes" → updates DB via `PATCH /uk-lrt/:id`
7. Or user clicks "Discard" → no DB changes

**Tasks:**
- [x] Add `autoReparse` prop to ParseReviewModal
- [x] Add reactive statement to trigger `reparseAllReadMode()` when modal opens with `autoReparse=true`
- [x] Add `openParseReviewModal()` function in admin/lrt for Parse & Review workflow
- [x] Remove `rescrapeRecord()` function and `rescrapingIds` state
- [x] Update button to use new workflow with "Parse & Review" tooltip
- [x] Deprecate `POST /uk-lrt/:id/rescrape` endpoint (returns 410 Gone with migration info)
- [x] Update instructions to document new workflow

**Endpoint deprecated:**
```
POST /uk-lrt/:id/rescrape  →  410 Gone (DEPRECATED)
  Replaced by:
    POST /uk-lrt/:id/parse-preview  (get parsed data, no save)
    PATCH /uk-lrt/:id               (save after review)
```

**Commit:** `4459ce0`

## Notes
- Previous session `2026-01-22-parse-review-modal-refactor.md` completed Phases 1-4 (field org, display modes, per-stage reparse, architecture review)
- Decision was to retain modal architecture (not dedicated route)
- This session extends read mode with reparse capability

**Ended**: 2026-01-24
