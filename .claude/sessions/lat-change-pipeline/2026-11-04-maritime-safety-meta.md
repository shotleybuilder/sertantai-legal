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
- ⬜ Sources
- ⬜ Feed reader
- ⬜ Markup reader
- ⬜ Commencement reader
- ⬜ Extent reader
- ⬜ Amending-law reader
- ⬜ Merge
- ⬜ Evidence
- ⬜ Label fold
- ⬜ Measures
- ⬜ Store and build
- ⬜ Labels side by side
- ⬜ Switch-over
- ⬜ Retrospective: compare against OH&S from the status table

## Dependencies

- ✅ OH&S switched (2026-11-02); retrospective and code reduction closed (2026-11-03)
- ✅ Process: `session-start` "Step session", `docs/lat-change-pipeline/WORKFLOW.md`, `AIMS.md`, `RULES.md`
- ✅ The family's LAT rows: 16 laws, as held (Decision 1)

## How this session runs

- Each step is its own session, `.claude/sessions/lat-change-pipeline/<date>-maritime-safety-<step-name>.md`, titled "Maritime Safety: <Step name>". It is created when the step is reached (no stubs ahead of time: their scope would be guessed before the earlier steps report). It starts in plan mode.
- This session holds only: which step is running, each step's status row, the decisions that cross steps, and pointers. Step detail stays in the step session.
- RULES.md's open decisions are taken into the plan of the step they touch.
- Parked bugs for a step (`.claude/sessions/lat-change-pipeline/2026-11-03-parked-bugs.md`, by `step:`) are read into that step's plan; whether any are fixed in it is the plan's call.

## Step status

One row per step, filled when the step session closes. Agent tokens are those of agent checks and agent-run plan items.

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs parked | Agent tokens | Commits |
|---|---|---|---|---|---|---|---|---|---|
| Sources | | | | | | | | | |
| Feed reader | | | | | | | | | |
| Markup reader | | | | | | | | | |
| Commencement reader | | | | | | | | | |
| Extent reader | | | | | | | | | |
| Amending-law reader | | | | | | | | | |
| Merge | | | | | | | | | |
| Evidence | | | | | | | | | |
| Label fold | | | | | | | | | |
| Measures | | | | | | | | | |
| Store and build | | | | | | | | | |
| Labels side by side | | | | | | | | | |
| Switch-over | | | | | | | | | |

## Decisions

### 1. Which family, and its missing LAT rows — DECIDED 2026-11-04

- **Family:** `💙 TRANSPORT: Maritime Safety` (Jason).
- **Scope:** the 16 laws with LAT rows now (Jason). LAT stores rows only for in-force making laws; that is a basic design rule. Amending and commencing laws that set no duties are read from the XML store, not given rows.
- **Fact for Jason, not acted on:** the register marks 109 of the family's laws as in-force or part-revoked making laws (`is_making`), and 15 of them have rows. One has rows but is marked not-making (part revoked). The other 94 are outside this run. Whether they need parsing is a LAT parser question, outside the pipeline's 13 steps.
