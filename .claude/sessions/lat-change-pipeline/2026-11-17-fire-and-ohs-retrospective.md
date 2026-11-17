---
session: 'Fire and OH&S: Retrospective'
status: closed
opened: '2026-11-17'
closed: '2026-11-17'
outcome: success
family: 'Fire and OH&S (round)'
parent: lat-change-pipeline/2026-11-13-fire-and-ohs-meta.md
summary: >
  The first QQ round (five families, 139 laws) took 5 days, 1 a family against at most 6, and met all 14 pass rules,
  with Fable doing the reader and fold fixes (about 5.1M tokens, 1.0M a family as EP) and the session confirming them
  in code. Bugs: 69 closed (51 existing) and 52 parked, so open rose 114 to 119; finding per family fell about fourfold.
  Decided: fix the Credo hook first; no agent now, the extended golden (baseline 41/50) gates from the next round, with
  one agent check at its end; carry on, and splitting the versions becomes hardening's first todo.
decisions:
  - what: Fix the Credo hook's /tmp copies in its own Tooling session, before the next round
    why: parked three times (EP, 11-14, 11-17) and it filled /tmp twice in the round; a lesson repeated must become code
    result: Tooling session next
  - what: 'No agent in final QA now; the extended golden (50) gates every step from the next round; one agent check at the end of the next round'
    why: "Jason: run against the extended golden set henceforth; RULES Decision 10's 'the 23 join at the next family' had been dropped for three families"
    result: 'baseline 41/50 (27/27 + 14/23), as at OH&S round 9; RULES 10, WORKFLOW'
  - what: Carry the version cascades and switched-family refolds; batch fold-version edits before one write; split the versions as hardening's first todo
    why: the measured cost this round was hours, not days; the split is groundwork for one process
    result: WORKFLOW line; hardening session todo
metrics:
  run: { days: 5, families: 5, days_per_family: 1, steps: 14, closed_same_day: 11, pass_rules_met: 14, plan_changes: 6, session_lines: 5262, commits: 33, laws_switched: 139, switched_refolded: 388 }
  agents: { fixer_fable_tokens: 5100000, fixer_calls: 24, clerk_sonnet_tokens: 72000, summariser_tokens: 0 }
  bugs: { new_closed: 18, new_parked: 52, existing_fixed: 51, existing_parked: 65, moved: 2, open_before: 114, open_after: 119, new_reader_parked: 29, swept_logged_fixed: 3 }
  golden_extended: { pass: 41, of: 50, base_27: 27, extended_23: 14 }
lessons:
  - title: The open count can rise while the backlog is worked hard
    detail: 'The round closed 69 bugs (51 existing, against EP''s 24) and still rose 114 to 119, because five families'' finding (52 parked) outran it. Per family finding fell fourfold (14 against 54). Read closing and finding per family, not the open total alone.'
    tag: tooling
  - title: A rule recommended in RULES but never put in a checklist is dropped silently
    detail: 'Decision 10 said the 23 extended golden cases join "at the next family''s pass, from the first step". Maritime, EP and this round all ran the 27; nothing in session-start or the plan template named it. Jason remembered it at the retrospective.'
    tag: tooling
  - title: A commit message can name paperwork its commit did not write
    detail: 'The Measures close commit (4964d636) lists "meta row", but the meta file was not in it; the row was missing until this review read the table step by step.'
    tag: tooling
  - title: A sweep that clears a parked bug must log it fixed
    detail: 'Three Sources fetch backlogs were cleared by the next steps'' sweeps (round gate 0 failures) but still read open in the index, inflating the open count.'
    tag: data
bugs:
  - pattern: "Three amending laws' schedules newly needed after the Feed reader's rebuild are not fetched (backlog): UK_nisr_2026_89 for NISR 2014/224, UK_uksi_1996_2089 for the Explosives Act 1875, UK_uksi_1993_208 for SI 1956/1943"
    category: backlog-schedules-after-feed-fixes
    module: sources
    affected: 3 documents
    fix: "swept by later steps; the round's Sources gate 0 failures at the Switch-over close"
    step: Sources
    status: fixed
  - pattern: "Sources gate after the Markup reader's build: SI 1992/1728 not fetched (body, introduction, schedules) for the Offshore Safety Act 1992 c.15, and 3 backlog schedules stale (SI 1974/1885 for the Explosives Act 1875, SI 1974/2013 for the Mines and Quarries Act 1954, 2017 c.3 for 2004 c.21)"
    category: sources-after-markup-build
    module: sources
    affected: 6 documents
    fix: "swept by later steps; the round's Sources gate 0 failures at the Switch-over close"
    step: Sources
    status: fixed
  - pattern: "FRSA 2004's backlog documents SI 2017/399 (body and schedules) and SI 2018/227 (body) are stale in the store (step close Sources 3)"
    category: sources-stale-backlog
    module: sources
    affected: 3 documents
    fix: "swept by later steps; the round's Sources gate 0 failures at the Switch-over close"
    step: Sources
    status: fixed
