---
session: 'LR-30: Undated Inserted Ancestor'
status: active
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

# Session: LR-30 Undated Inserted Ancestor (ACTIVE)

## Problem

Found in the LR-29 verification of the LR-25 dry run (2026-10-15):
- **The provision:** Transport Act 1968 s.10(1)[S] is a Scotland version. Its change markup marks it inserted, but no effect or law record dates the insertion.
- **What the timeline says:** its sub-provision s.10(1)(i)[S] gets the Act's start, 1968-10-25, as if its text had existed since then.
- **Why it hadn't shown:** LR-27's container over-reach gave it a wrong 2009 date instead. LR-29 removes the over-reach and exposes the gap.

Rule J5 already withholds the law's start from a row a note points to as inserted. Rows under an undated inserted ancestor need the same.

## Todo

- ⬜ Measure precisely (1,945 rows / 96 laws by section-id ancestry; classify)
- ✅ **Jason: D1** (2026-10-15): agreed — J5 extends to undated inserted ancestors
- ✅ Built test-first (2026-10-15), `LabelProjection`:
  - **The start (J1).** A row's insertion date is its own, else its nearest inserted ancestor's (it came with that ancestor). Was: own only, so children of a dated insertion took the law's start.
  - **Withholding the law's start.** It is withheld when the row or an ancestor has an insertion no source dates (change markup or the amending law's record, never dated, and no dated insertion on the row or above). It becomes the `insertion_not_in_register` gap, as J5's note pointer already does.
  - **Not covered:** prospective insertions (not yet in force) keep the approved reading, prospective from the law's start (1996/18 s.201(1)).
  - **Undated insertions in the register, by kind:**
    - markup 6,537 and law records 531, which the rule covers;
    - prospective effects 1,966, which it does not.
  - **One LR-24 expectation changed:** 1990/43 s.78B(2), inserted by the Environment Act 1995 on an undated day, had expected "in force since 1991" (the law's start). It now has no start, listed as a gap. Still never prospective, the test's original point.
  - Tests: 3 new plus the 1 changed; suite 2,675.
- ⬜ Lands with the LR-25 wave (timeline rebuild); counted in the final dry run

## Dependencies

- ✅ LR-24 (J1, J5); LR-29 (over-reach removed)
