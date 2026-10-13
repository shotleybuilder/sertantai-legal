---
session: 'LR-24: Label Projection'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-24 Label Projection — When (ACTIVE)

## Problem

Row change labels (`effective_from`, `changed_by`, the change part of `status`, `change_provenance`) are computed inside the LAT parse (`ChangeFacts.row_facts`). LR-22 makes them a pure projection of `lat_change_log`. The rules: the row's own changes and its ancestors' whole-provision changes; the latest dated change; the authority order (law > derived data > auto-derived > editorial, never notes); each label linked to its change ids. Recomputed by `mix lat.relabel` without re-parsing LAT.

## Todo

- ✅ Measure first: rows whose `effective_from` today comes from a modification / application rather than a text change
- ⬜ Jason: what `effective_from` means (since when the current text has had effect; modifications excluded), what each operation contributes to status, and what whole-instrument effects (LR-23 D5) mean for a row (LR-22 Q2)
- ⬜ Golden test cases: rows with known change histories (effective_from, changed_by, status, change ids), scrubbed of `key-` ids
- ⬜ `LabelProjection` (pure) from change-log records; status contributions to `LatStatus` with no note text
- ⬜ `mix lat.relabel --laws|--all --dry-run`: offline diff against today's labels, classified (expected: effect labels equal; the 14,709 note-sourced labels empty)
- ⬜ Gap queries: rows with a note pointer and no change; changes with no date; changes resolving to no row
- ⬜ Gemini acceptance

## Dependencies

- ✅ LR-23 table filled (closed 2026-10-13: 132,965 records, view `lat_change_log_rows` exact)
- ✅ LR-22 the two questions (where, when); authority order law > derived data > auto-derived > editorial

## Measure: what dates a row today (2026-10-13)

Every row with an `effective_from` (233,114). Its date and changed_by were matched to the register's changes on the row or its ancestors (`lat_change_log_rows`, excluding whole-instrument joins, which today's labels don't use). Scripts: scratchpad `lr24_measure.exs`, `lr24_nomatch.exs`.

| Today's label source | Dated by | Rows |
|---|---|---|
| effect | text change (substituted, inserted, repealed, renumbered, amended) | 107,721 |
| effect | commencement | 105,060 |
| effect | modification / application | **248** |
| effect | no matching change in the register | 8,716 |
| note | no matching change | 10,629 |
| note | commencement / text change / modification | 315 / 288 / 137 |

**Modifications barely date rows today:** 385 rows (0.2%). The worry in the sense check is real in principle but small in practice. Dates come from text changes and commencement in roughly equal shares.

**The 8,716 effect-labelled rows with no matching change** (300-row sample; scaled estimate):
- **Same law, but the register's change is undated: 123/300, about 3,600 rows.** Today's date came from the note's text and was labelled `effect`. This is LR-20's provenance mislabel (note dates shown as effect), still open, now measured. Under the projection these rows lose their date.
- **A whole-instrument change by the same law on that date: 112/300, about 3,300 rows.** Today's join reached the row another way (a note's placement); in the register it arrives as a whole-instrument change, for example ssi 2025/165, a commencement order "Regulations". Kept if whole-instrument commencements date rows (decision below).
- **Other laws only: 32/300; same law, another date: 24/300.** Today's spreading of note placement (LR-23's fan-out bug) and pooling.
- **No change on the row or its ancestors: 9/300.** Tables and inserted regulations.
