---
session: 'LAT Change Pipeline: Environmental Protection — Meta Session'
type: meta
status: active
opened: '2026-11-08'
family: '💚 ENVIRONMENTAL PROTECTION'
---

# Session: LAT Change Pipeline: Environmental Protection — Meta Session (ACTIVE)

## Problem

Environmental Protection is the third family through the LAT Change Pipeline, and the last run before production hardening (Maritime Safety retrospective, Decision 3). It was chosen because its law is of a different kind from OH&S and Maritime Safety: Welsh, Scottish and Northern Ireland law, and EU retained environmental law. The register holds 395 live UK laws in the family, of which 59 have LAT rows; Making laws will add more. This session runs the delivery step by step and records each step's status for the retrospective. It stays ACTIVE until the family is switched over.

## Todo

- ✅ Making laws (step 0): 116 making, all with LAT rows (63 parsed); 21 no verdict (5%); closed 2026-11-08
- ✅ Sources: gate PASS after a build, 1,422 needs held or absent; 16 register statistics re-scraped (2 laws became revoked: 114 live making); closed 2026-11-08
- ✅ Feed reader: 11,674 effects, our faults 0, 6,386 placed; Decisions 1–4; three reader faults fixed; closed 2026-11-09
- ✅ Markup reader: 3,251 changes, our faults 0 (from 134); a scoped law read for its scope; three reader-side fixes; Decisions 1–4; closed 2026-11-09
- ✅ Commencement reader: 35,518 rows, our faults 0 on stored rules (from 9,954), leftovers 23 → 0; ten reader forms, two check errors, an order-store overlap fixed; Decisions 1–2; closed 2026-11-09
- ⬜ Extent reader
- ⬜ Amending-law reader
- ⬜ Merge
- ⬜ Evidence
- ⬜ Label fold
- ⬜ Measures
- ⬜ Store and build
- ⬜ Labels side by side
- ⬜ Switch-over
- ⬜ Retrospective and housekeeping

## Dependencies

- ✅ Maritime Safety switched (2026-11-07); retrospective closed with the order of work before Family 3 (Decision 3)
- ✅ The work before Family 3: the Mines Regulations 2014 → HSWA repair, #192, #191, #193, #194, #195, the commencement catalogue in the parallel read, and the parked owner bugs (pushed e2cbf9f5)
- ✅ Process: `session-start` "Step session", `docs/lat-change-pipeline/WORKFLOW.md` ("Running a new family"), `AIMS.md`, `RULES.md`

## How this session runs

- Each step is its own session, `.claude/sessions/lat-change-pipeline/<date>-environmental-protection-<step-name>.md`, titled "Environmental Protection: <Step name>". It is created when the step is reached, and starts in plan mode.
- This session holds only: which step is running, each step's status row, the decisions that cross steps, and pointers. Step detail stays in the step session.
- Each step's parked bugs (`open_bugs` by `step:`) and RULES.md's open decisions are read into that step's plan.
- Scope: the family's UK laws. The register's family also holds 23 Australian laws, which legislation.gov.uk does not publish; they are outside the pipeline.

## Step status

One row per step, filled when the step session closes. Agent tokens are those of agent checks and agent-run plan items.

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs parked | Agent tokens | Commits |
|---|---|---|---|---|---|---|---|---|---|
| Making laws | making-laws | 2026-11-08 | 2026-11-08 | 1 | yes, all 6 | 0 (one classifier phrase moved to the commencement reader's words by the architecture test) | 2 (Commencement reader: EU "enter into force"; LAT parser: snapshot tables) + 3 not-making laws with rows (LAT parser, parking list) | 0 | 2 |
| Sources | sources | 2026-11-08 | 2026-11-08 | 1 | yes, all 5 | 0 (the explained-differences fixture wired within the pass rule) | 2 (Register: statistics capped at 1,000; LAT parser: rows for 2 now-revoked laws) | 0 | 2 |
| Feed reader | feed-reader | 2026-11-08 | 2026-11-09 | 2 | yes, all 6 | 0 (one law's body fetched, Decision 1, within the sources-held rule) | 3 open (Sources: scoped law needs its body; Feed reader: same-date stages, removal stage territory) + Tooling (credo-diff leftovers, #197); 4 fixed | 86,078 | 2 |
| Markup reader | markup-reader | 2026-11-09 | 2026-11-09 | 1 | yes, all 7 | 0 (the agent's new class fixed by Decision 3, a second cold catalogue run, within the pass rule) | 1 open (Tooling: the catalogue's full cold run is slow, #198) + 2 parking items (Feed reader: example rotation check; Markup reader: Z-number pattern names); 4 fixed | 152,593 | 5 |
| Commencement reader | commencement-reader | 2026-11-09 | 2026-11-09 | 1 | yes, all 6 | 0 (two fixes after the stored check — an order-store overlap, schedule-only rules — and one order form, within the pass rule; a second catalogue dry run) | 4 open (Commencement reader: order list wrong law, cited-orders overlap, fresh read without schedule effects, amenders list); 3 fixed (2 parked from OH&S/Maritime) | 0 | 2 |
