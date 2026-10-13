---
session: 'LR-27: Text-only Effect Refs'
status: pending
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Feed effects whose affected provision is given only as text ('Part 2B inserted', no AffectedProvisions refs) reach no LAT row, so the rows of an inserted Part have no dated insertion"
    category: effect-join
    module: ChangeCollector.Feed / EffectIndex (affected_provisions text → rows)
    affected: "25 unreached Part/Chapter effects; behind most of LR-24 J5's 7,157 rows in 144 laws (1996/18 Pt. 2B, ss. 27U-27Y, inserted by 2023/13)"
    fix: "Resolve affected_provisions text naming a Part / Chapter / cross-heading to its LAT rows (the rows' part / chapter / heading_group), join via ref; re-collect; the J5 rows then take their insertion date from the effect"
    status: open
---

# Session: LR-27 Text-only Effect Refs (PENDING)

## Problem

Some changes-feed effects give their affected provision only as text, with no structured `AffectedProvisions` refs. Example: 2023/13 "Part 2B inserted" into the Employment Rights Act 1996 (ss. 27U–27Y). The collector joins by structured refs, ranges, markup and note pointers, so such an effect reaches no row and sits in `lat_change_log` as a gap. The inserted provisions then have no dated insertion, and LR-24 (J5) leaves their start unknown rather than guess. This session makes those effects reach their rows. Pre-2002 insertions the feed doesn't record at all are LR-08's.

## Todo

- ⬜ Measure: unreached effects naming a Part / Chapter / cross-heading / Schedule Part as text only; the LR-24 J5 rows they would date
- ⬜ Tests first: "Part 2B" → the rows of Part 2B (1996/18); "Pt. 3 Ch. 1A"; nothing for a Part LAT doesn't hold
- ⬜ Collector: resolve the text to the rows (via `ref`); fidelity gate; re-collect (dry run → Jason → apply)
- ⬜ Timeline rebuilt: J5 gaps that now have a date

## Dependencies

- ✅ LR-23 register; ⬜ LR-24 timeline filled
