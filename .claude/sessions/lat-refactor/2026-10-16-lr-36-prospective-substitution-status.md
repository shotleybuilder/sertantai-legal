---
session: 'LR-36: Prospective Substitution Status'
status: pending
opened: 2026-10-16
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "A pending (prospective) substitution of a provision makes its current, in-force text read prospective (D3 counts an own substitution with no in-force date as a commencing change)"
    category: wrong status
    module: LabelProjection (D3 commencing_kind?)
    affected: "117 rows today (label prospective, markup in_force); LR-35 adds ukpga 1988/52 s.127(3)(a)-(d)"
    fix: "A substitution or insertion that is pending (prospective, not applied) dates the new text, not the current one: it doesn't make an existing row prospective; Jason decides"
    status: open
---

# Session: LR-36 Prospective Substitution Status (PENDING)

## Problem

Found in LR-35's dry run (2026-10-16). ukpga 1988/52 s.127(1)-(4) were substituted by the Road Safety Act 2006 (UK_ukpga_2006_49), never commenced. The current s.127 text is in force (the CLML marks it in force), but the labels read s.127(1)-(3) prospective today: D3 treats the row's own substitution with no in-force date as a commencing change. Corpus-wide, 117 rows read prospective where their markup reads in force. LR-35's document-order ranges extend the same reading to s.127(3)(a)-(d).

## Todo

- ⬜ Measure: the 117 rows by cause (pending substitution, pending insertion of the row itself, other)
- ⬜ Jason: what a pending substitution means for the current text
- ⬜ Build, dry run → Jason → relabel

## Dependencies

- ✅ LR-35 applied (2026-10-16)
