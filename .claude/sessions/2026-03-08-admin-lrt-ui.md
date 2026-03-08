# Title: Admin LRT UI Improvements

**Started**: 2026-03-08

## Todo
- [ ] (awaiting prompts)

## Completed
- [x] LAT Queue: added Data Scope stat box showing Electric-level filters
- [x] LAT Queue: added `making_classification != not_making` to shape WHERE
- [x] LAT Queue: added `live != revoked` to shape WHERE
- [x] LAT Queue: removed redundant TableKit filters from All Queue view
- [x] LRT Admin: removed Holders column groups (Duties, Powers, Rights, Responsibilities — 8 columns + interface fields)
- [x] LRT Admin: removed POPIMAR view, 6 column definitions, and interface fields
- [x] LRT Admin: removed force-update of saved views on page load — user edits now persist

## Notes
- Changes so far were on `admin/lat/queue` before session started
- Each UI change will be prompted individually

**Ended**: 2026-03-08T23:59Z
