---
session: 'LR-15: changed_by Gaps on Change Notes'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "changed_by null when the note cites a bare SI number ('by 2002/794', 'SI 1992/2823') the register holds, no Citation markup, no effect"
    category: lat-change-facts
    module: AmendmentNote / ChangeFacts note fallback
    affected: 22 notes / 3 laws
    fix: "resolve bare YYYY/NNN against the register by the note law's series"
    status: open
---

# Session: LR-15 changed_by Gaps on Change Notes (PENDING)

## Problem

200 change notes in 69 laws name the changing law in their text but have no `changed_by`:
- 101 (13 laws): the law changes itself — null by design (`ChangeFacts.not_self`);
- 4: "as inserted by" chains and the uksi/wsi twin 2018/647 (twin → LH-07);
- 95 (57 laws): no Citation markup and no matching effect, so only the note's text names the law:
  - 22 (3 laws) cite a bare SI number the register holds ("by 2002/794", "SI 1992/2823");
  - 73 name laws legal doesn't hold (e.g. General Rate Act 1967, Water Consolidation (Consequential Provisions) Act 1991).
EU "by Regulation (EC) No …" notes (LH-08): 32 now; the 11 with no changed_by are Official Journal footnotes or editorial notes — correct.

## Todo

- ⬜ Tests first: bare "YYYY/NNN" and "SI YYYY/NNN" after " by " resolve against the register in the note law's series
- ⬜ Fix in the note fallback; classified diff: only the 22 notes change
- ⬜ Re-parse the 3 laws: dry run → Jason → apply

## Decisions for Jason

- **D1 — Fix** the 22 resolvable notes
- **D2 — Known limit** for the 73 whose changing law legal doesn't hold (and the 101 self-changes, by design)

## Dependencies

- ✅ LR-06 wave 4 applied and verified
