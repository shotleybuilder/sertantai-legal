---
session: "AR-11: Feed Effects on a Provision Range"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-11: Feed Effects on a Provision Range (ACTIVE)

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
