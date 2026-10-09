---
session: 'LR-04: Parser Decomposition'
status: pending
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-04 Parser Decomposition (PENDING)

## Problem

`LatParser` → thin orchestrator; `LatParser.Text`, `.Ids`, `.Refs`, `.Walker` (+ `LatTerritory`). Red tests on new names → extract → defdelegate. Zero offline corpus diff per step.

## Todo

- ⬜ Build out when started (see meta)
- ⬜ From LR-03 acceptance (Gemini): extract the in-force qualifier parser out of `EffectTerritory` (`territory_scope` / `scope` / `provisions` / `in_scope?`) into its own module with a gallery of real qualifier strings; provision lists cover only s./ss./reg./regs. today (not Schs., Pts.)

## Dependencies

- ⬜ See meta session table
