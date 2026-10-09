---
session: 'LR-07: Change Metadata from Effects'
status: pending
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-07 Change Metadata from Effects (PENDING)

## Problem

`AmendmentNote` derives each note's `effect`, `effective_from`, `changed_by` and `change_id` from note text, and `LatStatus` builds row status (`in_force_partial`, `repealed_saved`) and row `effective_from` / `changed_by` on top of it. Notes are editorial and editable — not law (Jason, 2026-10-09: "building on sand"). These facts come from the effects layer (affecting provision, InForce dates and qualifications, applied, savings) where an effect exists; commencement by territory (LR-02 grounding) belongs here as status. Notes stay notes: `amendment_annotations` keeps their text, id and placement for display and as hints.

## Todo

- ⬜ Map each LAT fact to its effects source (and to the amending law where no effect exists)
- ⬜ effect / effective_from / changed_by from effects; note-only changes kept as notes, flagged (or checked against the law)
- ⬜ Row status from effects: partial / prospective / commencement by territory; repealed_saved from savings
- ⬜ From LR-03 checks: a retained repeal whose effect extent equals the row's extent makes no territory claim (1989/14 s.3(5)(aa)/(ba)/(c)(ia): "Act repealed (S.)" on S-only rows) — wholly in force → repealed status here
- ⬜ fractalaw contract impact (fields, hashes) → LH-05
- ⬜ Classified diff; review

## Dependencies

- ⬜ LR-03 (effects probe, effect ids)

## Pending tests this session must turn green (from LR-02)

`mix test --only pending` — tagged `pending: "LR-07"`:
- retained for no territory: the whole extent, repealed_saved
- a retained repeal with no territory (savings / purposes) is repealed_saved everywhere
