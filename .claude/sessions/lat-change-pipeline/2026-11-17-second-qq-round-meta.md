---
session: 'LAT Change Pipeline: second QQ round — Meta Session'
type: meta
status: active
opened: '2026-11-17'
family: 'Waste, Water and Climate (round)'
---

# Session: LAT Change Pipeline: second QQ round — Meta Session (ACTIVE)

## Problem

The next round takes the QQ legal register's families not already covered (Jason, 2026-11-17). Eight families are switched. QQ's register (laws QQ marks `yes`) touches 37 more, and 50 QQ laws have no family. Taken whole, as a round's scope must be (rule `a-round-is-its-exact-families`), those 37 families hold 8,167 live UK laws. Only 1,452 of them have law text in the local store, and 350 are QQ's own. The first round was 219 live laws, 91 fetched. The round's scope must be decided before Making laws (step 0) is planned.

## Todo

- ✅ Decision 1: the round's scope: (b) the environment cluster (Jason 2026-11-17)
- ✅ Tooling: "Waste, Water and Climate" in `ChangeVocabulary.Rounds`, its six families by exact name, with a test (ee5b3c17)
- ✅ Making laws (step 0): `2026-11-17-waste-water-and-climate-making-laws.md` (closed 2026-11-18)
- ✅ Sources (step 1): `2026-11-18-waste-water-and-climate-sources.md` (closed 2026-11-18)
- ✅ Feed reader (step 2): `2026-11-18-waste-water-and-climate-feed-reader.md` (closed 2026-11-19)
- ✅ Markup reader (step 3): `2026-11-19-waste-water-and-climate-markup-reader.md` (closed 2026-11-20)
- ✅ Commencement reader (step 4): `2026-11-20-waste-water-and-climate-commencement-reader.md` (closed 2026-11-23)
- ⬜ Before the Extent reader (Jason 2026-11-23, the Commencement reader retrospective, Decision 1), in order:
  1. ✅ `2026-11-23-commencement-reader-retrospective.md` (closed 2026-11-23)
  2. ✅ `2026-11-23-commencement-reader-step-procedures.md`: tasks for the step's procedures, feed figures in Measures, WORKFLOW rules (closed 2026-11-23)
  3. ✅ `2026-11-23-commencement-reader-staleness.md`: staleness that follows what changed (closed 2026-11-23)
  4. ✅ `2026-11-23-commencement-reader-old-path-decouple.md`: the new path off the old dater and register (closed 2026-11-23)
  5. `2026-11-23-commencement-reader-order-split.md`: split the order reader (one or more sessions)
  6. `2026-11-23-commencement-reader-feed-differences-as-patterns.md`: feed differences as patterns, judged by what the feed covers (Jason 2026-11-23)
  7. `2026-11-23-extent-reader-readiness-review.md`: the retrospective's questions asked of the Extent reader
- ⬜ Extent reader (step 5)

## Dependencies

- ✅ Fire and OH&S switched, its retrospective closed (2026-11-17)
- ✅ The Credo hook's /tmp copies fixed (9ec6cd27)
- ✅ The extended golden's baseline: 41/50 (RULES Decision 10)

## Sizes (2026-11-17)

Live UK laws per family (not revoked), the bodies already in the local store, and QQ's own laws. Of the families with no name, 3,832 are live UK, and 45 of those are QQ's.

