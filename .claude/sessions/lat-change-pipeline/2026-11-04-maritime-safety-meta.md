---
session: 'LAT Change Pipeline: Maritime Safety — Meta Session'
type: meta
status: active
opened: '2026-11-04'
family: '💙 TRANSPORT: Maritime Safety'
---

# Session: LAT Change Pipeline: Maritime Safety — Meta Session (ACTIVE)

## Problem

The second family through the LAT Change Pipeline, and the first under the process set by the 2026-11-03 retrospective (each step its own session, started in plan mode). OH&S took two weeks; this run tests whether the new process lands a family faster and cleaner. This session runs the delivery step by step and records each step's status for the next retrospective. It stays ACTIVE until the family is switched over.

## Todo

- ✅ Family: TRANSPORT: Maritime Safety; scope: the 16 laws with LAT rows (Decision 1)
- ✅ Making laws (step 0): 117 making, all with LAT rows; closed 2026-11-04
- ✅ Sources: gate PASS after a build, 682 needs held or absent; closed 2026-11-04
- ✅ Feed reader: our faults 10 → 0, catalogue gap fixed (Decision 1), agent clean; closed 2026-11-04
- ✅ Markup reader
- ✅ Commencement reader
- ✅ Extent reader: code gate PASS; bound by the law's text 736 → 2,923 of 3,154 (Decisions 1–4); closed 2026-11-05
- ✅ Amending-law reader: code gate PASS (83 groups named); A 1,273 → 1,348; 5 misread classes fixed (Decisions 1–3); closed 2026-11-06
- ✅ Merge: code gate PASS (310 groups named), one agent pass; new paragraphs carry their event (Decisions 1–2); closed 2026-11-06
- ✅ Evidence: code gate PASS (59 groups named, 37 inherited), one agent pass; no table fix; closed 2026-11-06
- ✅ Label fold: code gate PASS (7 groups named), one agent pass; 2 fold faults in Label.Made fixed (Decision 1); closed 2026-11-06
- ✅ Measures: every published figure audited, every gate re-run (3 that had passed fail today: parked); 3 measure faults fixed; replicable at seed 902; closed 2026-11-06
- ⬜ Store and build
- ⬜ Labels side by side
- ⬜ Switch-over
- ⬜ Retrospective: compare against OH&S from the status table

## Dependencies

- ✅ OH&S switched (2026-11-02); retrospective and code reduction closed (2026-11-03)
- ✅ Process: `session-start` "Step session", `docs/lat-change-pipeline/WORKFLOW.md`, `AIMS.md`, `RULES.md`
- ✅ Making laws step passed: 117 making laws decided from their text, all with LAT rows (Decision 2)

## How this session runs

- Each step is its own session, `.claude/sessions/lat-change-pipeline/<date>-maritime-safety-<step-name>.md`, titled "Maritime Safety: <Step name>". It is created when the step is reached (no stubs ahead of time: their scope would be guessed before the earlier steps report). It starts in plan mode.
- This session holds only: which step is running, each step's status row, the decisions that cross steps, and pointers. Step detail stays in the step session.
- RULES.md's open decisions are taken into the plan of the step they touch.
- Parked bugs for a step (`.claude/sessions/lat-change-pipeline/2026-11-03-parked-bugs.md`, by `step:`) are read into that step's plan; whether any are fixed in it is the plan's call.

## Step status

