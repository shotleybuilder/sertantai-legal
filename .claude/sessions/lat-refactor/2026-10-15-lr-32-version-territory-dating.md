---
session: 'LR-32: One Territory''s Change Dating Another''s Version'
status: active
opened: 2026-10-15
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Extent versions of a provision share an xml id ([E+W] and [S] versions both section-114-2-a-ix), so a ref join reaches every version; an effect for one territory (ssi 2006/181, S) can date the other territory's version (1995/25 s.114(2)(a)(ix)[E+W])"
    category: lat-timeline
    module: Feed ref joins / LabelProjection version selection
    affected: "to measure (found in the LR-29 dry run 5 check, 2026-10-15)"
    fix: "a change whose extent (effect extent / territorial application) is disjoint from the row version's extent doesn't date that version (LabelProjection.covers_row? already does this for repeals)"
    status: open
---

# Session: LR-32 One Territory's Change Dating Another's Version (ACTIVE)

## Problem

Found while checking why some labels changed between LR-25 dry runs 3 and 5 (2026-10-15).

Environment Act 1995 s.114(2)(a)(ix) has an [E+W] and an [S] version, both with the xml id `section-114-2-a-ix`. On 2006-04-01:
- the Water Act 2003 inserted the E+W text (markup on the [E+W] row);
- ssi 2006/181 inserted the S text. Its ref reaches both versions.

The E+W version's changed-by depended on which of the two came first: a same-day tie. The tie-break (LR-29) now picks a stable answer, the right one here, but only by law-name order. The real rule should stop a change for S dating an E+W version.

## Todo

- ⬜ Measure: version rows with dated changes whose extent doesn't cover the version
- ✅ **Jason: D1** (2026-10-15): agreed — `covers_row?` for all text changes in version selection
- ✅ Built test-first (2026-10-15), `LabelProjection.for_row?/2`. A change dates a row (version selection, insertion start, LR-30's undated check) unless its territory (territorial application, else effect extent) is **disjoint** from the row's.
  - **Refined from "covers_row?":** covering would wrongly drop an E-only amendment to an E+W provision, which does change its text. Jason's rule is "a change for one territory never dates another territory's version", i.e. disjoint.
  - Repeals keep `covers_row?` (LR-26 narrows the territory).
  - Tests: 1995/25 s.114(2)(a)(ix)[E+W] dated by the Water Act 2003, not ssi 2006/181, and not moved by a later S substitution; an E-only change still dates an E+W provision. Suite 2,677.
- ⬜ Lands with the LR-25 wave; counted in the final dry run

## Dependencies

- ✅ LR-26 (territory per period; `covers_row?`)