| Family | Live UK | Text held | QQ |
|---|---|---|---|
| ENERGY | 699 | 128 | 9 |
| WILDLIFE & COUNTRYSIDE | 665 | 105 | 19 |
| AGRICULTURE | 539 | 32 | 2 |
| ANIMALS & ANIMAL HEALTH | 531 | 15 | 1 |
| WASTE | 476 | 134 | 45 |
| FISHERIES & FISHING | 439 | 22 | 3 |
| WATER & WASTEWATER | 400 | 117 | 24 |
| TOWN & COUNTRY PLANNING | 374 | 45 | 22 |
| PLANNING & INFRASTRUCTURE | 373 | 78 | 4 |
| TRANSPORT: Harbours & Shipping | 317 | 20 | 2 |
| PLANT HEALTH | 308 | 13 | 4 |
| CLIMATE CHANGE | 307 | 76 | 21 |
| HEALTH: Coronavirus | 273 | 13 | 3 |
| MARINE & RIVERINE | 252 | 25 | 7 |
| FOOD | 239 | 15 | 4 |
| TRANSPORT: Road Safety | 210 | 47 | 26 |
| POLLUTION | 191 | 57 | 11 |
| HR: Insurance / Compensation / Wages / Benefits | 150 | 9 | 5 |
| PUBLIC: Building Safety | 146 | 83 | 15 |
| HR: Employment | 138 | 43 | 15 |
| NUCLEAR & RADIOLOGICAL | 121 | 44 | 13 |
| AIR QUALITY | 118 | 21 | 16 |
| HEALTH: Public | 116 | 45 | 12 |
| HEALTH: Drug & Medicine Safety | 102 | 23 | 5 |
| TRANSPORT: Roads & Vehicles | 98 | 10 | 2 |
| TRANSPORT: Air Safety | 97 | 39 | 6 |
| PUBLIC: Consumer / Product Safety | 94 | 59 | 18 |
| GMOs | 57 | 11 | 1 |
| PUBLIC | 56 | 25 | 11 |
| PUBLIC: Data | 51 | 21 | 4 |
| TREES: Forestry & Timber | 49 | 12 | 3 |
| TRANSPORT: Rail Safety | 39 | 26 | 3 |
| NOISE | 39 | 8 | 2 |
| HISTORIC ENVIRONMENT | 31 | 8 | 1 |
| BUILDINGS | 28 | 9 | 3 |
| AGRICULTURE: Pesticides | 27 | 8 | 4 |
| HR: Working Time | 17 | 6 | 4 |
| **Total** | **8,167** | **1,452** | **350** |

## Decision 1: the round's scope

**The question.** Which families does the second QQ round take?

**The aim it bears on.** `binds-on-date`, for QQ's laws first. Also the order (WORKFLOW, "The order after Environmental Protection"). That phase was to end "after 4 QQ families", and the first round took 5. The rest of the register was to come after production hardening, so a large round now runs ahead of that order.

**The options.**
- **(a) Every uncovered family in one round:** 8,167 live laws and about 6,700 bodies to fetch, 37 times the first round's laws. The check line (6 days a family) allows 222 days. Step 0's fetch and text verdicts alone would take days. Recommended against.
- **(b) A cluster round, the environment families beside EP:** WASTE, WATER & WASTEWATER, CLIMATE CHANGE, POLLUTION, AIR QUALITY and NOISE. That is 1,531 live laws, 413 bodies held, about 1,100 to fetch, and 119 QQ laws. It is 7 times the first round's laws, with the largest QQ share of any cluster. The remaining families follow in later cluster rounds.
- **(c) A small cluster round, the public-safety families:** PUBLIC: Building Safety, PUBLIC: Consumer / Product Safety, PUBLIC, PUBLIC: Data and BUILDINGS. That is 375 live laws, 197 bodies held, about 180 to fetch, and 51 QQ laws. It is close to the first round's size.
- **(d) QQ's 350 laws only, not whole families.** This breaks `a-round-is-its-exact-families`, and switching is by family (`:label_families`). It would need a law-list scope through every step and a partial switch. Recommended against.

