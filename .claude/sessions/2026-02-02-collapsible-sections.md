# Collapsible Sections for ParseReviewModal

**Started**: 2026-02-02 13:30 UTC
**Issue**: None (frontend UI improvement)

## Goal

Improve the "Update existing record" view in ParseReviewModal with:
1. Collapsible sections (STATUS, FUNCTION, etc.)
2. Collapsible lengthy fields (like `amended_by` arrays)

## Todo

- [x] Explore current ParseReviewModal implementation
- [x] Add collapsible section headers
- [x] Add collapsible lengthy field values
- [x] Test UI improvements

## Changes Made

**File**: `frontend/src/lib/components/RecordDiff.svelte`

### 1. Collapsible Section Groups
- Section headers (STATUS, FUNCTION, etc.) are now clickable buttons
- Shows field count badge: "(3 fields)"
- Chevron icon rotates on expand/collapse
- All sections default to expanded

### 2. Collapsible Long Field Values
- Arrays with >5 items are auto-collapsed
- Strings >300 chars are auto-collapsed
- Shows preview: `["UK_ssi_2025_166", "UK_ssi_2025_125", "UK_ssi_2025_124", ... +9 more]`
- "Expand/Collapse" button for toggling full view
- Array length badge shown: "12 items"

### Tests
- All 95 frontend tests pass
- Build succeeds
- No new TypeScript errors in RecordDiff.svelte

## Notes

- Screenshot shows sections like STATUS, FUNCTION with multiple fields
- Long array fields (amended_by) would benefit from collapse/expand
- Fixed Svelte reactivity issue: must access `expandedGroups[group.name]` directly in template, not via function call

---

**Ended**: 2026-02-02 14:45 UTC
