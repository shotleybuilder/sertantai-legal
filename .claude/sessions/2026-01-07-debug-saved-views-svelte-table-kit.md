# Title: debug-saved-views-svelte-table-kit

**Started**: 2026-01-07
**Ended**: 2026-01-08
**Issue**: None

## Completed

### Session 1: Filter UI and Sync Fixes
- [x] Fixed filter UI not showing default year >= 2024 setting on load
- [x] Fixed "no data available" after filter fix (multiple sub-issues):
  - IndexedDB store conflict - changed to separate database for sync metadata
  - Stale offset with empty collection - added safety check
  - Insert collision errors - changed to upsert logic
  - subscribeChanges not firing - subscribe to syncStatus store
  - Redundant sync on initial load - initialize lastWhereClause
- [x] Fixed unsubscribe context error when navigating
- [x] Created IndexedDB persistence skill document

### Session 2: Default Credentials View
- [x] Fixed duplicate "Duty Holder"/"Duty Holders" views issue
- [x] Created default "Credentials" Saved View with auto-load:
  - Filter: year >= last 3 years
  - Sort: md_date descending (most recent first)
  - Columns: actions, name, title_en, year, number, type_code, type_class
- [x] Fixed auto-select timing (use viewActions.waitForReady())
- [x] Fixed view ID prefix issue (read from $savedViews store, not raw localStorage)
- [x] Fixed sort config (defaultSorting array with columnId)
- [x] Fixed filter value type (string not number for FilterCondition)

### Session 3: Calculated Date Fields (Amendment & Rescind)

#### Latest Amendment Date
- [x] Phase 1: Baseline Calculation
  - [x] Populated `latest_amend_date` for 5,512 records from `amended_by` references
  - [x] Checked orphan references (11,094 - expected, laws outside dataset)
  - [x] Populated `latest_amend_date_year` and `latest_amend_date_month`
- [x] Phase 2: Automatic Updates (PostgreSQL Triggers)
  - [x] Created GIN index on `amended_by` for fast lookups
  - [x] Trigger 1: When `amended_by` changes → recalculate `latest_amend_date`
  - [x] Trigger 2: When `md_date` changes → propagate to all laws it amends
  - [x] Tested both triggers successfully
- [x] Phase 3: Frontend Integration
  - [x] Verified `latest_amend_date` already in ElectricSQL sync schema
  - [x] Added "Last Amended" column to TableKit columns
  - [x] Created "Recently Amended" Saved View

#### Latest Rescind Date
- [x] Phase 1: Baseline Calculation
  - [x] Populated `latest_rescind_date` for 5,600 records from `rescinded_by` references
  - [x] Populated `latest_rescind_date_year` and `latest_rescind_date_month`
- [x] Phase 2: Automatic Updates (PostgreSQL Triggers)
  - [x] Created GIN index on `rescinded_by` for fast lookups
  - [x] Trigger 1: When `rescinded_by` changes → recalculate `latest_rescind_date`
  - [x] Trigger 2: When `md_date` changes → propagate to all laws it rescinds
- [x] Phase 3: Frontend Integration
  - [x] Added `latest_rescind_date` to ElectricSQL sync schema
  - [x] Added "Last Rescinded" column to TableKit columns
  - [x] Created "Recently Rescinded" Saved View

#### Ash Migration for Production
- [x] Created migration `20260108074126_add_calculated_date_triggers.exs` containing:
  - Conditional column additions (IF NOT EXISTS) for `_year` and `_month` variants
  - GIN indexes on `amended_by` and `rescinded_by`
  - All 4 trigger functions and triggers
  - Baseline calculation queries for both fields
- [x] Fixed migration for test database compatibility (missing `_year`/`_month` columns)

## New Saved Views Added
1. **Credentials** (default) - Core identification fields, last 3 years, sorted by md_date
2. **Recently Amended** - Laws amended in last 3 years, sorted by latest_amend_date
3. **Recently Rescinded** - Laws rescinded in last 3 years, sorted by latest_rescind_date

## Database Changes (Dev - Applied Manually)
```sql
-- GIN indexes
CREATE INDEX idx_uk_lrt_amended_by_gin ON uk_lrt USING GIN (amended_by);
CREATE INDEX idx_uk_lrt_rescinded_by_gin ON uk_lrt USING GIN (rescinded_by);

-- 4 triggers for automatic calculated field updates
-- (see migration file for full SQL)
```

## Todo (Future)
- [ ] Saved Views: Add collapsible groups support to svelte-table-views-tanstack library
- [ ] Filter library: Add relative time operators ("last 36 months") to svelte-table-kit

## Notes
- Using svelte-table-views-tanstack library with TableKit
- Filter values must be strings for FilterCondition component (not numbers)
- TableKit uses `defaultSorting` (array) not `defaultSort`, and SortConfig uses `columnId`
- svelte-table-views-tanstack uses `columnId` in FilterCondition, TableKit uses `field`
- View IDs in localStorage have prefix (e.g., `s:uuid`) - use $savedViews store not raw localStorage
- GIN index required for efficient trigger propagation on array columns

## Key Files Modified
- `frontend/src/routes/admin/lrt/+page.svelte` - Added columns and saved views
- `frontend/src/lib/electric/uk-lrt-schema.ts` - Added latest_rescind_date
- `backend/priv/repo/migrations/20260108074126_add_calculated_date_triggers.exs` - Production migration
