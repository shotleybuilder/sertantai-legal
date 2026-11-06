---
session: 'Maritime Safety: Evidence'
status: closed
opened: '2026-11-06'
closed: '2026-11-06'
outcome: success
family: '💙 TRANSPORT: Maritime Safety'

summary: >
  Evidence passed for Maritime Safety on a code gate (Gate.Evidence): every value conflict and markup–feed disagreement grouped by attribute, sides and amending law, 59 groups all named in evidence.json (37 inherited from the Amending-law reader's gate), plus one agent pass over 50 agreeing changes. The evidence table's order was right throughout: the 100 wrong chosen values are the Commencement reader's parked misread, and 3 one-change forms are known limits. The agent's one cross-law find, amending SIs whose own clause is never read (94 laws, 1,473 changes without commenced_by), became a code gap cause and was parked.

decisions:
  - what: "Decision 1: the pass rule is a code gate over every V and D change plus one agent pass of 50 A changes; no resample (approved with the plan)"
    why: "the rule as last used (V by agents, D by pattern, A pooled to the 95% bound) is the sample → fix → resample loop forbidden on 2026-11-05; Merge's gate shape worked"
    result: "59 groups named; agent 29 OK / 1 wrong (known) / 20 gaps; 155,806 tokens; no evidence-table fix needed"
  - what: "Operation and level conflicts of the law's text inherit the Amending-law reader's status; date conflicts are named here, not inherited from Merge"
    why: "Merge gave the 90 SI 2006/1244 changes several causes, so no common status carried; the reader's Disagreement.cause covers operation and level"
    result: "37 of 59 groups inherited; MergeGate.items now names a group whose entries inherit several known: statuses"
  - what: "Gate.Evidence placed in change_vocabulary/gate/, outside ChangeVocabulary.Version's globs"
    why: "version.ex is itself hashed: adding to its except: list would stale every stored change and force rebuilds"
    result: "no stored change staled; no rebuild"

metrics:
  strata: { V: 180, D: 13, A: 3180 }
  gate: { groups: 59, inherited: 37, reviewed: 22, known: 59 }
  wrong_chosen: { commencement_reader_parked: 100, known_limits: 3 }
  agent_pass: { seed: 56, items: 50, ok: 29, wrong_known: 1, gap: 20, doubtful: 0, tokens: 155806 }
  gaps_text_changes: { commenced_by: 2221, of_which_no_rules: 1478, date: 50, level: 15 }
  ohs_regression: { V: 133, D: 39, A: 3029 }
  golden: "27/27"
  mix_test: "10,151 pass"

lessons:
  - title: Inherit earlier gates' statuses by cause, never by step
    detail: "The Amending-law reader's Disagreement.cause names the same operation and level conflicts the evidence gate sees, so 37 groups needed no second review. Merge's causes did not carry over: one date conflict sat under five different join bases. Inherit only where the earlier gate's cause is about the same attribute."
    tag: tooling
  - title: A misread primary claim winning is the reader's, not the table's
    detail: "All 100 wrong chosen values were the Commencement reader's misread start winning over legislation.gov.uk's right date, as law-text-wins orders. Judging the table's order separately from the reading kept the evidence step to zero fixes."
    tag: data
  - title: Spend the agent pass on gaps too
    detail: "The A sample showed no wrong table rule, but 12 of its gaps had one cause: amending SIs with no commencement rules though their own clause is stored. Measured in code, that was 94 laws and 1,478 gaps, a coverage hole the strata never showed."
    tag: data
  - title: A new check module goes outside the versioned globs
    detail: "ChangeVocabulary.Version hashes version.ex itself, so editing its except: list stales every stored change. Put a check module in a directory no pattern matches (change_vocabulary/gate/)."
    tag: tooling

bugs:
  - pattern: "An amending SI's own commencement clause is held in the store but never read into commencement_rules, so its changes have no commenced_by and their date falls back to the feed (e.g. SI 2018/667 reg.1 'come into force on 12th July 2018'; SI 2018/1202, 2019/308, 2019/509)"
    category: amending-law-own-clause-unread
    module: commencement/ (Commencement.Amending; mix lat.commencement --read-amending coverage)
    affected: "94 amending laws, 1,473 Maritime Safety text changes without commenced_by (gate gaps 'amending law has no commencement rules' 1,478)"
    fix: "Read every amending law's own clause held in the store (not only those without LAT), then rebuild; the gate's gap cause measures it"
    step: Commencement reader
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/evidence.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/gate/evidence_test.exs
  - backend/test/fixtures/evidence/evidence.json
  - backend/lib/mix/tasks/lat.evidence_check.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/merge_gate.ex
  - docs/lat-change-pipeline/WORKFLOW.md
  - docs/lat-change-pipeline/RULES.md
  - .claude/skills/evidence-check/SKILL.md
  - backend/data/reports/evidence/maritime-gate-review-1.md

depends_on:
  - 2026-11-06-maritime-safety-merge

enables:
  - "Maritime Safety: Label fold"
  - "Commencement reader: amending-law-own-clause-unread, amending-law-start-misread"
---

# Session: Maritime Safety: Evidence (CLOSED)

## Problem

Evidence is the next step (WORKFLOW.md step 8) for TRANSPORT: Maritime Safety, after Merge passed (a1dc2658). Its aim (AIMS `law-text-wins`, `one-change-per-event`): each attribute of a merged change comes from the right source by the evidence table, and every disagreement between the law and legislation.gov.uk is reported like for like. The faults: a wrong value, a false conflict, a missed conflict.

## Todo

- ✅ Open the session: todos, Decision 1, baselines
- ✅ The gate (TDD): `Gate.Evidence`; `--gate` in `lat.evidence_check` (`--by-design` not needed: `--stratum A` is the population); `evidence.json` started, inherited statuses
- ✅ Review every V and D group not inherited, in the sources' records: `fix:`, `known:` or `check:`, with a report
- ✅ The one agent pass over 50 A changes; finds become code groups; cost recorded
- ✅ Fix the `fix:` groups (none needed; triage into RULES.md; bug parked) — by reach (TDD): pre-flight on the laws concerned; triage into RULES.md; other steps' bugs parked
- ✅ (no fix, so no restore point or rebuild) Restore point and family rebuild (only if a fix was made); gate PASS, OH&S strata, golden 27/27, `mix test`
- ✅ Docs: WORKFLOW.md step 8, the `evidence-check` skill and history, parked Evidence bugs marked
- ✅ Close the session and the meta row; code and session commits separate; no push

## Dependencies

- ✅ Maritime Safety: Merge closed (2026-11-06)
- ✅ Plan approved at ExitPlanMode (2026-11-06)

## Decision 1: the pass rule (approved with the plan)

**The question.** How does Evidence pass for this family?

**The aim it bears on.** `law-text-wins` and like-for-like conflicts; and the process rule of 2026-11-05: one agent pass at most, never sample → fix → resample.

**The options.**
- The rule as last used (OH&S, 2026-10-29): V in full by agents, D by pattern, A pooled to the 95% bound. Five rounds for OH&S: the loop the 2026-11-05 rule forbids.
- The shape picked for Merge (Jason with Gemini): a code gate, plus one agent pass over the by-design population.

**Picked: the Merge shape.**
1. A code gate, `mix lat.evidence_check --family F --gate [--all]`. Every V and D change sits in a group, `"<attribute>: <side> against <side> @ <amending law>"`, named in `test/fixtures/evidence/evidence.json` (`known:`, `fix:` or `check:`). Statuses an earlier gate already gave the same change are inherited: operation conflicts from the Amending-law reader's `disagreements.json`; date conflicts from Merge's `merges.json`. Gaps (no source claims a value) are published by cause and never fail.
2. One agent pass of 50 A changes on a new seed, to find a class the grouping hides. Its finds become code groups; no resample.

## Baselines (2026-11-06, before any change)

**Maritime strata:** 117 laws, 29,944 changes, 3,373 in a stratum.

| Stratum | Count | Detail |
|---|---|---|
| V value conflicts | 180 | date commencement/feed 96 (SI 2006/1244 90; 2025 c.36 3; 2006 c.36 1; 2015 c.15 1), operation law_text/feed 82, operation law_text/markup 16, level law_text/feed 7, level law_text/markup 2, commenced_by commencement/feed 4 |
| D markup vs feed | 13 | 6 patterns: level provision/words 3; operation inserted/renumbered 5; inserted/substituted 3; substituted/inserted 1; level words/provision on an insertion 1 |
| A agreeing | 3,180 | level 3,129, operation 3,089, by 1,995, date 1,524, partial 1,156, territory 139, commenced_by 26 |

Gaps (no source claims): date 781, commenced_by 3,665, by 23,588 (mostly commencement-only changes).

**OH&S (regression baseline):** V 133, D 39, A 3,029. V was 8 at its pass (2026-10-29); the drift is mostly 97 operation conflicts, law text against feed, after later Amending-law reader rounds. Recorded, not chased.

**Parked Evidence bugs (OH&S):** a feed Type error wins where the law's text makes no claim (REACH Art 138(1)); moved words carried as renumbered (SI 1999/3242). Fixed only if a gate group shows them in Maritime over the triage size.

## The gate (todos 2–3)

`ChangeVocabulary.Gate.Evidence` (`change_vocabulary/gate/evidence.ex`, 7 tests) and `mix lat.evidence_check --gate [--all]`. Statuses are in `test/fixtures/evidence/evidence.json`.

**Placed outside `ChangeVocabulary.Version`'s globs** (a new `gate/` directory). The version hashes `version.ex` itself, so adding the module to its `except:` list would have staled every stored change.

**Inheritance, as built:**
- Operation and level conflicts of the law's text take the Amending-law reader's status (`Disagreement.cause`).
- Merge's statuses were **not** inherited for date conflicts, against the plan. Merge gave those 90 changes several causes, so no common status carried over. The date groups are named here by amending law instead, citing the parked bug.
- `MergeGate.items/3` now names a group whose entries inherit several `known:` statuses (each kept).

**Result: PASS, 59 groups** (37 inherited, 22 reviewed). Review: `backend/data/reports/evidence/maritime-gate-review-1.md`.
- 100 wrong chosen dates and commenced_by values, all the Commencement reader's parked `amending-law-start-misread`. The table's order is right.
- 3 one-change known limits:
  - 2003 c.20 s.311: the first commencement claim, not the earliest;
  - SI 2006/1244: the heading h.162's level;
  - SI 2019/270: a number wrapped by legislation.gov.uk.
- No false conflict and no wrong table rule.

**Gaps** (text changes, published): commenced_by 2,221, date 50, level 15.

## The agent pass (todo 4)

Seed 56, 50 A changes, sample `backend/data/reports/evidence/maritime-a-56.json`; **155,806 tokens**.

Result: **29 OK, 1 wrong (known), 20 gaps, 0 doubtful, no new class.** Pairs: 1 of 38 wrong.
- **The wrong item:** SI 2018/667 reg.2(4)(b) lacks an opening quote mark, so "(1B)" is read as a place. This is the logged one-law wording K3 (Amending-law reader).
- **Gap causes:**
  - **12 of the sampled amending SIs have no commencement rules,** though their own clause is in the store. Over the family that is 94 amending laws and 1,473 changes. Each date falls back to the feed and agrees with the clause.

    It became a code group: the gate's gaps name "amending law has no commencement rules" (1,478). It is parked with the Commencement reader (`amending-law-own-clause-unread`).
  - Schedule amending provisions unread (a v0.1 limit).
  - One modification row.
- **An observation, taken into the skill:** `Conflicts`' like-for-like pair (inserted for substituted) applies to the feed as well as to the markup (MSA 1995 s.306(1), 1997 c.28). The rule's text named only the markup.

## Results (todos 5–7)

- **No evidence fix needed,** so there was no restore point and no rebuild.
- **Pass rule:**
  - gate PASS (59/59);
  - the agent pass done (155,806 tokens);
  - OH&S unchanged (V 133, D 39, A 3,029);
  - golden 27/27;
  - `mix test` 10,151 pass.
- **The two parked Evidence bugs from OH&S** (a feed Type error winning, moved words carried as renumbered) don't reach Maritime: no gate group shows them. They stay open.
- **Quality statement.** The evidence table chose by its order in every disagreement reviewed.
  - The wrong values are the Commencement reader's (100, parked) plus 3 one-change known limits.
  - In the agent's sample, 29 of 50 changes were right, 1 was a known one-law wording and 20 were coverage gaps.
  - commenced_by is the main gap: 2,221 text changes, 1,478 of them where the amending law holds no rules.

## Parking list

- Commencement reader: `amending-law-own-clause-unread`. 94 amending laws' own clauses are not read into rules, so 1,473 changes lack commenced_by.
