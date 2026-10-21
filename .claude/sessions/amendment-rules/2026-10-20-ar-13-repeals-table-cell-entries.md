---
session: "AR-13: Repeals-Table Cells with Several Entries"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-13: Repeals-Table Cells with Several Entries (ACTIVE)

## Problem

A repeals-table cell listing several entries ("In section 117, …. Section 118(2) and (3). Section 120(2). … Section 125. …") is read as its first entry only — EReA 1999 Sch 9 on ERA 1996: 5 cells, ~40 entries → 5 rules (AR-05 trace, open bug; `Amendment.Reader.repeal_table`).

## Todo

- ⬜ Count repeals-table cells with more than one entry across the stored rules' sources
- ⬜ Split a cell into its entries, one rule each (reader tests first)
- ⬜ Read-pass the affected amending laws; pilot; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-05 trace (2026-10-20)
