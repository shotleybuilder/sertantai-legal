---
session: "AR-11: Feed Effects on a Provision Range"
status: closed
opened: '2026-10-20'
closed: '2026-10-21'
outcome: success
parent: amendment-rules/2026-10-19-ar-00-meta.md

summary: >
  The AR-05 bug (a feed range reaching only s.71) was a misreading: EffectTarget already expands "s. 71 - 80 (Pt. 8)"
  to 449 rows, stored as one compact record s.71 → s.80(4)(b). The missing ERA ss.72–80 labels come from the effect
  being undated; AR-12's commencement order dates them (preview: 115 of 129 rows in force, 112 from 1999-12-15). No code change.

decisions:
  - what: No AR-11 code change; the ERA rows are labelled by the AR measure run through AR-12
    why: EffectTarget.resolve gives :text with 450 ids; the stored record already spans s.71 → s.80(4)(b) via ref; the gap is a missing date, not a missing reach
    result: ERA relabel preview (ar11_era, no writes) — 115 of 129 ss.72–80 rows unknown → in force

metrics:
  era_range_effect: { resolved_ids: 450, records_rows: 449, via_ref: 448, via_note_cited: 1, compact_records: 2 }
  era_preview_ar11: { rows_ss72_80: 129, unknown_to_in_force: 115, start_1999_12_15: 112, label_diffs_law: 1121 }

lessons:
  - title: lat_change_log is compact — count rows through lat_change_log_rows, never GROUP BY section_id
    detail: 'A range or Part-wide change is one record from section_id to section_id_to (LR-23 D3). The AR-05 trace grouped lat_change_log by section_id, saw only s.71 and logged a reach bug that did not exist; the view lat_change_log_rows expands the runs (449 rows here).'
    tag: data
  - title: A row with records but no label is a date gap before it is a reach gap
    detail: 'ss.72–80 had the record but no period because the effect has no InForce date; check the records reaching a row before suspecting the collector.'
    tag: data

bugs:
  - pattern: 'A feed effect on a range ("s. 71 - 80 (Pt. 8) substituted", EReA 1999 s.7 on ERA 1996) reaches only the range''s first section (s.71) and the Part row via the note; s.72–s.80 get no record'
    category: feed range refs
    module: ChangeCollector.Feed / EffectIndex
    affected: 'none — not a bug: one compact record s.71 → s.80(4)(b) reaches all 449 rows; labels come with AR-12'
    fix: no change (the AR-05 trace misread a compact record)
    status: fixed

artifacts:
  - backend/data/reports/lat-refactor/ar11_era.csv
  - backend/data/reports/lat-refactor/ar11_era.diff.csv

depends_on:
  - 2026-10-19-ar-05-amending-schedule-blocks
  - 2026-10-20-ar-12-commencement-order-schedule

enables:
  - AR measure run (ERA Part VIII rows labelled via AR-12)
---

# Session: AR-11: Feed Effects on a Provision Range (CLOSED)

## Problem

A feed effect on a range ("s. 71 - 80 (Pt. 8) substituted by s. 7 Sch. 4 Pt. 1", EReA 1999 on ERA 1996) reaches only the range's first section (s.71) and the Part row via the note; ss.72–80 (~130 rows, markup in force) carry no label (AR-05 trace, open bug; `ChangeCollector.Feed` / `EffectIndex`).

## Todo

- ✅ Reproduce on ERA 1996: the range already reaches every row — the trace misread a compact record (§1)
- ❌ Expand the range to every section in it — not needed: `EffectTarget` (LR-29/LR-35) already does
- ✅ Why ss.72–80 had no label: the effect is undated; AR-12's order dates them (preview, §2)
- ✅ Nothing to batch: the ERA rows are labelled by the AR measure run through AR-12

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)

## 1. The range is reached (2026-10-21)

The effect (`key-db77b6…`, "s. 71 - 80 (Pt. 8) substituted", EReA 1999 Sch 4 Pt 1) has no `SectionRange`; its refs are `section-71` and `part-VIII`. Its text parses as a range, and `EffectTarget.resolve` gives `:text` with 450 ids from s.71 to s.80(4)(b). The parse of 2026-10-19 has the effect in `effect_ids` on s.72. The collector writes it as **one compact record**: `section_id` s.71, `section_id_to` s.80(4)(b), via `ref` (LR-23 D3). That covers 449 rows; `lat_change_log_rows` expands it to all of them. The AR-05 trace grouped `lat_change_log` by `section_id` and saw only s.71.

## 2. Why the rows had no label

The effect is undated (`RequiresApplied`, no InForce date), so no row in ss.72–80 got a period. The ERA relabel preview (`ar11_era`, no writes, current code) labels 115 of the 129 rows as in force; 112 of those start 1999-12-15. That date is SI 1999/2830's Schedule, which AR-12 reads. So the AR measure run labels these rows; there is no AR-11 code change.
