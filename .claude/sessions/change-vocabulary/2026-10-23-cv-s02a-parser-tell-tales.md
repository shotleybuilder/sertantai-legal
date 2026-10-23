---
session: CV-S02a Parser tell-tales
status: pending
opened: 2026-10-23
---

# Session: CV-S02a Parser tell-tales (PENDING)

## Problem

The CV-S02 feed-reader check senses markup faults the LAT parse passes on faithfully. Jason (2026-10-23): they are raised against the parser, fixed in this sub-session straight after CV-S02, as general patterns, never as one-law fixes. Then back to the workflow (CV-S03).

## Todo

- ⬜ #182: a non-breaking space in EU section_ids (639 rows, 15 laws); the spelling is unstable within a law. Name from the number, normalised.
- ⬜ #183: CLML structure faults sensed as diagnostics (ids that contradict their nesting: 27 elements in 4 laws; levels skipped: 14 in 3 laws); decide one general repair rule, if any.
- ⬜ What good looks like, agreed with Jason before building.
- ⬜ Re-parse plan for the affected laws only: dry run → Jason → restore point → apply; tell fractalaw (renamed rows).

## Dependencies

- ⬜ CV-S02 Feed reader closed (PASS)
