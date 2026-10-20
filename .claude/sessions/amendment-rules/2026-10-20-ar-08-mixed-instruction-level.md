---
session: "AR-08: Mixed Instruction Level"
status: active
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-08: Mixed Instruction Level (ACTIVE)

## Problem

A mixed instruction ("omit “and Wales” and after paragraph (b) insert—", 1994 c.19 Sch 9 para 17) labels the inserted paragraph words-level: one level for two operations (AR-03 open bug; `Amendment.Reader`).

## Todo

- ⬜ Split a mixed instruction into one rule per operation, each with its own level (reader test first)
- ⬜ Mixed repeals-table lines (left by AR-06): words beside a named provision ("the definitions of …; and subsection (2)") — one target per operation, each at its own level
- ⬜ Pilot on a few amending laws (re-read, wave preview); prove it changes output, 0 losses
- ⬜ Count the rules it changes; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
- ✅ AR-06 (repeals-table words lines) and AR-07 (targets that name no row) closed
