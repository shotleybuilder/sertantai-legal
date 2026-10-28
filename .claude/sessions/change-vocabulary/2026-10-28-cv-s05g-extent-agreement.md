---
session: 'CV-S05g: Extent Agreement Measure'
status: pending
opened: '2026-10-28'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
depends_on:
  - change-vocabulary/2026-10-22-cv-s05-extent-reader.md
  - change-vocabulary/2026-10-28-cv-s05f-target-named-extent.md
---

# Session: CV-S05g: Extent Agreement Measure (PENDING)

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
