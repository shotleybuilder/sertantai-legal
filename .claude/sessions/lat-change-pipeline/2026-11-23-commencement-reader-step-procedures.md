---
session: 'Commencement reader: step procedures, feed figures and workflow rules'
status: closed
opened: '2026-11-23'
closed: '2026-11-23'
outcome: success
summary: >
  The Commencement reader step's scratch scripts became tasks (lat.reread, lat.held_moves, --preview for --read and --read-amending, lat.stale --reasons), and the feed yardstick's standard figures are recorded by each family check and published by lat.measures. WORKFLOW carries the retrospective's five rules for every step.
  Every dry run on the round matches the closed step: 0 stale commencement rules, 0 preview changes, 0 held moves, and the yardstick figures equal to the close report.
decisions:
  - what: The new modules live in scraper/step_procedures/ and change_vocabulary/measures/, outside every version stamp
    why: "Commencement.ReadVersion hashes commencement/*.ex, and read_version.ex is in that folder, so a new module there (or an edit to its except list) stales every stored rule; the build's stamp covers commencement/check.ex"
    result: the round's staleness unchanged (565 laws, 0 on this reader) after the commit
  - what: Measures publishes the check's recorded figures rather than computing them again
    why: the figures come from the check's own rows; sharing its code would mean editing check.ex, which the build's version stamp covers; the record carries when it ran and whether that follows the last build
    result: the plan's fallback, taken for a different reason than planned (the stored check takes 167 s)
  - what: The difference groups are published by status and by row kind, not by owning step
    why: the statuses in feed_differences.json do not record an owner
    result: an owner field for the statuses is a question for Jason
metrics:
  round_dry_runs: { stale_rules: 0, preview_own_laws: 565, preview_amending_laws: 969, preview_changes: 0, held_examples_orders: 454, held_moves: 0, new_patterns: 0 }
  yardstick_round: { agree: 36261, differ: 1030, feed_error: 690, feed_only: 684, feed_partial_only: 298, own_only: 61245, neither: 9497, groups: 21 }
  timings_s: { stored_check: 167, held_moves: 12, preview_read: 10, preview_amending: 16, reread_dry_run: 2 }
  tests: { targeted: 6773, new: 18 }
  store_stale_rules: { stale: 26427, total: 72043 }
lessons:
  - title: A version stamp that hashes a folder stales everything when a tool file lands in it
    detail: "Commencement.ReadVersion globs commencement/*.ex and holds itself; the first draft put lat.reread's module in commencement/, which would have staled all 72,043 rules. Tools now live in scraper/step_procedures/; the staleness session takes the fix."
    tag: tooling
  - title: The re-read chain exposes other families' staleness
    detail: "Its dry run on the switched Fire and OH&S lists 454 laws' rules on older reader code, staled by the Waste, Water and Climate fixes; 26,427 rules store-wide."
    tag: data
bugs: []
artifacts:
  - backend/lib/mix/tasks/lat.reread.ex
  - backend/lib/mix/tasks/lat.held_moves.ex
  - backend/lib/sertantai_legal/scraper/step_procedures/
  - backend/lib/sertantai_legal/scraper/change_vocabulary/measures/feed_yardstick.ex
  - docs/lat-change-pipeline/WORKFLOW.md
  - .claude/skills/commencement-reader-check/SKILL.md
depends_on:
  - 2026-11-23-commencement-reader-retrospective
enables:
  - "Commencement reader: staleness that follows what changed"
---


# Session: Commencement reader: step procedures, feed figures and workflow rules (CLOSED)

## Problem

The Commencement reader retrospective (Decision 1 (d), (e), (f), Jason 2026-11-23) found the step's real procedures living as scratchpad scripts, the feed comparison's figures not reported as standard, and workflow gaps that cost the Waste, Water and Climate step days. First of the five sessions before the Extent reader.

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Pass rule: the four tasks and the Measures table exist with tests; their dry runs on the round agree with the closed step (0 stale substeps, 0 preview changes, 0 held moves, yardstick figures equal to `wwc-close-round.txt`); WORKFLOW carries the five rules; suite and Dialyzer green, no new Credo issue. No re-read, rebuild, fetch or fixture write in this session.

- ✅ 1. Measure: time the round's stored-mode commencement check
- ✅ 2. (d) `mix lat.reread`: the stale substeps in order (dry run) / `--run` under MemoryMax
- ✅ 3. (d) `mix lat.held_moves`: held catalogue moves (dry run) / `--write`; `--new` with `--pending`
- ✅ 4. (d) `--preview` for `--read` and `--read-amending`; `lat.stale --family F --reasons`
- ✅ 5. (e) `mix lat.measures`: Commencement against the feed (yardstick counts, feed errors, groups by status and owner)
- ✅ 6. (f) WORKFLOW: fetch list from Find; golden every Settle; no reader commit after the last re-read; decisions named; mid-step pass condition = new phase
- ✅ 7. Check: tests, Credo diff, Dialyzer, suite; round dry runs match the closed step
- ✅ 8. Close: skill names the tasks; session close; commits by path

## Dependencies

- ✅ Commencement reader retrospective closed (`2026-11-23-commencement-reader-retrospective.md`)

## Results (2026-11-23)

- **Measure:** the round's stored-mode check takes 167 s, and its yardstick equals the close report.
- **Tasks** (10323064; 18 new tests; outside every version stamp):
  - `mix lat.reread --family F` prints the chain; `--run --tag T` runs it. Round: no stale rule (2,369 laws, 45,373 rules). Fire and OH&S: 6 substeps.
  - `mix lat.held_moves`: 0 of the held answers moved (orders 454 examples); `--new`: 0 new patterns.
  - `--preview` for `--read` and `--read-amending` (`--read` also takes `--family`). Round: 565 and 969 laws, 0 changes, nothing written.
  - `mix lat.stale --family F --reasons`. Round: labels_version 565, extent_reader 263, as at the close.
  - The feed yardstick: recorded by `lat.commencement_check --family F` (`data/reports/commencement-reader/yardstick/<family>.json`) and printed by `lat.measures --family F`. Its round figures equal the close report.
- **WORKFLOW:** the five rules are in "How a step is run":
  - the fetch list from Find;
  - golden at every Settle;
  - no reader commit after the last re-read;
  - a mid-step pass condition is a new phase;
  - decisions named.
  - Step 4 names the tasks.
- **Checks:** 6,773 targeted tests pass; Credo diff adds no issue; Dialyzer passes; the commit hook passes.
- **Found, passed on:** to the staleness session's todos:
  - the stamps' folder globs;
  - the 26,427 stale rules elsewhere, among them Fire and OH&S.

## Close

- **Docs changed:** WORKFLOW (five rules, the tasks); the skill. RULES unchanged: these are process lines, not rules.
- **Bugs:** none.
- **Parking:** none; the two findings went to the staleness session.