**Decided (Jason, 2026-11-17): (b).** The round is named "Waste, Water and Climate": 1,531 live UK laws (the task's scope, `live` not revoked), 182 with LAT rows.

**The recommendation.** (b) The environment cluster. It holds a third of QQ's uncovered laws. It extends the pipeline into families that cite EP's laws, so EP's held work carries over. It is large enough to show what scale costs before production hardening, and that is the question Jason's "run all steps without stopping" turns on. If the step 0 fetch of about 1,100 bodies is too much for one round, choose (c) first.

## How this session runs

As the first round (`2026-11-13-fire-and-ohs-meta.md`): one session a step, `<date>-waste-water-and-climate-<step-name>.md`, opened in plan mode. Each step's plan starts from its parked bugs. The extended golden (50) gates every step: no new failure past the 9 of the baseline (RULES Decision 10). Fold-version edits are batched before one write (Fire and OH&S retrospective, Decision 3). The check line is at most 6 days a family, so 36 for the round; new reader bugs and open bugs (119) should fall.

## Step status

| Step | Session | Opened | Closed | Days | Pass rule met | Plan changes | Bugs closed / parked | Agent tokens (model) | Commits |
|---|---|---|---|---|---|---|---|---|---|
| Making laws | `2026-11-17-waste-water-and-climate-making-laws.md` | 2026-11-17 | 2026-11-18 | 2 | yes, but no verdict is 15.3% (accepted, Decision 1 a) | Decision 2's form taken out (a bird's nest; Jason): 15 EU reviews instead; parser-stale re-stamp of 190 | 0 closed / 9 parked (7 golden, 2 LAT parser) + `eu-enter-into-force` re-parked with its fix | 0 (no agents) | ee5b3c17, 4e10c1f7, 7e3a8554, 1b8d75bd, 004c94b6 |
| Sources | `2026-11-18-waste-water-and-climate-sources.md` | 2026-11-18 | 2026-11-18 | 1 | yes: gate PASS (4,523 needs, 0 failures, 0 register differences); step close Stale laws 224 parked with the readers | Decision 1 (b) narrowed the order-list fix; Decision 2 (a) fetched the switched families' 117; Decision 3 (a) re-scraped all 119; 23 laws rebuilt, 2 Maritime labels refolded | 6 closed (1 moved to the Register) / 5 parked (Register 2, Commencement reader 2, Extent reader 1) | not recorded | 556c5d6a, 515de15f, 6acaf483 |
| Feed reader | `2026-11-18-waste-water-and-climate-feed-reader.md` | 2026-11-18 | 2026-11-19 | 2 | yes: our faults 62 → 0, seed 67 repeatable, golden 41/50 the same 9; step close Stale laws 224 (parked at Sources) | Decision 2 (b) added two classes the plural-list fix uncovered (bracket tails, attached siblings) | 4 closed, 2 moved / 8 parked (Feed reader 3, Markup reader 2, Merge 1, LAT parser 2) | fixer ×7 (about 1.1M tokens, Fable) | df1727ac |
| Markup reader | `2026-11-19-waste-water-and-climate-markup-reader.md` | 2026-11-19 | 2026-11-20 | 2 | yes: our faults 2 → 0, switched families 0, seed 67 repeatable, golden 41/50 the same 9; step close Stale laws 224 (parked at Sources) | Decision 3: fix, not known limits (Jason) — fixes 7–12 added for classes the first fixes uncovered; time box one day → two | 15 closed / 11 parked (Markup reader 5, Merge 3, Feed reader 2, LAT parser 1) | fixer ×12 + 2 revisions (fixes 10–12 about 0.9M tokens, Fable) | f4cb1c73 |
| Commencement reader | `2026-11-20-waste-water-and-climate-commencement-reader.md` | 2026-11-20 | 2026-11-23 | 4 | yes: our faults 0, leftovers named, the new two-way feed gate all statused (690 proven feed errors), switched families PASS, golden 43/50 (7 the Label fold's); step close Sources 113 (Extent reader sweeps) and Stale laws 565 (other steps'; this reader 0) | suspended a day for the code review; resumed on the new loop; Decisions 1–21 | 7 earlier bugs closed / 10 parked (Commencement reader 9, Label fold 1), 2 passed (Register, Sources) | fixer ×20 (about 1.9M tokens, Fable) before Decision 3 | 3876fac6 |
