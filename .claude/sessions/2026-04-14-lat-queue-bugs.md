# Title: LAT Queue Bugs

**Started**: 2026-04-14T14:38Z
**Page**: http://localhost:5175/admin/lat/queue

## Todo
- [x] Fix: Making Classification column edits not persisting to DB
- [x] Fix: Duplicate records in LAT queue (e.g. UK_wsi_2005_2929 appears twice)
- [x] Fix: Zenoh TaxaSubscriber not deriving making_classification from duty_type

## Notes
- Bug 1: `<select>` only saved on `blur` — added `on:change={saveEdit}` + moved state clear before await
- Bug 2: Deleted duplicate 323ac949, added unique index on `uk_lrt.name`
- Bug 3: Added `derive_making_classification/1` to TaxaSubscriber — derives is_making + making_classification from duty_type values on Zenoh return. Bulk-fixed 3,320 records (is_making=true→making) + 121 records (taxa says not_making)
