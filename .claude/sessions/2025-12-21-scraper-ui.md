# Scraper UI

**Started**: 2025-12-21 19:00
**Status**: In Progress

## Overview

Build admin UI for the legislation.gov.uk scraper implemented in previous session. Pattern based on sertantai-enforcement's scraper UI with routes under `/admin/scrape`.

## Architecture

```
Frontend (SvelteKit)                    Backend (Phoenix)
┌─────────────────────┐                ┌─────────────────────┐
│ /admin/scrape       │──────────────→ │ POST /api/scrape    │
│  - Date range form  │                │  - Create session   │
│  - Start button     │                │  - Run scrape       │
│                     │                │  - Categorize       │
├─────────────────────┤                ├─────────────────────┤
│ /admin/scrape/      │──────────────→ │ GET /api/sessions   │
│   sessions          │                │  - List all         │
│  - Session list     │                │                     │
│  - Status badges    │                ├─────────────────────┤
├─────────────────────┤                │ GET /api/sessions/  │
│ /admin/scrape/      │──────────────→ │   :id               │
│   sessions/:id      │                │  - Session detail   │
│  - 3 group tabs     │                │  - Group records    │
│  - Record table     │                │                     │
│  - Parse actions    │                ├─────────────────────┤
│                     │                │ POST /api/sessions/ │
│                     │──────────────→ │   :id/parse         │
│                     │                │  - Parse group      │
└─────────────────────┘                └─────────────────────┘
```

## Todo

### Phase 1: Backend API (Complete)

- [x] Create `SertantaiLegalWeb.ScrapeController`
  - [x] `POST /api/scrape` - Create and run scrape session
  - [x] `GET /api/sessions` - List sessions (recent/active)
  - [x] `GET /api/sessions/:id` - Session detail with group counts
  - [x] `GET /api/sessions/:id/group/:group` - Group records (1, 2, 3)
  - [x] `POST /api/sessions/:id/persist/:group` - Persist group to uk_lrt
  - [x] `POST /api/sessions/:id/parse/:group` - Parse group with metadata fetch
  - [x] `DELETE /api/sessions/:id` - Delete session

- [x] Add routes to `router.ex`
  ```elixir
  scope "/api", SertantaiLegalWeb do
    pipe_through :api
    post "/scrape", ScrapeController, :create
    get "/sessions", ScrapeController, :index
    get "/sessions/:id", ScrapeController, :show
    get "/sessions/:id/group/:group", ScrapeController, :group
    post "/sessions/:id/persist/:group", ScrapeController, :persist
    post "/sessions/:id/parse/:group", ScrapeController, :parse
    delete "/sessions/:id", ScrapeController, :delete
  end
  ```

- [x] Write controller tests (26 tests, 2 skipped for integration)

### Phase 1b: UK LRT CRUD API (Complete)

- [x] Create `SertantaiLegalWeb.UkLrtController`
  - [x] `GET /api/uk-lrt` - List/search records with pagination & filters
  - [x] `GET /api/uk-lrt/:id` - Get single record
  - [x] `PATCH /api/uk-lrt/:id` - Update record
  - [x] `DELETE /api/uk-lrt/:id` - Delete record
  - [x] `GET /api/uk-lrt/search` - Search alias
  - [x] `GET /api/uk-lrt/filters` - Get available filter values

- [x] Add routes to `router.ex`
  ```elixir
  get "/uk-lrt", UkLrtController, :index
  get "/uk-lrt/filters", UkLrtController, :filters
  get "/uk-lrt/search", UkLrtController, :search
  get "/uk-lrt/:id", UkLrtController, :show
  patch "/uk-lrt/:id", UkLrtController, :update
  delete "/uk-lrt/:id", UkLrtController, :delete
  ```

- [x] Write controller tests (19 tests)

### Phase 2: Frontend Routes (Complete)

- [x] Create SvelteKit route structure:
  ```
  frontend/src/routes/admin/
  ├── +layout.svelte          # Admin layout (nav, auth check)
  ├── scrape/
  │   ├── +page.svelte        # New scrape form
  │   └── sessions/
  │       ├── +page.svelte    # Session list
  │       └── [id]/
  │           └── +page.svelte # Session detail
  ```

