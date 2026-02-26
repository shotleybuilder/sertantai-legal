# Title: LAT record detail modal ("back of the card")

**Started**: 2026-02-26

## Todo
- [x] Explore browse route and svelte-table-kit usage
- [x] Check svelte-table-kit for row detail/modal support
- [x] Determine: generic library feature vs app-level implementation
- [x] Create svelte-table-kit issue for row detail feature
- [x] Update svelte-table-kit to v0.15.1 (includes row-detail slot)
- [x] Implement row-detail slot on /browse page
- [x] Build and verify

## Research Findings
- Browse route: `frontend/src/routes/browse/+page.svelte`
- 26 columns defined, subset shown per view
- svelte-table-kit v0.14.0 had `onRowClick` but no built-in row detail
- Filed shotleybuilder/svelte-table-kit#6 for generic row detail feature
- stk#6 shipped in v0.15.1 with `row-detail` slot, modal, prev/next nav, ESC/keyboard

## Implementation
- Updated `@shotleybuilder/svelte-table-kit` to `^0.15.1`
- Added `features.rowDetail: true` to TableKit config
- Added `slot="row-detail"` with full record layout:
  - Header: title, name (mono), family prefix badge, status badge, function tags, legislation.gov.uk link
  - 4 detail sections in 2-column grid: Credentials, Classification, Geographic, Key Dates
- Library manages row selection, modal, prev/next navigation internally

## Key Files
- `frontend/src/routes/browse/+page.svelte` — row-detail slot added here
- `frontend/package.json` — svelte-table-kit bumped to ^0.15.1

**Ended**: 2026-02-26
