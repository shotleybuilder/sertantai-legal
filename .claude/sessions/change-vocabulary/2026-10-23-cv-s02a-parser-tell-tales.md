---
session: CV-S02a Parser tell-tales
status: active
opened: 2026-10-23
---

# Session: CV-S02a Parser tell-tales (ACTIVE)

## Problem

The CV-S02 feed-reader check senses markup faults the LAT parse passes on faithfully. Jason (2026-10-23): they are raised against the parser, fixed in this sub-session straight after CV-S02, as general patterns, never as one-law fixes. Then back to the workflow (CV-S03).

## Todo

- ⬜ What good looks like, agreed with Jason before building.
- ⬜ #182: a non-breaking space in EU section_ids (639 rows, 15 laws); the spelling is unstable within a law. Name from the number, normalised.
- ⬜ #183: CLML structure faults sensed as diagnostics (ids that contradict their nesting: 27 elements in 4 laws; levels skipped: 14 in 3 laws); decide one general repair rule, if any.
- ⬜ #184: numbered items with no id get no row (1,652 ListItems in 114 laws; CLP Art. 2's definitions, REACH Art. 57 points)
- ⬜ #185: row names with doubled brackets, `art.Article 77(2)((e))` (79 rows in 9 laws)
- ⬜ Note: `ParserVersion` already moved with CV-S02 NEW-D (`ChangesFeed` reads lowercase "other"); the re-parse plan covers it
- ⏸️ The shared namer (`Commencement.Order.ref/1`) drops nested schedule ids: `schedule-N-part-P-paragraph-M` → `sch.N.pt.P`; unnumbered `schedule-paragraph-1` → `sch.paragraph`. 48 collisions in the family's feeds, none in the body (CV-S02 NEW-C). Deferred until schedules are parsed (no schedule rows in v0.1); fix it with the schedule naming decision
- ⬜ Re-parse plan for the affected laws only: dry run → Jason → restore point → apply; tell fractalaw (renamed rows).

## Dependencies

- ✅ CV-S02 Feed reader closed PASS (2026-10-23)