artifacts:
  - backend/data/reports/retrospective/fire-and-ohs-bugs.md
  - backend/data/reports/retrospective/fire-and-ohs-golden-extended.txt
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - .claude/sessions/2026-11-07-production-hardening-and-integration.md
depends_on:
  - lat-change-pipeline/2026-11-17-fire-and-ohs-switch-over
  - lat-change-pipeline/2026-11-10-environmental-protection-retrospective
enables:
  - 'Tooling: the Credo hook cleans its /tmp copy'
  - 'the next QQ round (the register families not yet covered), on the extended golden'
  - 2026-11-07-production-hardening-and-integration
---

# Session: Fire and OH&S: Retrospective (CLOSED)

## Problem

The round is switched: five families, 139 laws, from 2026-11-13 to 11-17. It was the first round run as one, and the first run with a model per part: the session on Opus 5.5, `fixer` on Fable 5.2, `summariser` and `clerk` on smaller models. Jason's view (2026-11-17) is that the orchestration worked: Fable took the harder bugs better, the tokens held out, and the session checked and confirmed each fix. He expects the bug picture to be better, but wants that confirmed. This retrospective measures the round from its step lessons and the session index, not from memory (EP's lesson), and records what to change.

## Todo

- ✅ Measure each step: the round against EP, Maritime and OH&S, and against the meta's check line (6 days a family, 30 for the round)
- ✅ Bug status, four ways (new and closed, new and parked, existing and fixed, existing and parked), by owning step; against the check line (new reader bugs below EP's 26, open bugs below 123). Full lists in `backend/data/reports/retrospective/fire-and-ohs-bugs.md`
- ✅ The model per part, measured: agent tokens by model per step, each fixer call's class and outcome, the session's catches of a fixer's over-reach
- ✅ The round's lessons from its 14 step sessions (index): what worked, what drifted, what repeated inside the round
- ✅ Decisions 1–3 (Jason, 2026-11-17): fix the Credo hook in its own Tooling session; no agent now, the extended golden (50) gates from the next round, one agent check at its end; carry on, the version split as hardening's first todo
- ✅ Record: RULES Decision 10 (the extended golden), WORKFLOW ("After the first QQ round", the golden prerequisite), the hardening session's first todo, the meta's missing Measures row and its Retrospective row (meta closed), the pickup memory
- ✅ Housekeeping: done 2026-11-17 (meta, "Housekeeping after the round"): `lat_reparse` tables dropped, NAS full snapshot verified, 69 restore points pruned, `/tmp` cleared
- ✅ Close the session; session and docs commits with `--no-verify`, by path; no push unless asked

## Context, not to action (Jason, 2026-11-17)

- **The next round** is the QQ legal register's families not already covered.
- **Further out:** the whole workflow runs through every step without stopping, as software should, for example when new laws are processed. This is the production-hardening session's aim (`2026-11-07-production-hardening-and-integration.md`). The review notes what bears on it; it does not plan it.

## Dependencies

- ✅ Fire and OH&S: Switch-over closed, pushed (e19d9aa2)
- ✅ Environmental Protection: Retrospective (the measures and the four-way bug method)

## 1. The run measured

| | Maritime Safety | Environmental Protection | Fire and OH&S (round of 5) |
|---|---|---|---|
| Calendar days | 4 | 5 | 5 (2026-11-13 to 11-17): **1 a family** |
| Laws switched | 117 | 122 | 139, plus 388 switched laws refolded |
| Steps closed on the day opened | 13 of 14 | 11 of 14 | 11 of 14 (Extent reader, Label fold, Store and build took 2) |
| Session lines (steps, meta, scope) | 3,748 | 4,126 | 5,262 |
| Commits | 55 | 37 | 33 (14 session) |
| Pass rule met | all 14 | all 14 | all 14; every step close PASS or each failure parked with its owner |
| Plan changes | 6 | 0 | 6 in 5 steps, each approved (a re-parse, a fetch, a fix's lost joins, an amended plan twice, an in-step class). The meta has no Measures row; it is added at the record todo |
| Agent tokens | 1.49M | about 1.0M | **fixer (Fable) about 5.1M** over 24 calls (Commencement reader 1.70M, Feed reader 1.18M, Extent reader 660k); clerk (Sonnet) about 72k in 3 steps; summariser none. About 1.0M a family, as EP |

The check line (meta): **days met** (5 against 30); **new reader bugs missed narrowly** (29 parked against EP's 26, but across 5 families, not one); **open bugs missed** (114 → 119; see section 2).

## 2. Bug status

Full lists: `backend/data/reports/retrospective/fire-and-ohs-bugs.md`. A bug counts once, under its latest status, matched by pattern or class slug.

| | EP (1 family) | Fire and OH&S (5 families) |
|---|---|---|
| New and closed | 13 | 18 |
| New and parked | 41 | 52 (Commencement reader 12, Sources 9, Amending-law reader 8, Feed, Register, Extent 4 each) |
| Existing and fixed | 24 | **51** (Commencement reader 22, Feed reader 8, Sources 6, Markup reader 5) |
| Existing and parked | 79 | 65 |
| Open before → after | 109 → 120 | 114 → 119 |

**Jason's expectation, checked.** Better, but not yet falling:
- **Closing nearly doubled:** 69 closed against EP's 37, most of them the backlog (51 existing). The Commencement reader, EP's worst (29 open), closed 22.
- **Finding per family fell by about four:** 70 new across 5 families (14 a family) against EP's 54 for one.
- **The open total still rose by 5.** The round found 52 it parked, and closed 51 old.
- **At least 3 parked entries are already done.** The round's Sources fetch backlogs (3 documents after the Feed reader, 6 after the Markup reader, FRSA 2004's 3 stale) were swept by later steps. The round's Sources gate shows 0 failures at the close, but the entries still read open. A sweep doesn't log `fixed`.
- **One bug was parked twice in the round** (the Credo hook's `/tmp` copies, 11-14 and 11-17), and EP's retrospective named it already parked. It filled `/tmp` twice in the round.

## 3. The model per part

- **Fable took the hard classes.** The 24 fixer calls fixed the round's reader and fold classes: 22 Commencement reader bugs, the Merge's compound provision, the stages fold, Royal Assent for TCPA s.78(4BA). Each came with its failing test and its reach.
- **The session caught what the fixer's tests did not.** Four lessons:
  - "A golden pass can rest on a wrong reading";
  - "A status diff per scope finds a fix's regressions the tests miss";
  - "Diff the checked rows after a fold fix";
  - "Read a fix's reach change by change".

  Each catch was code the session ran after the fixer returned, not an agent check.
- **The cost sat in the briefs, not in the model.** Lean briefs cost a third (Commencement reader: calls 1–3's wide briefs took 1.29M of 1.70M). Wide scans still overran the 150k cap three times (Extent reader 409k on a 29-minute scan; Label fold 228k). A scan the session can run in code, before the call, keeps it out of the fixer's budget.
- **The clerk was used in 3 steps, then not.** One commit stopped on a format check and was finished in the session. The summariser was not needed.

## 4. Lessons of the round (53, from the index)

**What worked:**
- **One round of five, run as one.** A round shows classes one family hides ("A round shows a family class that one family hides"). Each step ran once.
- **The step-close check** stopped gates moving unseen (Measures: every figure the same, or moved by a named commit).
- **Code checks before writes** (in-memory reader diffs, full-key preview comparisons, status diffs per scope) caught over-reach in minutes.

**What drifted or repeated:**
1. **Version cascades, again.** Five lessons:
   - `store.ex` stales every stored rule;
   - a derived field stales every build;
   - a reader file in `law_start` stales every reading;
   - a new extent module must join the pattern versions;
   - every fold-version edit costs the switched families a refold.

   This was EP's first theme, and its "untangle the versions" was not done.
2. **Switched families carry every round.**
   - Their stored labels carry every step since their last refresh.
   - Shared reader edits need them in the same write.
   - Their checked rows need their own re-read.
   - A reader fix opens gate groups in families already through.

   This round refolded 388 switched laws for 139 new ones. The cost grows with each round.
3. **Tools that report success wrongly.** A build reported success while every law failed. `--accept` re-chose examples. A dry-run-looking register re-read rewrote feeds (EP's bug, still parked).
4. **A repeated lesson still not code.** The Credo `/tmp` copies (section 2).

**Bearing on the context (not to action):**
- **The next round** (the QQ register's families not yet covered) will hold more families than this one. Theme 2's carry cost grows with each one switched. Theme 1's cascades grow with the laws held.
- **One process without stopping** needs three things this round lacked:
  - tools whose success is true (theme 3);
  - versions narrow enough that a fix restales only what it reaches (theme 1);
  - bug entries closed by the sweep that clears them (section 2).

## 5. Decisions for Jason

**Decision 1: the Credo hook's `/tmp` copies.**
- **Question:** fix the hook now, before the next round, or leave it parked?
- **Aim:** none directly. It is tooling, and it stopped work twice in this round.
- **Options:**
  - (a) fix it now, as a short Tooling session: the hook removes its copy on exit (`trap`). About 30 min with a test commit.
  - (b) leave it parked, and keep clearing `/tmp` by hand.
- **Recommendation: (a).** It was parked three times, and EP's rule is that a lesson repeated must become code.
- **Decided (Jason, 2026-11-17): (a).** It is fixed in its own Tooling session after this one closes.

**Decision 2: an agent in the round's final QA** (session-start: "whether an agent helps a family's final QA is decided at its retrospective").
- **Question:** does one agent pass check the switched labels against the law's own text?
- **Aim:** `binds-on-date`.
- **Options:**
  - (a) no agent. The pass stays code alone, as in every step.
  - (b) one pass over 50 seeded rows of the round's switched labels: on a date, is the row in force and for where, read from legislation.gov.uk's stored text and the order. It is read-only and costed at about 150k (Sonnet). Its findings are parked by owner, with no fix round.
- **Recommendation: (b), once for this round.** Every check so far compares our readers with each other or with our golden. The round's last finds were 167 text-gone rows and 13 Part rows, and a code scan found them only at the switch, so nothing independent has yet read the labels against the law. EP's agent passes found real faults (Merge 63 changes). If it finds nothing new, the next round drops it.
- **Decided (Jason, 2026-11-17): (a) no agent for this round.** Instead:
  - **The extended golden (50) gates from now on.** It is `golden.exs` 27 plus `golden_extended.exs` 23, run with `mix lat.vocabulary --golden --extended`, and it gates every step of the next round from its first step. RULES Decision 10 said the 23 should join "at the next family's pass, from the first step". Maritime, EP and this round all ran the 27 only, so the rule was dropped without being decided.
  - **One agent check at the end of the next round,** costed then.
  - **Baseline run (Jason's go): 41/50.** All 27 pass, and 14 of the 23 extended pass. This is OH&S's round-9 score, so nothing moved. The 9 failing extended cases are listed in WORKFLOW, and the next round's first step names each one's owner. Report: `backend/data/reports/retrospective/fire-and-ohs-golden-extended.txt`.

**Decision 3: the round's carry cost, before the next round.**
- **Question:** should the version cascades and the switched families' refold be narrowed before the QQ round?
- **Aim:** `binds-on-date` holds either way. This is time.
- **Options:**
  - (a) carry on as now. Fold-version edits are batched before one write (this round's lesson, into WORKFLOW). The refold costs minutes per hundred laws.
  - (b) a tooling session first, to split the versions so that a fix restales only the rules it reaches (EP's "untangle the versions", item D).
  - (c) leave it to production hardening.
- **Recommendation: (a) now, with (b) as hardening's first todo.** The measured cost this round was hours, not days: 3 steps of 2 days, none from the refold alone. Splitting versions is the groundwork for one process, and belongs with it.
- **Decided (Jason, 2026-11-17): (a).** The WORKFLOW line is to batch fold-version edits before one write. The production-hardening session gains a first todo: split the versions.

**Recorded without a decision:** the 3 swept Sources entries are logged `fixed` here (frontmatter). The WORKFLOW line reads "a sweep that clears a parked fetch logs it fixed". The meta's Measures row is added.

## Docs changed

- RULES Decision 10: ruling 2026-11-17, the extended golden gates from now on.
- WORKFLOW: "After the first QQ round" (the check line measured, the extended golden and its baseline, batched fold-version edits, sweeps log fixed), and the prerequisite line.
- No DATA-ARCHITECTURE or GLOSSARY change: no table, flow or term is new.
