---
session: "Commencement reader: split the clause reader"
status: pending
opened: 2026-11-24
---

# Session: Commencement reader: split the clause reader (PENDING)

## Problem

The order split (2026-11-23-commencement-reader-order-split) left two large modules in the clause reader, the law's own commencement clauses:
- `LawStart.Provisions` (1,823 lines);
- `LawStart.Clause` (966 lines).

They hold the clause read path's stamp (`ReadVersion.Clause`), a different concept from the order reader's, so they were kept out of that session. As with `Order`, a fix to one form of clause should land in a module of one concept, small enough to review, with reading unchanged.

## Todo

- ⬜ Measure: the call graph of `Provisions` and `Clause`, the cut lines, and the tests that hold their behaviour
- ⬜ Baseline: the commencement catalogue (`lat.commencement_patterns`, or this reader's catalogue) and the own-clause re-read preview (`--read --family F --preview`); its differences are recorded as they stand
- ⬜ Red: one test file per new module
- ⬜ Green: module by module, with the existing tests unchanged; `ReadVersion.Clause` lists the new files
- ⬜ Pre-flight: the targeted tests, the Credo diff and Dialyzer; the catalogue and the preview identical to the baseline
- ⬜ The own-clause re-read, on Jason's go (its stamp moves once). Since b6d7e37d, a read stamp's list no longer moves the build's or the fold's stamp, so no rebuild should follow: confirm with `lat.stale`
- ⬜ Check and close: the commencement checks for the round and the 4 switched families, and golden 27/27

## Dependencies

- ✅ The order split: the method, and the stamp fix (b6d7e37d) that keeps a reader split from staling every build
- ⬜ Its plan, approved in plan mode
