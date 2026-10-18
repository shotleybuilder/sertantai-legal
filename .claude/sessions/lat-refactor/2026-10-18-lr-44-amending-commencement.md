---
session: 'LR-44: Dating Amending Provisions'
status: active
opened: '2026-10-18'
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-44 Dating Amending Provisions (ACTIVE)

## Problem

The amending-law collector finds the change but can't date it: the amending provision's own commencement is by order or unread, and hop 2 (the commencing orders the note names, `CommencingOrder`) finds no date (LR-40 cause 5: 2,405 records undated, 1,057 partial only; after LR-41 most new records stall here — sample: 47 reach a record, 6 dated). The benchmark also shows the dates it does find differ from the feed's in 854 cases (Water Act 2014: England 2017 vs Wales 2019). Jason 2026-10-18: commencement before block changes (LR-43).

## Todo

- ⬜ Size after the LR-41/42 relabel: undated amending-law records by cause — commencement by order with no order named / order not held / order held but no date read / partial only / amending SI (its own start: `LawStart`)
- ⬜ Trace a sample of "order held, no date read"
- ⬜ D1 per cause (Jason)
- ⬜ Build, tests, dry run, benchmark (date differs down), apply

## Dependencies

- ✅ LR-41/42 (records reach this stage); LR-33 `LawStart` (an amending SI's start)
