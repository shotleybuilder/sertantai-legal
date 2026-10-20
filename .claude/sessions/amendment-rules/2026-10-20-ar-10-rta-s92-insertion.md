---
session: "AR-10: RTA 1988 s.92 Insertion Recheck"
status: pending
opened: '2026-10-20'
parent: amendment-rules/2026-10-19-ar-00-meta.md
---

# Session: AR-10: RTA 1988 s.92 Insertion Recheck (PENDING)

## Problem

RTA 1988 9 rows: in_force_from moved 1992-07-01 → 1988-11-15 when an undated "insertion of s.92" by RTA 1991 was no longer read (LR-41 open bug, module `AmendingLaw.Target` — deleted by AR-04); s.92(1)'s 2009 words substitution never dates it. Recheck under the ruleset.

## Todo

- ⬜ Recheck on the ruleset: what RTA 1991's s.92 instruction reads as (`mix lat.amending --law UK_ukpga_1991_40`) and what the 9 rows carry today
- ⬜ Fix at source if still wrong (reader or commencement), or close as fixed by AR-03/04

## Dependencies

- ✅ AR-04 switch-over (the collector on stored rules)
