---
session: 'LR-30: Undated Inserted Ancestor'
status: closed
opened: '2026-10-15'
closed: '2026-10-15'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'A provision whose own insertion, or an ancestor''s, no source dates no longer takes the law''s start: its start is unknown and listed as a gap (J5 extended); a dated ancestor insertion now starts
  its children. Applied in the LR-25 wave: 1,162 provisions in force → unknown.'
decisions:
- what: J5 extends to undated inserted ancestors; prospective insertions keep their reading
  why: 'Jason 2026-10-15: agreed; ''in force since 1968'' for a later-inserted [S] version was wrong'
  result: 1,162 rows honest unknowns; one LR-24 test expectation (1990/43 s.78B(2)) corrected
- what: A dated ancestor insertion starts the row
  why: the row came with its parent
  result: children no longer take the law's start before their parent existed
metrics:
  wave:
    in_force_to_unknown: 1162
    future_dated_parent: 72
  register_undated_insertions:
    markup: 6537
    law: 531
    prospective_effects_excluded: 1966
lessons:
- title: An old test can encode the bug it was written near
  detail: LR-24's 1990/43 s.78B(2) test expected 'in force since 1991' for a provision inserted in 1995; its point (never prospective) survives, its date was the error.
  tag: data
bugs:
- pattern: A row under an ancestor whose insertion no source dates (change markup 'inserted', no effect, no law record) takes the law's start (J1) as if its text existed from then (1968/73 s.10(1)(i)[S]
    reads in force since 1968; its [S] version was inserted later)
  category: lat-timeline
  module: LabelProjection J1 / J5 (LR-24)
  affected: 1,162 provisions in force → unknown in the wave (plus 72 under a future-dated parent insertion)
  fix: 'extend J5: a row whose own insertion, or an ancestor''s, no source dates never takes the law''s start — its start is unknown (:insertion_not_in_register), as a note-pointed insertion already is'
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/label_projection.ex
- backend/test/sertantai_legal/scraper/label_projection_test.exs
depends_on:
- 2026-10-13-lr-24-label-projection
- 2026-10-15-lr-29-container-ref-overreach
enables:
- A8 gap classes (insertion_not_in_register)
---

# Session: LR-30 Undated Inserted Ancestor (CLOSED)

## Problem

Found in the LR-29 verification of the LR-25 dry run (2026-10-15):
- **The provision:** Transport Act 1968 s.10(1)[S] is a Scotland version. Its change markup marks it inserted, but no effect or law record dates the insertion.
- **What the timeline says:** its sub-provision s.10(1)(i)[S] gets the Act's start, 1968-10-25, as if its text had existed since then.
- **Why it hadn't shown:** LR-27's container over-reach gave it a wrong 2009 date instead. LR-29 removes the over-reach and exposes the gap.

Rule J5 already withholds the law's start from a row a note points to as inserted. Rows under an undated inserted ancestor need the same.

## Todo

- ✅ Measured in the final dry runs: 1,162 in force → unknown (LR-30), 72 future-dated parent insertions
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
- ✅ Counted in the final dry run: 1,162 provisions in force → unknown confirmed as LR-30; plus 72 whose parent's insertion is dated in the future (no period before the start, J1)
- ✅ Landed in the LR-25 wave (2026-10-15)

## Dependencies

- ✅ LR-24 (J1, J5); LR-29 (over-reach removed)