- [x] Install dependencies:
  - TanStack Query already installed
  - Added date-fns: `npm install date-fns`

- [x] Create API client (`src/lib/api/scraper.ts`)
  - Type definitions for ScrapeSession, ScrapeRecord, GroupResponse, ParseResult
  - Fetch functions for all API endpoints

- [x] Create TanStack Query hooks (`src/lib/query/scraper.ts`)
  - Query keys factory
  - useSessionsQuery, useSessionQuery, useGroupQuery
  - useCreateScrapeMutation, usePersistGroupMutation, useParseGroupMutation, useDeleteSessionMutation

### Phase 3: Scrape Form (`/admin/scrape`) (Complete)

- [x] Create scrape form page
  - [x] Year input (default: current year)
  - [x] Month select (1-12)
  - [x] Start day input (1-31)
  - [x] End day input (1-31)
  - [x] Type code filter (optional)
  - [x] Start Scrape button
  - [x] Loading state during scrape

- [x] Implement form submission with TanStack Query mutation
- [x] Redirect to session detail on success

### Phase 4: Session List (`/admin/scrape/sessions`) (Complete)

- [x] Create session list page
  - [x] Table: Session ID, Date Range, Status, Records (with group badges), Created At
  - [x] Status badge (active/completed/failed)
  - [x] Click row → navigate to detail
  - [x] Delete button per row

- [x] Use TanStack Query for data fetching

### Phase 5: Session Detail (`/admin/scrape/sessions/:id`) (Complete)

- [x] Create session detail page
  - [x] Session metadata header (date range, status)
  - [x] Stats grid (Total, G1, G2, G3, Persisted)
  - [x] Tab navigation for 3 groups:
    - Group 1: SI Code Match (highest priority)
    - Group 2: Term Match (medium priority)
    - Group 3: Excluded (review needed)
  - [x] Record count badge per tab

- [x] Create records table (inline)
  - [x] Columns: Title, Type, Year, Number, SI Codes (Group 1 only)
  - [x] Link to legislation.gov.uk

- [x] Create action buttons per group:
  - [x] "Parse Group" button (fetches metadata)
  - [x] "Persist Group" button

### Phase 6: Polish

- [x] Add confirmation dialogs for destructive actions (persist, parse, delete)
- [x] Add loading spinners during mutations
- [x] Success/error message display for mutations
- [ ] Add toast notifications (optional enhancement)
- [ ] Add loading skeletons (optional enhancement)
- [ ] Mobile-responsive tables (basic responsive done)
- [ ] Keyboard navigation (optional enhancement)

## Backend Mapping

| API Endpoint | SessionManager Method |
|--------------|----------------------|
| POST /api/scrape | `SessionManager.run(year, month, start, end)` |
| GET /api/sessions | `SessionManager.list_recent()` |
| GET /api/sessions/:id | `ScrapeSession` Ash read + `Storage.read_metadata()` |
| GET /api/sessions/:id/group/:group | `Storage.read_group()` |
| POST /api/sessions/:id/persist/:group | `SessionManager.persist_group()` |
| POST /api/sessions/:id/parse/:group | `LawParser.parse_group()` |
| DELETE /api/sessions/:id | `SessionManager.delete()` |

## Notes

- Related to previous session: `2025-12-21-legislation-gov-uk-scraper.md`
- Backend scraper modules already complete
- Pattern based on sertantai-enforcement `/admin/scrape` routes
- No SSE needed initially - scrape is fast enough for request/response
- Consider SSE later for parse operations (metadata fetch is slow)

## Reference: sertantai-enforcement Patterns

Key differences from enforcement scraper:
- **This app**: Single-step scrape (HTML → categorize), then separate parse (XML metadata)
- **Enforcement**: Multi-step scrape with SSE progress streaming

Reusable patterns:
- Route structure: `/admin/scrape`, `/admin/scrape/sessions`
- TanStack Query for mutations/queries
- Status badges for session state
- Tab navigation for different data views
- Action buttons for group operations

## Current Button Behavior

