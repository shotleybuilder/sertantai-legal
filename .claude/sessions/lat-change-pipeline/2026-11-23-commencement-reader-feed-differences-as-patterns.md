---
session: 'Commencement reader: feed differences as patterns'
status: pending
opened: 2026-11-23
---

# Session: Commencement reader: feed differences as patterns (PENDING)

## Problem

Jason, 2026-11-23 (Commencement reader staleness, Decision 1; RULES `feed-differences-are-patterns-by-feed-coverage`):

- **Where the feed holds a law's commencement** (roughly every law from 2002), the feed is the date, unless the law's own words prove it wrong. Evidence takes the feed unless proven wrong (a handful of feed errors), and then the Reader.
- **Where the feed holds nothing,** the Reader is the source of truth.
- **So a feed difference is a pattern,** as in our catalogues, to be looked for in the laws without feed data:
  - held by them: the Reader's to fix;
  - found only where the feed speaks: a known limit for the Reader, and the feed is used.
- **The cut is practical:** does legislation.gov.uk's feed give the data for the law?

Today the 28 statuses in `feed_differences.json` are judged law by law ("one-law wordings"), with no look at the laws only the Reader reads. So the Reader risks growing more complex than the data requires, or missing a pattern where it alone speaks.

## Todo

- ⬜ Plan (plan mode): the coverage cut in code (which laws' commencement the feed holds, from the stored feed), the pattern form, pass rule, time box
- ⬜ The coverage cut: each law with LAT marked feed-covered or not, from the Feed reader's stored record; counts per family
- ⬜ Each difference group as a catalogue pattern (the own-clause and orders catalogues' forms), with its laws counted by coverage
- ⬜ Re-judge today's entries: held without feed data → `fix:` (Commencement reader); feed-covered only → known limit, feed used; dry run, then written on Jason's go
- ⬜ Check the build follows it: Evidence takes the feed unless a proven feed error (Jason 2026-11-23), against RULES §7 `primary-first-derived-fills` (law text first); reconcile the rule text or the code, tests first
- ⬜ The check prints the coverage split: differences on feed-covered laws vs patterns reaching laws without feed data
- ⬜ Close: RULES `feed-differences-are-patterns-by-feed-coverage` completed (its code and test); the Extent readiness review asks the same of the Extent reader

## Dependencies

- ⬜ Commencement reader staleness closed (owners in `feed_differences.json`)
- ⬜ Commencement reader: split the order reader closed (a fix lands in the split modules)
