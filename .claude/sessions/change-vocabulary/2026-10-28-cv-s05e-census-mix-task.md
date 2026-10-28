---
session: 'CV-S05e: Census Mix Task'
status: pending
opened: '2026-10-28'
parent: change-vocabulary/2026-10-22-cv-s05-extent-reader.md
depends_on:
  - change-vocabulary/2026-10-27-cv-s05d-whole-reader-census.md
---

# Session: CV-S05e: Census Mix Task (PENDING)

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
