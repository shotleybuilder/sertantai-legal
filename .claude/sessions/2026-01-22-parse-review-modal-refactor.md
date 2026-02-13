# Title: Parse Review Modal Refactor

**Started**: 2026-01-22 10:46
**Issue**: None (standalone session)

## Planned Refactors

### 1. Create vs Update display modes
- **Create**: Show ALL editable fields from schema (exclude auto-fields like `created_at`, `updated_at`, `id`)
- **Update**: Show only key identifier fields + the diff (changed fields only)

### 2. Align form sections with parse stages
- Organize field groups to match parse flow: metadata → enacting → amending → taxa etc.
- Minor refactor - most already aligned, just needs cleanup/reordering

### 3. Per-stage re-parse controls
- Add controls to each form section to re-trigger that specific parse stage
- Allows user to re-run individual stages (e.g., just re-parse amendments) without full re-parse
- Leverages existing `stages` parameter in parser

### 4. Improve field naming in diff view
- Make field names more human-readable in the diff display
- e.g., `amended_by` → "Amended By", `si_code` → "SI Code"

### 5. Separate amending and amended_by sections
- `amending` and `amended_by` are distinct parse processes
- Should be separate sections in the form, not grouped together
- Each with its own re-parse control (per refactor #3)

### 6. Consider dedicated route instead of modal
- Review modal architecture - may be better as standalone page with its own URI
- Benefits: direct linking, browser history, can open pre-parse for existing records
- Could serve as a record editor with selective stage re-parse controls
- Modal could remain for quick inline review, full page for detailed editing

### 7. Align field order with LRT-SCHEMA.md
- Field order within each parse group should match `docs/LRT-SCHEMA.md`
- Ensures consistency between schema documentation and UI

## Implementation Plan

### Phase 1: Foundation - Field Organization & Naming
*Low risk, improves readability, prepares for later phases*

- [x] Restore friendly names from 2025-12-22-schema-alignment.md session into docs/LRT-SCHEMA.md
- [x] Create field label mapping (snake_case → human readable) - `FIELD_LABELS` in field-config.ts
- [x] Review LRT-SCHEMA.md and define canonical field order per section
- [x] Separate `amending`/`rescinding` fields from `amended_by`/`rescinded_by` into distinct sections
- [x] Reorder existing sections to match parse stage flow
- [x] Apply field ordering within each section

**Sections implemented (matching LRT-SCHEMA.md stages):**
1. STAGE 1 💠 metadata (Credentials, Description, Dates, Document Statistics)
2. STAGE 2 📍 geographic extent
3. STAGE 3 🚀 enacted_by
4. STAGE 4 🔄 amendments (Function, Self-Affects, Amending, Rescinding, Amended By, Rescinded By)
5. STAGE 5 🚫 repeal_revoke
6. STAGE 6 🦋 taxa (Purpose, Roles, Duty Type, Duty Holder, Rights Holder, Responsibility Holder, Power Holder, POPIMAR)
7. Change Logs
8. Timestamps

### Phase 2: Display Modes (Create / Update / Read) - COMPLETED
*Medium complexity, improves UX for different workflows*

**Three modes:**
- **Create**: New law being parsed for first time - show all parsed fields
- **Update**: Existing law reparsed - show diff between parsed data and DB record  
- **Read**: View existing DB record as-is (no parse) - read-only display

**Implementation approach:**
- Mode auto-detected from props: `record` prop = Read mode, `records` prop = Create/Update (parse workflow)
- Create vs Update determined by `parseResult.duplicate?.exists`

- [x] Add optional `record` prop for Read mode (single DB record, no parse)
- [x] Add optional `mode` prop to force specific mode
- [x] Derive effective mode: explicit mode > record prop > parse result
- [x] Read mode: skip parsing, display record directly, hide confirm/skip/nav buttons
- [x] Update mode: show diff prominently at top before field sections
- [x] Create mode: current behavior (all fields shown)
- [x] Visual mode indicator in header (badge or subtitle)

**Commit:** `95dced4`

### Phase 3: Per-Stage Re-parse Controls - COMPLETED
*Medium complexity, adds selective re-parse capability*

- [x] Add re-parse button to each section header (via CollapsibleSection `showReparse` prop)
- [x] Wire button to trigger single-stage parse via existing `stages` parameter
- [x] Show loading state on section during re-parse (opacity + spinner)
- [x] Merge stage result into current form state
- [x] Update diff view after re-parse completes
- [x] Add tests for reparse functionality (12 new tests)

**Commit:** `111b448`

### Phase 4: Architecture Review - Dedicated Route - COMPLETED
*Higher complexity, requires architectural decision*

**Decision: RETAIN MODAL architecture (no dedicated route)**

#### Evaluation Summary

| Aspect | Dedicated Route | Modal (Current) |
|--------|----------------|-----------------|
| Direct linking | ✓ Shareable URLs | ✗ No deep links |
| Browser history | ✓ Back/forward works | ✗ No history |
| Context retention | ✗ Loses session context | ✓ Preserves workflow state |
| Multi-record flow | ✗ Requires custom state mgmt | ✓ Native prev/next navigation |
| Implementation cost | High (new route, loader, state) | None (already built) |
| Cascade workflow | ✗ Would need session passing | ✓ Seamless integration |

#### Analysis

**Current Usage Patterns (from codebase review):**

1. **Session Workflow** (`/admin/scrape/sessions/[id]`):
   - Primary use case: parse batch of scraped records
   - Modal opens with `parseModalRecords` array (1 to N records)
   - Sequential confirm/skip flow with prev/next navigation
   - On complete, triggers cascade check → may open CascadeUpdateModal
   - **Verdict**: Modal is ideal - maintains session context, array state, cascade flow

2. **Cascade Workflow** (`/admin/scrape/cascade`):
   - Opens modal for "Laws to Re-parse" with `stages={['amendments', 'repeal_revoke']}`
   - Selective stage parsing - exactly what modal now supports
   - Multi-record batch processing
   - **Verdict**: Modal is ideal - leverages stages prop, batch flow

3. **LRT Browser** (`/admin/lrt`):
   - Currently uses TableKit with inline editing for Family/Function fields
   - Has "rescrape" action per row (calls API endpoint directly)
   - **Potential**: Could benefit from "View Record" modal in Read mode
   - **Verdict**: Read mode already supported, could add row click → modal

4. **Read Mode (Phase 2)**:
   - Already supports opening with `record` prop (no parse)
   - Could serve as "View Law Details" from LRT browser
   - No dedicated route needed - modal works well for peek/view

**Why NOT a Dedicated Route:**

1. **Session state complexity**: Parse workflow needs `sessionId`, `records[]`, `currentIndex`, `confirmedCount`, cascade detection. Route would need URL params + query string + possibly localStorage to reconstruct.

2. **No standalone "edit law" use case**: Users don't navigate directly to edit a law by URL. They either:
   - Browse scrape session → parse batch
   - Browse cascade → re-parse affected
   - Browse LRT table → inline edit or view details

3. **ElectricSQL sync**: LRT browser already has real-time sync. A separate edit route would duplicate this setup.

4. **Modal enhancements sufficient**: Phases 1-3 addressed the core issues:
   - Field organization: now matches LRT-SCHEMA.md
   - Display modes: Create/Update/Read
   - Per-stage reparse: granular control

**Recommendation: Modal Improvements Instead**

1. **✓ Already done**: Collapsible sections, better field rendering, mode-specific behavior
2. **Future consideration**: Add row-click handler in LRT browser to open modal in Read mode
3. **Future consideration**: Modal size could be made responsive/fullscreen on mobile

#### Checklist

- [x] Evaluate modal vs page trade-offs for this codebase
- [x] Document decision and rationale
- [x] Decision: Retain modal architecture

## Todo
- [x] Phase 1: Field organization & naming
- [x] Phase 2: Display modes (Create/Update/Read)
- [x] Phase 3: Per-stage re-parse controls
- [x] Phase 4: Architecture review

## Notes
- Phase 1 is prerequisite for Phases 2-3 (clean field structure needed)
- Phase 4 is independent - can be done anytime, decision informs Phase 3 implementation
- Each phase should be tested before moving to next
- Exact field orders to be finalized from LRT-SCHEMA.md before starting each phase

### Key Files
- Modal: `frontend/src/lib/components/ParseReviewModal.svelte`
- Schema: `docs/LRT-SCHEMA.md`
- Staged parser: `backend/lib/sertantai_legal/scraper/staged_parser.ex`
- API types: `frontend/src/lib/api/scraper.ts`

### Stage → Section Mapping
| Stage | Fields/Section |
|-------|----------------|
| metadata | Credentials, Description, Dates & Stats |
| extent | Geographic Extent |
| enacted_by | Enacted By |
| amendments | Amending/Rescinding (outgoing), Amended By/Rescinded By (incoming) |
| repeal_revoke | Status |
| taxa | Roles/Taxa |

## Blueprint

The refactored modal follows the structure defined in `docs/LRT-SCHEMA.md` (v0.7):

### Section Structure (from LRT-SCHEMA.md)

Each section should be **collapsible/expandable**. Field labels use **Friendly Name** from schema.

---

# PHASE 1 - COMPLETED

## Foundation Work
- [x] Created `CollapsibleSection.svelte` - expand/collapse toggle with section/subsection levels
- [x] Created `field-config.ts` - `FIELD_LABELS` mapping + `SECTION_CONFIG` with all sections/fields
- [x] Created `FieldRow.svelte` - type-aware field rendering (date, boolean, array, json, url, multiline, text)

## Section Implementation (matching LRT-SCHEMA.md)

### STAGE 1 💠 metadata
- [x] Parent section with 4 subsections: Credentials, Description, Dates, Document Statistics
- [x] Field order matches LRT-SCHEMA.md tables exactly

### STAGE 2 📍 geographic extent
- [x] Single section (no subsections): geo_extent, geo_region, geo_detail

### STAGE 3 🚀 enacted_by
- [x] Single section: enacted_by, enacted_by_meta, is_enacting, enacting, linked_enacted_by

### STAGE 4 🔄 amendments
- [x] 6 subsections: Function, Self-Affects, Amending, Rescinding, Amended By, Rescinded By
- [x] linked_* fields moved to their respective subsections
- [x] latest_amend_date, latest_change_date, latest_rescind_date in appropriate subsections

### STAGE 5 🚫 repeal_revoke
- [x] Single section: live (Status), live_description (Status Description)

### STAGE 6 🦋 taxa
- [x] 8 subsections: Purpose, Roles, Duty Type, Duty Holder, Rights Holder, Responsibility Holder, Power Holder, POPIMAR

### Supporting Sections
- [x] Change Logs section
- [x] Timestamps section

## Key Files Modified
- `frontend/src/lib/components/ParseReviewModal.svelte` - config-driven rendering
- `frontend/src/lib/components/parse-review/field-config.ts` - section/field configuration
- `frontend/src/lib/components/CollapsibleSection.svelte` - reusable component
- `frontend/src/lib/components/parse-review/FieldRow.svelte` - field rendering

## Commits
- `a85e2ef` - STAGE 1 💠 metadata with 4 subsections
- `0c04843` - STAGE 2 📍 geographic extent
- `dffb7e5` - STAGE 3 🚀 enacted_by
- `a546bf3` - STAGE 4 🔄 amendments with 6 subsections
- `863e9dc` - STAGE 5 🚫 repeal_revoke
- `d8c66dd` - STAGE 6 🦋 taxa with 8 subsections

**Ended**: 2026-01-23 08:40
