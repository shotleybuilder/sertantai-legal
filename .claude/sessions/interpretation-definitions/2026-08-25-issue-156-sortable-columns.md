---
session: "Sortable Definition Columns (#156)"
status: pending
opened: 2026-08-25
github_issue: 156
depends_on:
  - interpretation-definitions/2026-08-24-definitions-ui-debugging
superseded_by: 160
---

# Session: Sortable Definition Columns (#156) (PENDING)

## Problem

The definitions table on `/admin/definitions/browse` sorts by Term alphabetically only. Column headers are not clickable. Section sort needs natural/numeric ordering (`section-2` < `section-10`). A compound Term+Section sort is needed for laws with scoped definitions.

**Note:** This may be delivered for free by #160 (GridLite migration) which has built-in column sorting. Evaluate whether to implement standalone or defer to GridLite.

## Todo

- ⬜ Decide: standalone implementation or defer to #160 GridLite migration
- ⬜ Add click-to-sort on column headers (Term, Section, Type, Status)
- ⬜ Implement natural/numeric section sort (extract number from `section-52`, `regulation-3`)
- ⬜ Add compound Term+Section sort option
- ⬜ Visual sort direction indicator (chevron/arrow)
- ⬜ Default sort remains Term ascending

## Dependencies

- ✅ Definitions browse page built
- ⬜ #160 GridLite migration decision (may supersede this work)
