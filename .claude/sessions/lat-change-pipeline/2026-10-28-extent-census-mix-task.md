---
session: 'Extent reader: Census Mix Task'
status: closed
opened: '2026-10-28'
closed: '2026-11-25'
outcome: deferred
summary: >
  Superseded. The census was delivered as `mix lat.extent_census` by the session "Extent census as a task (#192)" (2026-11-07), proven byte for byte against run-07. Its three leftovers (a `--family` population, the noise-bin audit, the census in the skill's steps) moved to the pending session "Extent reader: step procedures" (Extent reader readiness review, 2026-11-25).
decisions:
  - what: Closed as superseded, leftovers moved
    why: the task exists; the rest is step procedure work, decided in the readiness review
    result: three todos in 2026-11-25-extent-reader-step-procedures.md
lessons: []
bugs: []
artifacts: []
depends_on:
  - 2026-11-07-extent-census-as-a-task
enables:
  - "Extent reader: step procedures"
parent: archive/change-vocabulary/2026-10-22-cv-s05-extent-reader.md
---

# Session: Extent reader: Census Mix Task (CLOSED)

## Problem

CV-S05d's whole-reader census found the extent reader's long-tail misreads by count (129 → 57 silent candidates over six runs), and the agent check passed once they were fixed (seed 20). It is a Python prototype in the run folders (`backend/data/experiments/cv-s05d-whole-reader-census/run-06/`: `dump.exs`, `finder.py`, `census.py`, `bench.py`). Each round and each new family should run it as a read-only mix task with tests (Jason 2026-10-28: "Close; PENDING task"). Start it when the next family enters the change-vocabulary workflow.

## Todo

- ⬜ Port `finder.py` as pure modules sharing no code with the reader (no `RefList`, `Parts`, `Forms`), with tests from run-05's triage wordings
- ⬜ Port `census.py` (verdicts, unnamed, scope extract) and `bench.py` (recall bench of past agent NEW)
- ⬜ A thin `mix lat.extent_census [--family F] [--out DIR]` over `Extent.ReadCache`, read-only
- ⬜ The `--family` population: every catalogue sentence class plus the sweep's uncaught sentences (deferred from CV-S05d)
- ⬜ Noise-bin audit as a census section: each sweep `noise:*` label checked by the same test (deferred from CV-S05d)
- ⬜ Add the census to the `extent-reader-check` skill's steps; parity with run-06 (57 silent, 329 unnamed) as the acceptance test

## Dependencies

- ✅ CV-S05d Whole-Reader Census (closed): prototype, run-01 to run-06, triage format

## Close (2026-11-25)

Superseded by `mix lat.extent_census` (`2026-11-07-extent-census-as-a-task.md`). The `--family` population, the noise-bin audit and the census in the skill's steps are todos in `2026-11-25-extent-reader-step-procedures.md`. The agreement-with-run-06 acceptance was replaced by run-07 parity.
