---
session: 'LAT Change Pipeline: Fire and OH&S — Meta Session'
type: meta
status: active
opened: 2026-11-13
family: 'Fire and OH&S (round)'
---

# Session: LAT Change Pipeline: Fire and OH&S — Meta Session (ACTIVE)

## Problem

This is the first QQ register round, and it takes five families together (Jason 2026-11-13): FIRE, FIRE: Dangerous and Explosive Substances, OH&S: Gas & Electrical Safety, OH&S: Mines & Quarries and OH&S: Offshore Safety. OH&S: Occupational / Personal Safety is already switched and stays out. Between them the five families hold 219 live UK laws, 100 of them with LAT rows, and none of those laws has a making verdict from its own text. The 40 OH&S laws with rows were built once, at Occupational's Store and build, but none has been through the steps.

## Todo

- ✅ Tooling: round scope: `--family "Fire and OH&S"` gives exactly the five families (100 laws with rows, 219 live UK); closed 2026-11-13
- ⬜ Making laws (step 0)
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
- ⬜ Switch-over (the five names added to `:label_families`)
- ⬜ Retrospective and housekeeping

## Dependencies

- ✅ Environmental Protection switched and its retrospective closed (2026-11-12)
- ✅ Review tooling and the step-close check (pushed fa9aac25)
- ✅ Claude Model Plan: agents in `.claude/agents/` (fixer, summariser, clerk, reviewer); no agent QA in any step (pushed e6adb0a2)

## How this session runs

- **One round, five families** (Jason 2026-11-13). This replaces "one at a time" in the order after Environmental Protection. Each step runs once over the round with `--family "Fire and OH&S"`, the round's name in `ChangeVocabulary.Rounds`.
- **Step sessions.** Each step is its own session, `<date>-fire-and-ohs-<step-name>.md`, titled "Fire and OH&S: <Step name>". A session is opened when its step is reached, and starts in plan mode.
- **Parked bugs.** Each step's plan starts from its parked bugs, of any family.
- **The check line**, per round: at most 6 days a family (30 for the round); new reader bugs falling from EP's 26; open bugs falling from 123.
- **Scope.** The round's UK laws only: the register's families also hold 82 Australian laws.

## Step status

One row per step, filled when its session closes. Agent tokens are given by model.

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs closed / parked | Agent tokens (model) | Commits |
|---|---|---|---|---|---|---|---|---|---|
