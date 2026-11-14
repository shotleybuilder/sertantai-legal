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
- ✅ Making laws (step 0): 133 making, 65 not making, 21 no verdict (9.6%); 40 laws parsed (34 safety-zone orders), the 100 parser-stale laws re-stamped (0 rows changed); step close Stale laws PASS, Checked rows 22 (parked in EP); closed 2026-11-13
- ✅ Sources (step 1): round gate PASS, 139 laws, 1,173 needs, 0 failures, 0 register differences; one build (29,288 changes); scoped-law body fix (Fire Precautions Act 1971); the three switched families refetched and rebuilt (Decision 1 b, gates PASS), 3 laws' labels applied (Decision 3 c); step close Sources PASS, Checked rows 22 (parked in EP), Stale laws 49 (parked: Commencement reader); closed 2026-11-13
- ✅ Feed reader (step 2): 7,045 effects, our faults 0; 10 parked bugs taken (7 classes fixed, 1 set aside to the Markup reader, 2 known limits); 154 held examples moved and written (Decision 4 a); one build (29,286 changes); switched families one reading behind until Store and build (Decision 5 b); step close Feed reader PASS, Sources 3 (parked), Checked rows 22 (parked in EP), Stale laws 49 (parked: Commencement reader); closed 2026-11-13
- ✅ Markup reader (step 3): 1,942 changes and 1,815 note placements, our faults 0 (from 2); 6 parked bugs taken (3 fixed: child CommentaryRef, #188 by Decision 1 a, the nested later Addition by Decision 2 a with the Feed reader's held range patch; 3 known limits); catalogue 9 new accepted, 0 held moved (Decision 3 a); one build (29,281 changes); switched families' moved laws (Occupational 3, EP 1) refreshed at Store and build; step close Markup reader PASS, Sources 9 (parked), Checked rows 22 (parked in EP), Stale laws 49 (parked: Commencement reader); closed 2026-11-14
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
| Making laws | fire-and-ohs-making-laws | 2026-11-13 | 2026-11-13 | 1 | yes, all 7 (7: Stale laws PASS; Checked rows 22 parked in EP) | 1 (the round's 100 parser-stale laws re-parsed, as RULES family-re-parses-its-parser-stale-laws; Jason's go) | 3 closed / 3 parked (LAT parser: 6 not-making laws with rows, lat_reparse tables #189; Register: edges after refile) | 0 by the step; clerk (Sonnet) 24,858 for this row (its commit stopped on a format check, done in the session) | 2 |
| Sources | fire-and-ohs-sources | 2026-11-13 | 2026-11-13 | 1 | yes, all 6 (6: Sources PASS; Checked rows 22 parked in EP; Stale laws 49 parked with the Commencement reader) | 1 (the switched families fetched and rebuilt in the step, Jason's Decision 1 b) | 6 closed / 4 parked (Amending-law reader: schedules held not read; LAT parser: SI 1994/232 revoked with rows; Label fold: revocation listed per provision, SI 2008/2337; Commencement reader: 49 built laws) | 0 by the step; clerk (Sonnet) 24,320 for this row and the commits | 2 |
| Feed reader | fire-and-ohs-feed-reader | 2026-11-13 | 2026-11-13 | 1 | yes, all 8 (8: Feed reader PASS; Sources 3 parked with Sources; Checked rows 22 parked in EP; Stale laws 49 parked with the Commencement reader) | 0 (class 5 moved to the Markup reader within the plan's dispositions) | 8 closed (fixed or known limit) / 2 moved, 11 parked (Feed reader 3; Merge 3; Markup reader, Label fold, Evidence, Amending-law reader, Sources 1 each) | fixer (Fable) 1,180k over 7 of 8 calls (one not recorded); no clerk | 2 |
| Markup reader | fire-and-ohs-markup-reader | 2026-11-14 | 2026-11-14 | 1 | yes, all 8 (8: Markup reader PASS; Sources 9 parked with Sources; Checked rows 22 parked in EP; Stale laws 49 parked with the Commencement reader) | 0 (Decisions 1–3 within the plan) | 8 closed (5 fixed, 3 known limits) / 2 parked (Sources 1, Merge 1) | 0 by the step; clerk (Sonnet) for this row and the commit | 2 |
