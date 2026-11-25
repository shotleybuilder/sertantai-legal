---
session: 'Extent reader: Agreement with the Feed'
status: closed
opened: '2026-10-28'
closed: '2026-11-25'
outcome: deferred
summary: >
  Superseded by the Extent reader readiness review (2026-11-25). The like-for-like figure was measured there from the stored claims, on every text change in every family: the law's bound and the feed's effect extent agree on 89% of the 35,322 changes where both speak. Jason then decided the feed comes first where it speaks (RULES `extent-feed-first-where-it-speaks`, Evidence #202). The agent rounds were dropped: no agent QA in a step (2026-11-13).
decisions:
  - what: Closed as superseded
    why: the measure was taken in the readiness review; agent checks are no longer run in a step
    result: the yardstick by coverage goes into the step procedures session
lessons: []
bugs: []
artifacts:
  - backend/data/reports/extent-reader/readiness/feed-vs-law.md
depends_on:
  - 2026-11-23-extent-reader-readiness-review
enables:
  - "Extent reader: step procedures"
parent: archive/change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: Extent reader: Agreement with the Feed (CLOSED)

## Problem

CV-S05's quality statement rests on agent samples of the extent reader. It has no agreement figure against legislation.gov.uk, which CV-S06's revised check gave the amending-law reader (operation 99.5%, level 99.2%). The extent reader's bound on each change (`law_text.extent`) can be compared like for like with the feed's `effect_extent` / `territorial_application` over every change where both are stated, so its disagreements are found in full rather than sampled. This was moved here from CV-S05f (2026-10-28). That session's aim was target-named statements; this measure covers the whole reader.

## Todo

- ⬜ Define like for like: the bound (where the change can apply) against the feed's effect extent, not its application; which feed values compare (placeholders, "E+W+S+N.I." spellings: `Readers.Feed`)
- ⬜ Measure (read-only, seconds): over OH&S changes with both values, the agreement rate, and the disagreements and changes with no feed extent as strata
- ⬜ Agents on the disagreements in full, and on a seeded sample of the no-feed-extent changes (`extent-reader-check` skill prompt); pass rule decided before the run (CV-S06 model)
- ⬜ Add the figure to CV-S05's quality statement

## Dependencies

- ✅ CV-S05 Extent and application reader (closed)
- ✅ CV-S05f Target-named extent statements (target bounds stored)

## Close (2026-11-25)

Measured in `2026-11-23-extent-reader-readiness-review.md` (todo 2): agree 31,441 of 35,322 where both speak; the law wider 3,114, narrower 706, disjoint 61. The figure is printed from code in `2026-11-25-extent-reader-step-procedures.md` (the feed yardstick).
