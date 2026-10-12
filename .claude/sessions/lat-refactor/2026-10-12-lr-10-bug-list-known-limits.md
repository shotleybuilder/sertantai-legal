---
session: 'LR-10: Bug List & Known Limits'
status: active
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-10 Bug List & Known Limits (ACTIVE)

## Problem

Plan step 1 (LR-00 meta, 2026-10-12). The open LAT bugs were logged before wave 4, and LH-08's open items were taken over by LR-02 to LR-05 without being reconciled, so no one can say what is still wrong in the data fractalaw will get. Each item is re-measured on the wave-4 dev DB and the CLML store (offline) and ends as **fixed**, **fix now** (test-first, lands in a later targeted wave) or **known limit**. Jason approves the known-limits list, the only things allowed to stay wrong at hand-off and the list QA run 4 classifies against.

## Todo

- ⬜ #165 schedule rows with empty text (Schedule Number/TitleBlock, ScheduleBody lead-in): re-measure
- ⬜ 3,483 provisions ending "insert—/substitute—" with no body; schedules held for 84 of 910 LAT laws: re-measure
- ⬜ 32 notes in 27 laws that hold no LAT: decide (remove, or keep with a reason)
- ⬜ Savings listed + feed silent on territory → read as everywhere (2010/404 reg.14, 2020/7 s.8; 8 rows): fix or known limit
- ⬜ 39 Making laws whose LAT was deleted by the not-Making clean-up: in scope for hand-off?
- ⬜ fractalaw holds stale LAT for revoked laws legal no longer holds (#58 flips): goes into LH-05's message (manifest removals)
- ⬜ 1949/97, 1949/74 marked Revoked; regnal-year name 1961: register, outside LAT — confirm out of scope
- ⬜ LH-08's 12 open items: each matched to the LR fix that closed it, or carried here; close LH-08
- ⬜ Known-limits list → Jason → approved

Out of scope (not LAT): definition parser bugs, fractalaw tree/fitness bugs, AU is_making, the fitness doc.

## Dependencies

- ✅ LR-06 wave 4 applied and verified
