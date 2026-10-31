---
session: 'CV-06: Switch-over and Measure'
status: pending
release: v0.1
opened: '2026-10-21'
parent: change-vocabulary/2026-10-21-cv-00-meta.md
---

# Session: CV-06: Switch-over and Measure (PENDING)

## Problem

Part of the change-vocabulary architecture shift (CV-00): corpus dry run against v01_final, classified; acceptance cases (SI 2010/404 reg.14, Forestry Act 1967, Coronavirus Act 2020 s.78, SI 2016/1105 reg.72(2)(b), TCPA 1990 s.78(4BA)); known limits; into the v0.1 re-parse and relabel.

## Todo

- ⬜ Shadow runs: new labels against today's and `v01_final`, per provision, every difference classified
- ⬜ From CV-05: start from its T baseline (OH&S 16,487 of 20,371 rows differ; `lat.label_check --strata`)
- ⬜ From CV-05: the writer — `LabelRefresh` takes `LabelSource.timeline/1` behind one setting; migration for `changed_by_all`, `commenced_by` (Jason 2026-10-31: add, don't replace)
- ⬜ From CV-05: the four gaps (J6 by-order rows, J4 pending/unapplied, no gap list, headings/signatures unfolded) and the old-table reads (law start, `lat.commencement --orders`) — `backend/data/reports/change-vocabulary/cv-05-retirement-list.md`
- ⬜ Consumers switched one at a time (labels, then the parse's territory); restore points
- ⬜ Old tables and rules removed once the shadow diff is explained
- ⬜ Dry run → Jason → restore point → the v0.1 re-parse and one relabel (V1-00)

- ⬜ The switch from `lat_change_log` to `provision_changes` is reversible: one setting selects the register the projection reads (Gemini CV-04 storage review)

## Dependencies

- ✅ CV-S01–S11 passed (S11 closed 2026-10-31; S12 Retrospective comes after CV-06)

- ✅ CV-01 signed off by Jason
- ✅ CV-05 closed (2026-10-31)
