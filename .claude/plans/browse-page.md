# Plan: Blanket Bog Browse Page

## Status: Implemented (Phase 1 Complete)

The `/browse` route provides a read-only UK LRT table using ElectricSQL + TableKit.

### What's Done

- Browse layout with emerald green accent and "Blanket Bog" tier badge
- Read-only table (no editing, no Parse & Review, no action buttons)
- ElectricSQL sync via `getUkLrtCollection` / `updateUkLrtWhere`
- ViewSelector + SaveViewModal from `svelte-table-views-tanstack`
- ViewSidebar from `svelte-table-views-sidebar` (basic integration)
- 5 default views: Recent Laws, By Family, By Status, By Type, Geographic Scope
- `defaultGrouping` and `defaultExpanded` via `svelte-table-kit@0.13.0`
- Derived grouping columns (`md_date_year`, `md_date_month`) from DB generated columns
- Stale shape recovery after Electric restart (onError handler)
- Filter-driven Electric sync (`is_after`/`is_before` operators)

### Key Files

| File | Purpose |
|------|---------|
| `frontend/src/routes/browse/+layout.svelte` | Browse layout with nav and tier badge |
| `frontend/src/routes/browse/+page.svelte` | Main browse page (read-only table) |
| `frontend/src/lib/db/index.client.ts` | ElectricSQL sync, shape recovery |

### Columns (22 + 2 derived)

Core: `name`, `title_en`, `year`, `number`, `type_code`, `type_class`
Derived: `md_date_year` (groupable), `md_date_month` (groupable)
Description: `family` (groupable), `family_ii` (groupable), `function`, `si_code`
Status: `live` (groupable)
Geographic: `geo_extent` (groupable), `geo_region` (groupable)
Dates: `md_date`, `md_made_date`, `md_coming_into_force_date`
Amendments: `latest_amend_date`, `latest_rescind_date`
Links: `leg_gov_uk_url`

### Default Views

1. **Recent Laws** (default) — `md_date` desc, filtered to past 3 years, grouped by year + month
2. **By Family** — grouped by `family`, sorted alphabetically
3. **By Status** — grouped by `live` status
4. **By Type** — grouped by `type_code`
5. **Geographic Scope** — grouped by `geo_extent`

---

## Known Bugs / Remaining Work

1. [x] **Sidebar views & labelling** — Added 3 view groups (New Laws, Amended Laws, Repealed Laws) with 7 time-based views each, plus Classification group. Views ordered by definition. Commit `3b24a67`.

2. [ ] **Grouping rows show Family column value** — Group header rows (e.g. "2028", "Mar") render the Family cell content alongside the group key. Needs investigation: could be in `svelte-table-kit` group row rendering, `@tanstack/svelte-table` aggregation, or the browse page `slot="cell"` being applied to group rows.

3. [ ] **No search** — No way to search within displayed data or query the full DB. Options: global filter in TableKit, full-text search via Electric/Postgres, or a new search component/library.

4. [ ] **`captureCurrentConfig()` returns hardcoded defaults** — "Save View" and "Update View" buttons save incorrect config:
   ```typescript
   // CURRENT (broken) — returns defaults, not current state
   function captureCurrentConfig(): TableConfig {
     return {
       filters: [],
       sort: null,
       columns: columns.map((c) => String(c.id)),
       columnOrder: columns.map((c) => String(c.id)),
       columnWidths: {},
       pageSize: 25,
       grouping: []
     };
   }
   ```
   Needs to read from TableKit's current state via `handleTableStateChange` or a ref.

5. [ ] **`leg_gov_uk_url` link click area too small** — "View" text link is hard to click.

6. [ ] **Mobile responsive** — Sidebar doesn't collapse to dropdown on narrow screens.

---

## Related

- Future view sidebar and tier features: `.claude/plans/issue-18-future-tiers-and-views.md`
- ElectricSQL sync bug fixes: commit `17fd7d1`
- `defaultGrouping` added in `svelte-table-kit@0.13.0`: commits `c94b97e`, `a9239fc`
