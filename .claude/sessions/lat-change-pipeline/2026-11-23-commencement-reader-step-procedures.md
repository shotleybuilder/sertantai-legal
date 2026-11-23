---
session: 'Commencement reader: step procedures, feed figures and workflow rules'
status: active
opened: 2026-11-23
---

# Session: Commencement reader: step procedures, feed figures and workflow rules (ACTIVE)

## Problem

The Commencement reader retrospective (Decision 1 (d), (e), (f), Jason 2026-11-23) found the step's real procedures living as scratchpad scripts, the feed comparison's figures not reported as standard, and workflow gaps that cost the Waste, Water and Climate step days. First of the five sessions before the Extent reader.

## Todo

Plan approved 2026-11-23 (`~/.claude/plans/gleaming-doodling-matsumoto.md`). Pass rule: the four tasks and the Measures table exist with tests; their dry runs on the round agree with the closed step (0 stale substeps, 0 preview changes, 0 held moves, yardstick figures equal to `wwc-close-round.txt`); WORKFLOW carries the five rules; suite and Dialyzer green, no new Credo issue. No re-read, rebuild, fetch or fixture write in this session.

- ⬜ 1. Measure: time the round's stored-mode commencement check
- ⬜ 2. (d) `mix lat.reread`: the stale substeps in order (dry run) / `--run` under MemoryMax
- ⬜ 3. (d) `mix lat.held_moves`: held catalogue moves (dry run) / `--write`; `--new` with `--pending`
- ⬜ 4. (d) `--preview` for `--read` and `--read-amending`; `lat.stale --family F --reasons`
- ⬜ 5. (e) `mix lat.measures`: Commencement against the feed (yardstick counts, feed errors, groups by status and owner)
- ⬜ 6. (f) WORKFLOW: fetch list from Find; golden every Settle; no reader commit after the last re-read; decisions named; mid-step pass condition = new phase
- ⬜ 7. Check: tests, Credo diff, Dialyzer, suite; round dry runs match the closed step
- ⬜ 8. Close: skill names the tasks; session close; commits by path

## Dependencies

- ✅ Commencement reader retrospective closed (`2026-11-23-commencement-reader-retrospective.md`)
