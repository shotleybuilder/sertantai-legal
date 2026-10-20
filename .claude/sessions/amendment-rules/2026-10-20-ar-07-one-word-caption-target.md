---
session: "AR-07: One-Word Caption Read as a Target"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-07: One-Word Caption Read as a Target (PENDING)

## Problem

A one-word caption ("(interpretation)") becomes a bracket target (`s.336(interpretation)`) that matches no row — harmless today, but a rule naming a row that cannot exist (AR-03 open bug; `Amendment.Reader.brackets`; 10+ rules).

## Todo

- ⬜ With it: spurious targets from a quote's own numbers (s.99(99), s.47B(47C), s.88(c), s.i — AR-05 trace, EReA 1999 on ERA 1996)
- ⬜ A bracket holding a word (not a number or letter) is never a target (reader test first)
- ⬜ Count the rules it changes; batch into the AR measure run

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
