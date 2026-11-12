---
session: 'Tooling: step-close check'
status: closed
opened: 2026-11-12
closed: 2026-11-12
step: Tooling
outcome: success

summary: >
  A step now closes on its gates re-run: mix lat.step_close --family F --step S runs every gate
  up to the step (the gate map ChangeVocabulary.Gate.Steps, also lat.gates --through), the
  switch-over's checked rows and the family's stale laws, and exits non-zero naming who takes each
  failure. On Environmental Protection through Switch-over it reproduced the recorded state (3 moved
  gates, 22 changed checked rows, 0 stale laws), each already parked with its owner.

decisions:
  - what: The step close reuses lat.gates and the check tasks' Step results, with the step list moved into a pure map
    why: lat.gates already re-ran every gate (Maritime Store and build) but nothing called it at a step's close, and its list was a module attribute
    result: one new task, one pure module; lat.label_checked and lat.stale --family return results; the other output unchanged
  - what: Checks that are no step's gate name who takes their failures (Step owner:)
    why: a changed checked row belongs to the step whose change moved it (traced), a stale law to re-parse, re-read or rebuild by reason
    result: each failure line names its owner
  - what: Golden stays out of the step close
    why: golden from inputs is the pre-flight's (review tooling); the close checks what can move after a step
    result: the close costs minutes, plus about 12 min once the Label fold gate is in

metrics:
  ep_step_close_switch_over: { gates_pass: 6, gates_fail: 3, sources_failing: 69, extent_failing: 2, amending_failing: 4, checked_rows: 744, checked_changed: 22, family_stale_laws: 0, exit: 1, lines: 416 }
  tests: { gate_tests: 25, architecture: 22 }

lessons:
  - title: The step close found nothing new on EP because Measures had already found it all, which is the point
    detail: The three moved gates and 22 changed checked rows were found by EP's Measures and Switch-over by hand. The same figures from one command show that a close at each step would have caught them the day they moved, not days later.
    tag: tooling
  - title: lat.stale without --family is a corpus count; a family's close needs its own laws
    detail: The corpus shows 842 stale laws on the old label path (parser and labels version); EP's own are 0. Scoping by family stops the old path's backlog failing every close.
    tag: tooling

bugs: []

artifacts:
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/steps.ex
  - backend/lib/mix/tasks/lat.step_close.ex
  - backend/lib/mix/tasks/lat.gates.ex
  - backend/lib/mix/tasks/lat.stale.ex
  - backend/lib/mix/tasks/lat.label_checked.ex
  - backend/lib/sertantai_legal/scraper/change_vocabulary/gate/step.ex
  - backend/test/sertantai_legal/scraper/change_vocabulary/gate/steps_test.exs
  - backend/test/sertantai_legal/scraper/change_vocabulary/gate/step_test.exs
  - .claude/commands/session-close.md
  - .claude/commands/session-start.md
  - docs/lat-change-pipeline/WORKFLOW.md

depends_on:
  - 2026-11-12-retrospectives-review-against-aims

enables:
  - every step of the next family closes on mix lat.step_close
  - the review tooling's pre-flight (the same Step results)
---

# Session: Tooling: step-close check (CLOSED)

## Problem

A gate passed at its step's close fails once later steps change shared code, and nothing re-runs it until Measures. The lesson is recorded four times over three families (CV-S10 Measures 2026-10-22; Maritime 2026-11-06, twice; Environmental Protection Measures 2026-11-11), and WORKFLOW's rule "Gates run on the final code" did not hold. EP: 3 gates moved (Sources 69, Extent 2, Amending-law 4), 22 OH&S checked rows changed unnoticed, 59 parser-stale laws seen only after the apply. Retrospectives review against aims, Decision 2 (Jason, 2026-11-12): its own session, done before the next family's first step.

## Todo

Plan approved 2026-11-12 (the plan for this session and the review tooling after it). Aim: every family step closes on gates that still pass (`prove-one-family`, `fix-where-owned`). Pass rule: new tests pass; compile with warnings as errors, the architecture tests and the Credo ratchet clean; one read-only run on Environmental Protection through Switch-over gives the state Switch-over recorded, any difference parked with its owner. Time box: half a day.

