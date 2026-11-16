---
session: 'Fire and OH&S: Measures'
status: closed
opened: 2026-11-16
closed: 2026-11-16
outcome: success
family: 'Fire and OH&S (round)'
parent: lat-change-pipeline/2026-11-13-fire-and-ohs-meta.md

summary: >
  Every in-scope figure the round's ten step sessions published was checked against today's store: the same, or moved
  by a named later commit, with no gate moved to a failure (Maritime found 3, EP 4). Every check, gates included, ran
  twice at seed 1116 and replicates byte for byte; the register gained three rows over code already tested; no code
  changed and no agent pass ran.

decisions:
  - what: The pass rule, EP's unchanged (no agent pass; 3 items read by hand)
    why: Jason, plan approved 2026-11-16; no agent QA in any step (2026-11-13)
    result: all five pass rules met
  - what: No measure fault, so no code change; the register gaps are rows over tested code
    why: the audit and the hand items found nothing classed wrong; the three unregistered figures are printed by tasks over tested modules
    result: checked_rows, sources_register_differences, stored_changes added to the register

metrics:
  audit: { steps: 10, same_steps: 5, moved_explained: 5, gates_failing_now: 0, register_rows_added: 3 }
  replicability: { samples_identical: 10, printed_identical: 13, pass_minutes: 5.5, seed: 1116 }
  round_today: { stored_changes: 31711, text_changes: 5100, law_and_derived: 2736, law_only: 371, derived_only: 1993, undated: 154, commenced_by_named: 3427 }
  switched_today: { ep_text_changes: 8048, occupational_text_changes: 5042, maritime_text_changes: 3142 }
  hand_check: { items_read: 3, wrong: 0, agent_tokens: 0 }
  regression: { golden: "27/27", mix_test: 11234, measures_tests: 62 }
  step_close: { gates: "all PASS", checked_rows: PASS, stale_laws: "139 (labels; change register 0), parked with Store and build" }

