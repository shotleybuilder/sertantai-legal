---
session: 'Waste, Water and Climate: Commencement reader retrospective'
status: pending
opened: 2026-11-23
family: Waste, Water and Climate (round)
step: Commencement reader
---

# Session: Waste, Water and Climate: Commencement reader retrospective (PENDING)

## Problem

The Commencement reader step for the Waste, Water and Climate round ran four days (2026-11-20 to 23), with a day's suspension for a code review, 21 decisions, 20 Fable fixer calls (about 1.9M tokens) and three round re-reads and rebuilds. It closed (`2026-11-20-waste-water-and-climate-commencement-reader.md`), but it took so long that it needs a dedicated review before the next step. Jason has points to raise.

## Todo

- ⬜ 1. A design spec for the Commencement reader: its aims, what is in scope and what is out
- ⬜ 2. A substeps document: each substep's input sources, the data it changes, its output, what goes stale and why; the architecture and the workflow rules that force the substeps to loop
- ⬜ 3. The boundary with the Amending-law reader made explicit: which reader dates what, and why the Commencement reader is not doing the Amending-law reader's work
- ⬜ 4. Complexity: the code is now so complex that changes are hard to track — measure it and propose solutions
- ⬜ 5. The feed as a yardstick: standard stats driven from the comparison; the rules for taking the feed or the reader refined, in their owning step (not this one)
- ⬜ 6. Claude's takeaways from the step's session docs and log
- ⬜ 7. Changes decided and written where they belong (WORKFLOW, RULES, skills, memory); close

## Jason's points (2026-11-23)

1. "Commencement Reader needs a 'what it is doing' spec [design spec?]. Ie a clear aims - what's in scope and what's out of scope."
2. "A document that describes the substeps with extra detail - eg what are the input data sources, what data does it change, what its output, what goes stale and why - that sort of thing - explains the architecture and big workflow rules that mean having to loop the substeps."
3. "Related to those two - I'm not clear how Commencement Reader isn't doing part of the work of the Amending Law Reader. I want that explicit."
4. "Complexity - it's clear the code is now so complex that changes are getting harder to track - solutions?"
5. "Feed as a yardstick. This is working well. We need to drive standard stats from the comparison. The rules for deciding which to take Feed or Reader may need refining - and that shouldn't be in this step anyway."
6. "Your takeaways from reviewing the session docs for Commencement Reader."

## Dependencies

- ✅ Waste, Water and Climate: Commencement reader closed (2026-11-23, cd038fde)
- ✅ Earlier retrospectives for comparison: Maritime Safety (2026-11-07), Environmental Protection (2026-11-10), the review against the aims (2026-11-12), Fire and OH&S (2026-11-17)

## Starting material

- The step's session: its frontmatter (decisions, metrics, lessons) and the round's meta row (`2026-11-17-second-qq-round-meta.md`).
- The step's log: `backend/data/reports/commencement-reader/wwc-commencement-reader-log.md`.
- The code review that set the new loop: `backend/data/code-reviews/commencement-reader-code-review.md`; WORKFLOW "How the step runs".
- Late finds from the close: golden moved by a correct fix that unmasked an older fault (Decision 21); every reader commit stales the whole round's rules, so the close needed one more re-read and rebuild; the Sources gate's calendar rule decided on 2026-11-19 is still not built.
