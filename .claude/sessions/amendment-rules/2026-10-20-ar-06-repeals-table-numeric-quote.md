---
session: "AR-06: Repeals-Table Line Quoting a Number"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-06: Repeals-Table Line Quoting a Number (PENDING)

## Problem

A repeals-table line quoting a number only ("In section 53(1)(a) “114”.", 1991 c.34 Sch 19 on 1982 c.16) is read as a whole-provision repeal, not words (AR-03 open bug; `Amendment.Reader.repeal_table`).

## Todo

- ⬜ A repeals-table line whose quote is a number reads as words-level (reader test first)
- ⬜ Count the rules it changes (`mix lat.amending --read` on the affected laws); batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
