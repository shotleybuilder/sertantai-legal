---
session: 'LR-32: One Territory''s Change Dating Another''s Version'
status: pending
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

# Session: LR-32 One Territory's Change Dating Another's Version (PENDING)

## Problem

Found while checking why some labels changed between LR-25 dry runs 3 and 5 (2026-10-15).

Environment Act 1995 s.114(2)(a)(ix) has an [E+W] and an [S] version, both with the xml id `section-114-2-a-ix`. On 2006-04-01:
- the Water Act 2003 inserted the E+W text (markup on the [E+W] row);
- ssi 2006/181 inserted the S text. Its ref reaches both versions.

The E+W version's changed-by depended on which of the two came first: a same-day tie. The tie-break (LR-29) now picks a stable answer, the right one here, but only by law-name order. The real rule should stop a change for S dating an E+W version.

## Todo

- ⬜ Measure: version rows with dated changes whose extent doesn't cover the version
- ⬜ **Jason: D1** — rule (recommended: extend `covers_row?` from repeals to all text changes in version selection)
- ⬜ Tests first; lands with the LR-25 wave

## Dependencies

- ✅ LR-26 (territory per period; `covers_row?`)
