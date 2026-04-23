# Title: LAT Queue Bugs

**Started**: 2026-04-14T14:38Z
**Page**: http://localhost:5175/admin/lat/queue

## Todo
- [x] Fix: Making Classification column edits not persisting to DB
- [x] Fix: Duplicate records in LAT queue (e.g. UK_wsi_2005_2929 appears twice)
- [x] Fix: Zenoh TaxaSubscriber not deriving making_classification from duty_type
- [x] Migrate to TanStack DB onUpdate mutation handlers (optimistic UI + SQL injection fix)
- [x] Fix: Function column only showing "Making", ignoring other values (e.g. "Amending Maker")

## Notes
- Bug 1: `<select>` only saved on `blur` — added `on:change={saveEdit}` + moved state clear before await
- Bug 2: Deleted duplicate 323ac949, added unique index on `uk_lrt.name`
- Bug 3: Added `derive_making_classification/1` to TaxaSubscriber — derives is_making + making_classification from duty_type values on Zenoh return. Bulk-fixed 3,320 records (is_making=true→making) + 121 records (taxa says not_making)
- Bug 4: Migrated from direct PGLite writes to TanStack DB `onUpdate` mutation handlers. Created two skills documenting patterns.
- Bug 5: Function column cell template only checked `fns?.includes('Making')` — now renders all function values as badges (green=Making, blue=other)
- Investigation: Amendment laws with making_classification=making — legacy Airtable taxa data, largely confirmed correct after LAT parse (only 5/157 flipped in OH&S Occupational)
- Finding: 104 laws with is_making=false still carry 13,444 LAT rows — parsing service bug (should withhold LAT rows for non-making laws)

**Reopened**: 2026-04-21
**Prior Commits**: `613c68e`, `309f53a`, `f97c761`

## Todo (reopened)
- [x] Investigate column visibility/order mismatch on LAT Queue open → library bug
- [x] Raise GH issue: shotleybuilder/svelte-gridlite-kit#28 — `applyConfig()` missing columnVisibility/columnOrder/columnSizing
- [x] Investigate inline edit not persisting in grouped view → library bug
- [x] Raise GH issue: shotleybuilder/svelte-gridlite-kit#29 — grouped view rows are static snapshots, optimistic mutations don't update UI

## Notes (reopened)
- Column panel shows "VISIBLE 13" but toolbar badge shows "Columns 6" — stale internal state in GridLite
- Root cause: `columnVisibility` inits as `{}`, `columnOrder` reads config once at init, `applyConfig()` doesn't handle column state
- Fix goes in library `GridLite.svelte` — extend `applyConfig()` to accept column layout options
- Inline edit bug: `executeGroupDetail()` in adapter returns one-shot `toArrayWhenReady()` snapshots stored in `groupData.children` — no `subscribeChanges()` like flat mode has. Edits persist to backend/PGLite but UI never re-renders.

**Ended**: 2026-04-21
**Commits**: None (investigation + GH issues only)
