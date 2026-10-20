---
session: "AR-11: Feed Effects on a Provision Range"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-11: Feed Effects on a Provision Range (PENDING)

## Problem

A feed effect on a range ("s. 71 - 80 (Pt. 8) substituted by s. 7 Sch. 4 Pt. 1", EReA 1999 on ERA 1996) reaches only the range's first section (s.71) and the Part row via the note; ss.72–80 (~130 rows, markup in force) carry no label (AR-05 trace, open bug; `ChangeCollector.Feed` / `EffectIndex`).

## Todo

- ⬜ Count feed effects whose affected provision is a range, and the rows each reaches today
- ⬜ Expand the range to every section in it (`LatRef` ranges, as the evaluator does) — tests first
- ⬜ Pilot on ERA 1996 + the counted laws; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)
