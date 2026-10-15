---
session: 'LR-30: Undated Inserted Ancestor'
status: pending
opened: 2026-10-15
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "A row under an ancestor whose insertion no source dates (change markup 'inserted', no effect, no law record) takes the law's start (J1) as if its text existed from then (1968/73 s.10(1)(i)[S] reads in force since 1968; its [S] version was inserted later)"
    category: lat-timeline
    module: LabelProjection J1 / J5 (LR-24)
    affected: "1,945 rows in 96 laws (stored register, 2026-10-15)"
    fix: "extend J5: a row whose own insertion, or an ancestor's, no source dates never takes the law's start — its start is unknown (:insertion_not_in_register), as a note-pointed insertion already is"
    status: open
---

# Session: LR-30 Undated Inserted Ancestor (PENDING)

## Problem

Found in the LR-29 verification of the LR-25 dry run (2026-10-15):
- **The provision:** Transport Act 1968 s.10(1)[S] is a Scotland version. Its change markup marks it inserted, but no effect or law record dates the insertion.
- **What the timeline says:** its sub-provision s.10(1)(i)[S] gets the Act's start, 1968-10-25, as if its text had existed since then.
- **Why it hadn't shown:** LR-27's container over-reach gave it a wrong 2009 date instead. LR-29 removes the over-reach and exposes the gap.

Rule J5 already withholds the law's start from a row a note points to as inserted. Rows under an undated inserted ancestor need the same.

## Todo

- ⬜ Measure precisely (1,945 rows / 96 laws by section-id ancestry; classify)
- ⬜ **Jason: D1** — the rule (recommended: J5 extends to undated inserted ancestors; start unknown, listed as a gap)
- ⬜ Tests first; lands with the LR-25 wave (timeline rebuild only)

## Dependencies

- ✅ LR-24 (J1, J5); LR-29 (over-reach removed)