| Button | Action | Resource Usage |
|--------|--------|----------------|
| **Parse Group N** | Fetch XML metadata + persist to DB | Heavy (HTTP calls per record) |
| ~~Persist Group N~~ | ~~Save existing JSON data to DB~~ | ~~Light (no HTTP calls)~~ |

**Parse** = Full workflow: fetches extended metadata from legislation.gov.uk XML API (extent, enactment, amendments, repeals/revocations), then saves to `uk_lrt` table.

**Persist button removed**: The initial scrape metadata is insufficient for `uk_lrt` records. Records require extent, enactment date, amendment history, and repeal/revocation metadata which only comes from the full parse workflow.

Both buttons operate on the **entire group**. See Feature Extensions below for selective processing and interactive review.

## Feature Extension: Selective Record Processing (Implemented)

### Background

In the donor `legl` app, the parse/persist workflow iterates through each law sequentially:
1. For each record, user is prompted to confirm parsing (resource-heavy XML fetch)
2. After parsing, user confirms persistence (or uses `post: true` flag for auto-persist)

This CLI-based workflow doesn't translate well to a UI.

### Proposed UI Enhancement

Add **checkbox selection** for records to enable batch operations:

```
┌─────────────────────────────────────────────────────────────────────┐
│ SI Code Match  (37)    Term Match  (88)    Excluded  (52)          │
├─────────────────────────────────────────────────────────────────────┤
│ [Select All] [Deselect All]          [Parse Selected] [Persist...] │
├─────────────────────────────────────────────────────────────────────┤
│ ☑ │ Environmental Permitting Regulations      │ uksi │ 2025 │ 1227 │
│ ☑ │ Control of Major Accident Hazards Regs    │ uksi │ 2025 │ 1215 │
│ ☐ │ Planning (Hazardous Substances) Order     │ uksi │ 2025 │ 1198 │
│ ☐ │ Water Environment Regulations             │ uksi │ 2025 │ 1156 │
└─────────────────────────────────────────────────────────────────────┘
```

### Implementation Requirements

1. **Add `selected` field to records in JSON files**
   ```json
   {
     "name": "uksi/2025/1227",
     "Title_EN": "Environmental Permitting Regulations",
     "selected": true,
     ...
   }
   ```

2. **New API endpoints**
   - `PATCH /api/sessions/:id/group/:group/select` - Update selection for records
   - Request body: `{ "names": ["uksi/2025/1227", ...], "selected": true }`

3. **Modify existing endpoints**
   - `POST /api/sessions/:id/parse/:group` - Parse only selected records (or all if none selected)
   - `POST /api/sessions/:id/persist/:group` - Persist only selected records

4. **Frontend changes**
   - Add checkbox column to records table
   - Add "Select All" / "Deselect All" buttons
   - Update button labels: "Parse Selected (N)" / "Persist Selected (N)"
   - Optimistic updates for selection state

5. **Storage module changes**
   - `Storage.update_selection(session_id, group, names, selected)` - Mutate JSON file
   - Preserve selection state across page refreshes

### Workflow

1. User views session → records load with current selection state
2. User clicks checkboxes to mark records for processing
3. Selection is saved to JSON immediately (debounced API call)
4. "Parse Selected" parses only marked records
5. "Persist Selected" persists only marked records to uk_lrt table

### Benefits

- **User control**: Review records before committing resources
- **Batch operations**: Process multiple records efficiently
- **Persistence**: Selection survives page refresh
- **Flexibility**: Can parse subset, review results, then persist

### Implementation Complete

**Backend Changes:**
- `Storage.update_selection/4` - Update selection state for records in JSON files
- `Storage.get_selected/2` - Get list of selected record names
- `ScrapeController.select/2` - PATCH endpoint for updating selection
- `LawParser.parse_group/3` - Added `selected_only` option to filter by selection

**API Endpoints:**
- `PATCH /api/sessions/:id/group/:group/select` - Update selection (body: `{names: [...], selected: bool}`)
- `POST /api/sessions/:id/parse/:group` - Now accepts `selected_only` parameter

