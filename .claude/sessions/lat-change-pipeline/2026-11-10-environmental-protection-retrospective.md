---
session: 'Environmental Protection: Retrospective'
status: pending
opened: 2026-11-10
family: '💚 ENVIRONMENTAL PROTECTION'
---

# Session: Environmental Protection: Retrospective (PENDING)

## Problem

Jason (2026-11-10, after the Amending-law reader step and its parked bugs took a whole day): "we've spent all day on amending-law reader step for 1 Family. ~50 Families. About 10 steps." At a day per step, about 50 families × 10 steps is a year and a half. This retrospective runs when Environmental Protection is switched over, before the review tooling session. It decides how the pipeline runs for the families still to come. The meta session's step rows hold each step's figures.

## Todo

- ⬜ Measure each Environmental Protection step: days, runs, re-reads, fixes, and which fixes were general (reaching other families' laws) or family-specific
- ⬜ Decide the way of working for the remaining families (Decisions for Jason, below)
- ⬜ Record the decisions in WORKFLOW ("Running a new family") and the meta session; order the review tooling session after
- ⬜ Housekeeping from the family: stale caches, parked bugs by step, reports

## Preliminary conclusions (from the Amending-law reader, 2026-11-10)

**Where the day went:**
1. **The fixes were general.** Every class fixed was general and reached every family's laws: an Order's articles, a Schedule's paragraphs, ranges, list items, repeals-table items, quotes numbered in titles. Each was found by reading one family's groups by hand.
2. **Version cascades.** Shared modules (`amending_law/text.ex`, `doc.ex`) sit in 5–8 reader versions. Each edit staled every amendment, commencement and extent rule, so a warning fix and an architecture-test fix forced four extra corpus re-reads (about 30 min each). Commencement re-reads then needed `--effects`, orders, title searches and fetches.
3. **Rebuilt tooling.** Group dumps, field diffs, naming and run chains were written again by hand, with fresh slips: a path error, a pgrep wait loop.
4. **Hand review of by-design groups.** Most of 280 groups were "legislation.gov.uk holds no record", by design.
5. **One run at a time.** Each write was its own question to Jason.

**Changes to decide:**
- **A. Readers fixed across the corpus, not per family.** Each reader's gate runs over every family's laws at once, reviewed by class with the widest first; a class found in one law is fixed for all. A family's step then becomes its gates plus naming the few new groups: about an hour, not a day. This turns about 500 family-step sessions into about 10 corpus-wide reader rounds plus a short gate per family.
- **B. By-design groups named by rule.** The tool applies the standard statuses. A human reads only the misread causes: operation and level conflicts, and quote-dropped repeals by law.
- **C. One approved round per step.** The fix batch is approved once, then one scripted round runs: restore point, reads, re-reads, rebuilds, golden, tests, overnight where needed.
- **D. Untangle the versions.** Split the shared amending-law document readers so an amendment-only reading change does not stale commencement and extent rules. Run `mix compile --warnings-as-errors` and the architecture tests before any read pass.
- **E. The review tooling** (`2026-11-10-amending-law-reader-review-tooling.md`) is built after this retrospective, shaped by A–D.

## Dependencies

- ⬜ Environmental Protection switched over (Merge, Evidence, Label fold, Measures, Store and build, Labels side by side, Switch-over)