- ✅ The gate map in code (`ChangeVocabulary.Gate.Steps`, pure): the 14 steps in order, each with its gate task or none; `through/1`; `lat.gates` reads it and gains `--through S`
- ✅ `lat.label_checked` returns a `Step` ("Checked rows"); `lat.stale --family F` counts only the family's laws and returns a `Step` ("Stale laws")
- ✅ `mix lat.step_close --family F --step S`: gates through S, checked rows, the family's stale laws (`--switched` at Switch-over); one line each; non-zero exit naming the owner; read-only
- ✅ Tests: the map (order, `through`, unknown step, each task exists); the summary fails on each kind
- ✅ The step variant of `session-close`, WORKFLOW and the session-start step section call it before a step closes
- ✅ The Environmental Protection run through Switch-over (read-only, ~15 min; ask Jason)
- ✅ Close; code commit with hooks, session and docs commit `--no-verify`, by path; no push

## Out of scope

Fixing any gate the run finds moved (parked by owner); a Making laws gate (`lat.making_laws` returns no result); golden in the step close (it stays in the review tooling's pre-flight).

## Dependencies

- ✅ The review tooling (`2026-11-10-amending-law-reader-review-tooling.md`) follows this session (one active per lane); both before the next family's first step

## Built

- **The gate map** `ChangeVocabulary.Gate.Steps` (`backend/lib/sertantai_legal/scraper/change_vocabulary/gate/steps.ex`). It holds the 14 steps; 9 have a gate task. `through/1` gives a step's own gate and every earlier one. A step with no gate (Measures onwards) closes on all 9. `lat.gates` reads it, and `--through S` runs only those gates. `lat.gates` with no flag is unchanged.
- **`Gate.Step` gains `owner:`** for checks that are no step's gate. `lat.label_checked` returns "Checked rows", whose failures are parked with the step whose change moved them, traced with `--list`. `lat.stale --family F` prints and returns "Stale laws" for the family's LAT, labels and change register; the fix is by reason (re-parse, re-read, rebuild). The rest of the output is unchanged.
- **`mix lat.step_close --family F --step S`** (`backend/lib/mix/tasks/lat.step_close.ex`). It runs the gates through S, the checked rows, and the family's stale laws (`--switched` at Switch-over), prints one line each, and exits non-zero on any failure. Read-only.
- **Tests:** `gate/steps_test.exs` checks the order, `through`, a step with no gate, an unknown step, and that each task exists. `gate/step_test.exs` checks that each failure kind fails the close and is named by who takes it. The gate tests pass (25), as do the architecture tests (22). Compile with warnings as errors is clean, and the Credo diff is clean after one split (`lat.stale`'s `run` reached complexity 10, so its tail became `finish/3`).
- **Called from:**
  - `session-close` step 6b (a step closes only on PASS, or with each failure parked);
  - the session-start step section (the last todo before the close);
  - WORKFLOW "Gates run on the final code".

  The gate modules are outside every version's files, so this stales no stored result.

## The Environmental Protection run (read-only, 2026-11-12)

`mix lat.step_close --family "ENVIRONMENTAL PROTECTION" --step "Switch-over"`, about 15 min, exit 1:

| Check | Result | Already parked |
|---|---|---|
| Sources | FAIL, 69 | Sources (EP Measures) |
| Feed, Markup, Commencement readers | PASS | |
| Extent reader | FAIL, 2 | Extent reader (EP Measures) |
| Amending-law reader | FAIL, 4 | Amending-law reader (EP Measures) |
| Merge, Evidence, Label fold | PASS | |
| Checked rows | FAIL, 22 of 744 changed | Commencement reader (EP Switch-over) |
| Stale laws | PASS, 0 (the corpus's old path holds 842, not the family's) | |

It is the state Measures and Switch-over recorded, so the pass rule is met. Nothing new was parked. The next family's steps fix these when they reach their own.

Which doc changed: WORKFLOW ("Gates run on the final code"), with `session-close` (step 6b) and `session-start` (the step section). No rule changed, so RULES.md does not.