**Frontend Changes:**
- Added checkbox column to records table with header "select all" checkbox
- Select All / Deselect All buttons
- Selection counter showing "N of M selected"
- Parse button shows "Parse Selected (N)" or "Parse All (N)"
- Selected rows highlighted with blue background
- Selection state persisted in JSON files (survives page refresh)

## Feature Extension: Interactive Parse Review (Implemented)

### Background

In the donor `legl` app, the parse workflow is interactive:
1. User selects a law to parse
2. Extended metadata is fetched (extent, enactment, amendments, repeals)
3. The parsed record is displayed for review
4. User confirms or cancels before persistence

The current UI parses entire groups without user review. This is problematic because:
- **Family assignment** may need manual correction (auto-categorization isn't perfect)
- **Duplicate detection** - record may already exist in `uk_lrt`
- **Data quality** - user should verify metadata before committing

### Proposed UI: Parse Review Modal

When parsing records (individually or in batch), display each result for review:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Parse Review                                                           [×]  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Title: Environmental Permitting (England and Wales) Regulations 2025      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Identification                                                       │   │
│  ├──────────────────┬──────────────────────────────────────────────────┤   │
│  │ Type Code        │ uksi                                             │   │
│  │ Year             │ 2025                                             │   │
│  │ Number           │ 1227                                             │   │
│  │ SI Codes         │ ENVIRONMENTAL PROTECTION, POLLUTION              │   │
│  └──────────────────┴──────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Classification                                                       │   │
│  ├──────────────────┬──────────────────────────────────────────────────┤   │
│  │ Family*          │ [E ▼]  (Environment / Health / Safety / ...)     │   │
│  │ Matched Terms    │ environmental, pollution, emissions              │   │
│  └──────────────────┴──────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Metadata                                                             │   │
│  ├──────────────────┬──────────────────────────────────────────────────┤   │
│  │ Extent           │ E+W (England and Wales)                          │   │
│  │ Enactment Date   │ 2025-03-15                                       │   │
│  │ Made Date        │ 2025-03-10                                       │   │
│  │ In Force Date    │ 2025-04-01                                       │   │
│  │ Description      │ These Regulations consolidate and replace...     │   │
│  └──────────────────┴──────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ Changes                                                              │   │
│  ├──────────────────┬──────────────────────────────────────────────────┤   │
│  │ Amends           │ uksi/2016/1154, uksi/2018/110                    │   │
│  │ Revokes          │ uksi/2010/675                                    │   │
│  │ Amended By       │ (none)                                           │   │
│  └──────────────────┴──────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ ⚠ Duplicate Warning                                                  │   │
│  │ A record with name 'uksi/2025/1227' already exists in uk_lrt.       │   │
│  │ Confirming will UPDATE the existing record.                         │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│                                    [Cancel]  [Skip]  [Confirm & Save]      │
│                                                                             │
│  Record 3 of 37                                          [← Prev] [Next →] │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Implementation Requirements

1. **New API endpoint for single-record parse**
   - `POST /api/sessions/:id/parse-one` - Parse single record, return full metadata
   - Request body: `{ "name": "uksi/2025/1227" }`
   - Response: Full parsed record with all metadata fields
   - Does NOT persist - just returns data for review

2. **Duplicate check endpoint**
   - `GET /api/uk-lrt/exists/:name` - Check if record exists
   - Returns: `{ "exists": true, "id": "uuid", "updated_at": "..." }`

3. **Confirm endpoint**
   - `POST /api/sessions/:id/confirm` - Persist reviewed record
   - Request body: `{ "name": "uksi/2025/1227", "family": "E", "overrides": {} }`
   - Allows user to override Family and potentially other fields

4. **Frontend changes**
   - Parse Review modal component
   - Family dropdown (E/H/S/W/HS/EHS/etc.)
   - Navigation for batch parsing (Prev/Next/Skip)
   - Duplicate warning display
   - Form validation

5. **Backend changes**
   - `LawParser.parse_single(session_id, name)` - Parse one record without persisting
   - `UkLrt.upsert(record, overrides)` - Insert or update with user overrides
   - Track which records have been reviewed in session metadata

### Workflow

1. User clicks "Parse Group" or "Parse Selected"
2. For each record in sequence:
   a. Fetch extended metadata from legislation.gov.uk
   b. Check for duplicate in `uk_lrt`
   c. Display Parse Review modal
   d. User reviews, edits Family if needed
   e. User clicks Confirm (save), Skip (don't save), or Cancel (abort batch)
3. After all records processed, show summary

### Batch Processing Options

For large groups, offer two modes:

1. **Interactive Mode** (default): Review each record before saving
2. **Auto Mode**: Parse and save all, log any that need review (duplicates, missing data)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Parse 37 records in Group 1?                                        │
│                                                                     │
│ ○ Interactive - Review each record before saving                    │
│ ● Auto - Parse all, flag issues for later review                    │
│                                                                     │
│                                        [Cancel]  [Start Parsing]    │
└─────────────────────────────────────────────────────────────────────┘
```

### Benefits

- **Data quality**: User verifies each record before persistence
- **Family correction**: Override auto-categorization when wrong
- **Duplicate handling**: Explicit choice to update or skip existing records
- **Audit trail**: Track which records were manually reviewed
- **Flexibility**: Interactive for careful review, auto for bulk processing

### Implementation Complete

**Backend Changes:**

1. **StagedParser module** (`backend/lib/sertantai_legal/scraper/staged_parser.ex`)
   - Four independent parsing stages: extent, enacted_by, amendments, repeal_revoke
   - Note: Metadata (title, dates, SI codes) is captured during initial scrape by NewLaws
   - enacted_by stage parses `/introduction/made/data.xml` for enacting parent laws
   - Acts (ukpga, etc.) skip enacted_by as they are primary legislation
   - Each stage reports its own success/error status
   - Returns merged record data with per-stage results
   - Graceful handling of 404s (e.g., no amendments data is OK)

2. **New API endpoints:**
   - `POST /api/sessions/:id/parse-one` - Parse single record, return staged results
   - `POST /api/sessions/:id/confirm` - Persist reviewed record with family override
   - `GET /api/uk-lrt/exists/*name` - Check if record exists (wildcard path for slashes)

3. **Controller actions:**
   - `ScrapeController.parse_one/2` - Invokes StagedParser, checks duplicates
   - `ScrapeController.confirm/2` - Parses, applies overrides, persists, marks reviewed
   - `UkLrtController.exists/2` - Handles wildcard path parameter

**Frontend Changes:**

1. **API client** (`frontend/src/lib/api/scraper.ts`)
   - Added `parseOne()`, `confirmRecord()`, `checkExists()` functions
   - TypeScript interfaces for ParseOneResult, ConfirmResult, ExistsResult

2. **TanStack Query hooks** (`frontend/src/lib/query/scraper.ts`)
   - `useParseOneMutation()` - Parse single record
   - `useConfirmRecordMutation()` - Confirm and persist
   - `useExistsQuery()` - Check duplicate

3. **ParseReviewModal component** (`frontend/src/lib/components/ParseReviewModal.svelte`)
   - Displays parsed record with all metadata sections
   - Shows stage status with visual indicators (+/x/-)
   - Editable Family dropdown for classification override
   - Duplicate warning with existing record details
   - Prev/Next/Skip/Cancel/Confirm navigation
   - Progress indicator (Record N of M)

4. **Session detail page integration**
   - "Review Selected" / "Review All" button for interactive mode
   - "Review" button on each row for single-record parsing
   - Modal opens and iterates through records
   - Completion message shows confirmed/skipped/error counts

**Workflow:**
1. User clicks "Review Selected" or "Review" on a row
2. Modal opens and parses the first record
3. User reviews staged results (sees any errors per stage)
4. User can edit Family classification
5. User clicks Confirm (saves), Skip (moves on), or Cancel (closes modal)
6. After all records processed, summary message displayed

**Ended**: 2025-12-22 ~15:30

## Summary
- Completed: All major features (API, UI, Parse Review, Family categorization)
- Files touched: ScrapeController, UkLrtController, StagedParser, Models, Filters, ParseReviewModal.svelte, scraper.ts, query/scraper.ts
- Outcome: Full scraper UI with interactive parse review and granular family categorization (~40 families)
- Next: Schema alignment between frontend/backend and LRT database columns