One row per step, filled when the step session closes. Agent tokens are those of agent checks and agent-run plan items.

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs parked | Agent tokens | Commits |
|---|---|---|---|---|---|---|---|---|---|
| Making laws | making-laws | 2026-11-04 | 2026-11-04 | 1 | yes, all 6 | 0 | 2 (Register, LAT parser) | 0 | 12 |
| Sources | sources | 2026-11-04 | 2026-11-04 | 1 | yes, all 4 | 0 | 0 | 0 | 1 |
| Feed reader | feed-reader | 2026-11-04 | 2026-11-04 | 1 | yes, all 6 | 0 | 1 (LAT parser) | 98,791 | 3 |
| Markup reader | markup-reader | 2026-11-04 | 2026-11-04 | 1 | yes, all 6 | 0 | 1 (Markup reader: catalogue examples rotate) | 138,275 | 2 |
| Commencement reader | commencement-reader | 2026-11-05 | 2026-11-05 | 1 | yes, by Decision 2 (agent rounds stopped at 2; 1 test failure the Extent reader's) | 0 | 3 (Feed reader, Extent reader, Sources) | 273,926 | 2 |
| Extent reader | extent-reader | 2026-11-05 | 2026-11-05 | 1 | yes, all 4 (code gate, Decision 1) | 0 | 3 (Sources, Amending-law reader, OH&S Extent gate) | 0 | 2 |
| Amending-law reader | amending-law-reader | 2026-11-06 | 2026-11-06 | 1 | yes, all 4 (code gate, Decision 1) | 1 (Decision 3: a third full read pass) | 5 (Amending-law reader: as-if modifications, quote body number, Schedule sub-paragraphs, a law named in an aside; EU targets half) | 0 | 2 |
| Merge | merge | 2026-11-06 | 2026-11-06 | 1 | yes, all 4 (code gate + one agent pass, Decision 1) | 0 (Decision 2 a fix within the plan) | 2 (Commencement reader: amending-law start; Amending-law reader: unnumbered list items) | 129,479 | 2 |
| Evidence | evidence | 2026-11-06 | 2026-11-06 | 1 | yes, all 4 (code gate + one agent pass, Decision 1) | 1 (date conflicts named here, not inherited from Merge) | 1 (Commencement reader: amending-law own clause unread) | 155,806 | 2 |
| Label fold | label-fold | 2026-11-06 | 2026-11-06 | 1 | yes, all 4 (code gate + one agent pass, Decision 1) | 0 (the container check re-run on 4 laws, spliced) | 2 (Feed reader: range Part locator, 106 rows; Commencement reader: staged start dropped, 21 changes) | 350,424 | 2 |
| Measures | measures | 2026-11-06 | 2026-11-06 | 1 | yes, all 4 | 0 (territory items drawn from the extent sample, same pass) | 6 (Sources: 11 to fetch; Extent reader, Amending-law reader: gates moved; Store and build: gates not re-run, measures in the version; Commencement reader: purpose-limited start, 93 changes; Merge: ids split) | 288,287 | 2 |
| Store and build | | | | | | | | | |
| Labels side by side | | | | | | | | | |
| Switch-over | | | | | | | | | |

## Decisions

### 1. Which family, and its missing LAT rows — DECIDED 2026-11-04

- **Family:** `💙 TRANSPORT: Maritime Safety` (Jason).
- **Scope:** the 16 laws with LAT rows now (Jason). LAT stores rows only for in-force making laws; that is a basic design rule. Amending and commencing laws that set no duties are read from the XML store, not given rows. Superseded in part by Decision 2: the scope grows to the laws the Making laws step decides making.
- **Fact for Jason, not acted on:** the register marks 109 of the family's laws as in-force or part-revoked making laws (`is_making`), and 15 of them have rows. One has rows but is marked not-making (part revoked). The other 94 are outside this run. Whether they need parsing is a LAT parser question, outside the pipeline's 13 steps.

### 2. Making laws decided before Sources — DECIDED 2026-11-04

Jason, 2026-11-04: a law with no LAT rows marked in force and making is an estimate (the detector scores metadata and title; fractalaw reads the text for the final call). So the family's LAT rows depend on that call, and this dependency comes before Sources. Question: can the law's own text, read by the pipeline's readers, decide it without fractalaw?

- **The 158 live laws without rows (corrected 2026-11-04):** 94 marked making, 93 by `legacy_drrp` (old duty types) and 1 by `legacy_is_making`. 64 marked not making: 57 by `legacy_is_making`, 5 by human review and 2 by fractalaw. My first note said "detector only", which was wrong: the detector's scores are stored, but older tiers decide. None of the 151 estimates was read from the law's text, so both sides are checked.
- **Held:** the XML store has the body of 6 of the 94. It holds what the pipeline needed (the laws with rows, and their amenders), not the family's other laws.
- **Probe on the 6 (rough text count, P1 groups, quoted inserted text removed):** 5 read as making, for example Load Line 1998, with 32 provisions stating "shall/must" and 3 amending. One is amending only: Port State Control (Amendment) Regulations 2003, with 2 amending provisions and none stating a requirement. The estimate is wrong there.
- **Decided (Jason):** a formal step, **Making laws** (step 0, before Sources). Each live law is decided from its own text with the pipeline's readers, with no dependency on fractalaw. The verdict is a new `law_text` tier in `MakingResolver`, below human review and fractalaw's enrichment, above every estimate. The laws decided making are then parsed into LAT. Docs: WORKFLOW.md step 0. Session: `2026-11-04-maritime-safety-making-laws.md`.