lessons:
  - title: The step-close check stopped gates moving unseen
    detail: Maritime and EP each found 3-4 gates that had passed at their step and failed by Measures. Here none had, because every step since the round began closed with lat.step_close re-running every earlier gate. Measures' audit is now mostly dating moved figures, not finding failures.
    tag: tooling
  - title: Saved step-close logs date every moved figure
    detail: Each later step's step-close log prints the earlier checks' figures, so a moved figure (Sources' needs 1,173 → 1,176 → 1,178 → 1,160 → 1,150) is placed between two closes without re-running anything. Keep saving them under each step's reports folder.
    tag: data

bugs: []

artifacts:
  - backend/data/reports/measures/fire-and-ohs-audit.md
  - backend/data/reports/measures/fire-and-ohs-step-close-2026-11-16.txt
  - .claude/skills/measures-check/SKILL.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-15-fire-and-ohs-label-fold.md

enables:
  - "Fire and OH&S: Store and build (the round's 139 stale labels; the switched families' 388)"
---

# Session: Fire and OH&S: Measures (CLOSED)

## Problem

Step 10 of the LAT Change Pipeline for the Fire and OH&S round. Every figure the round's ten step sessions published must be believable: one name and one meaning, printed by tested code, replicable. Later rebuilds and the Label fold's new rules have moved the store since several were published. No Measures bugs are parked. Plan: `~/.claude/plans/gleaming-doodling-matsumoto.md`, approved by Jason on 2026-11-16.

## Todo

- ✅ Open the session and meta row; draws pass 1 at seed 1116 (the round); `lat.measures` baselines for EP, Occupational and Maritime
- ✅ Audit: every in-scope figure of the ten round sessions against the register, task, code, test and today's value (`backend/data/reports/measures/fire-and-ohs-audit.md`); failing gates parked with their steps
- ✅ Register gaps: a register row, a print line with a test, or "hand tally, report only"
- ✅ Hand check: the hand sample replicates (pass 2); `measures/` tests; 3 items read by me
- ❌ Any measure fault: none found (audit and hand items), so no code change
- ✅ Verify: draws pass 2 against pass 1; switched families' `lat.measures` against baselines; golden 27/27; `mix test`
- ✅ Step close: `mix lat.step_close --family "Fire and OH&S" --step "Measures"`
- ✅ Docs and close: register, skill history, WORKFLOW step 10, meta row, commits

## Dependencies

- ✅ Fire and OH&S: Label fold closed and pushed (f0ddab0c)
- ✅ Environmental Protection: Measures (`draws.sh`, the hand sample, the register)

## Pass rule (DECIDED: plan approved, Jason 2026-11-16)

1. **Register complete:** every data figure in the round sessions' closing `metrics:` has a register entry, a task and a test, or is marked "hand tally, report only".
2. **Audit:** each figure is the same, moved by a named later commit, or a finding. A gate failing today is parked with its step.
3. **Replicable:** two `draws.sh` passes at seed 1116 give byte-identical samples and identical filtered outputs.
4. **Hand check, no agent pass:** the hand sample replicates; the measure-fault classes stay tested; 3 items read by me.
5. **No regression:** `mix test`; golden 27/27; the switched families' `lat.measures` unchanged from this step's baseline.

## Parking list

## Draws pass 1 (before any code change)

Seed 1116, `draws.sh` (scratchpad `measures/fire-and-ohs-p1/`), 5½ min, every check exit 0. Sources took 100 s; Making laws 40 s; Commencement 45 s; the label fold 8 s (fold cache); the rest 4–30 s. Baselines from `lat.measures` (`switched-baseline.out`): EP 8,048 text changes, Occupational 5,042, Maritime 3,142. The round: 31,711 stored changes, 5,100 text changes.

## Audit (report `backend/data/reports/measures/fire-and-ohs-audit.md`)

- **Every gate passes today.** None moved to a failure since its step closed (Maritime found 3, EP 4).
- **The same as published:** Feed reader, Markup reader, Merge, Evidence and the Label fold, with their gates; the Commencement reader's rows and most gaps.
- **Moved, explained:**
  - Making laws: live 219 → 213 (5 refiled by Decision 6 at the step's apply; SI 1994/232 revoked at Sources). The one disagreement, SI 1989/76, is Decision 4's review.
  - Sources: needs 1,173 → 1,150, tracking each later rebuild (step-close logs date each move); failures 0.
  - Extent: text changes 5,156 → 5,100, bound by law text 76.1% → 76.0%; Commencement appointed 142 → 143 (the Amending-law reader's writes and Merge's rebuild).
  - Amending: A/D/L 2,520/257/337 → 2,522/255/334, gate 175 → 169 groups, all named (Merge, a3958cef).

## Register gaps

Three rows, the code already tested: `checked_rows` (`Checked.compare/2`), `sources_register_differences` (`Sources.register_stats/1`), `stored_changes` (`Store.for_law/1`). The one-off probes and tallies are report only (named in the audit).

## Hand check (no agent pass)

- Three seed-1116 items, read by me, all classed right (the audit lists them): a feed-only partial repeal read with no rule (body), a joined NI revocation, and a dropped number the law alone states.
- The hand sample's replication is checked in pass 2.

## Verify

- **Draws pass 2** against pass 1 (seed 1116, `fire-and-ohs-p2/`, 5½ min): all 10 samples byte-identical (`cmp`, the hand sample included) and `making.csv` too; all 13 printed outputs identical once log, compile and path lines are filtered.
- **The switched families' `lat.measures`:** unchanged (EP 8,048, Occupational 5,042, Maritime 3,142 text changes).
- **`measures/` tests:** 62 pass (Maritime's measure-fault classes held).
- **Golden:** 27/27. **`mix test`:** 11,234 passed, 2 skipped, 0 failures.

## Step close (`backend/data/reports/measures/fire-and-ohs-step-close-2026-11-16.txt`)

Every gate PASS (Sources, the five readers, Merge, Evidence, the Label fold) and Checked rows PASS. Stale laws FAIL, 139: the round's labels (LAT or labels 139, change register 0), the same as at the Label fold's close and parked with Store and build.

## Docs

- The `measures-check` skill: three register rows, and the history.
- WORKFLOW step 10: the Fire and OH&S note.
- RULES: no rule was decided here. DATA-ARCHITECTURE and GLOSSARY: no table, flow or term changed.
- The parking list is empty.
