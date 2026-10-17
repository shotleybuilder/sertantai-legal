---
session: 'LR-36: Prospective Substitution Status'
status: active
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

# Session: LR-36 Prospective Substitution Status (ACTIVE)

## Problem

Found in LR-35's dry run (2026-10-16). ukpga 1988/52 s.127(1)-(4) were substituted by the Road Safety Act 2006 (UK_ukpga_2006_49), never commenced. The current s.127 text is in force (the CLML marks it in force), but the labels read s.127(1)-(3) prospective today: D3 treats the row's own substitution with no in-force date as a commencing change. Corpus-wide, 117 rows read prospective where their markup reads in force. LR-35's document-order ranges extend the same reading to s.127(3)(a)-(d).

## Todo

- ✅ Measure: the rows by cause (below)
- ✅ Jason (2026-10-17: "Agree, go"): a pending change leaves the current text in force; `pending_change` gap
- ⬜ Build, dry run → Jason → relabel

## Dependencies

- ✅ LR-35 applied (2026-10-16); LR-37 applied (2026-10-17)

## Measure (2026-10-17)

After LR-35 and LR-37: **123 rows in 25 laws** read prospective today while their CLML markup reads in force. The changes on them that could make them prospective (own insertion / substitution / commencement with no in-force date): feed `inserted` prospective, not applied 57 (+4 "added"), feed `substituted` prospective, not applied 50 (+ ~10 "substituted for …"); our markup `inserted` undated 11 and amending-law `inserted` undated but applied 3 (neither counts as informative under the current rule; the rows also carry a feed change).

**Cause:** `LabelProjection.informative?/1` counts a change that is prospective **and not applied** as a commencing change still to come, so its row reads prospective until it's dated. That fits only a provision that doesn't exist yet; but every LAT row comes from the revised text, and a provision legislation.gov.uk holds as not yet in force is marked prospective there (J2 reads it). For an existing row, a pending change is about the *new* text: ukpga 1988/52 s.127(1)-(4) "substituted" by the Road Safety Act 2006, never commenced — the current s.127 is in force.

## Proposal (Jason 2026-10-17: "Agree, go")

- **D1.** Only a dated entry makes a change a commencement still to come. A prospective change not yet applied to the revised text leaves the current text's status alone; the row is listed as a **`pending_change`** gap (new, so the pending change stays visible). A provision the revised text marks prospective still reads prospective (J2).

Built tests first (2 tests; 45 projection tests pass). Dry run: `lr36_dry` (relabel, all laws) running.

## Dry run 1 (`lr36_dry`): one fault, fixed

0 errors; 185 label changes in 24 laws (prospective → in force 122, effective_from gained 53, changed_by gained 10); unknown today unchanged (18,326). But markup conflicts rose 8,184 → 10,050, all but 7 in one law: **asc 2026/5**, whose 119 undated "coming into force" effects (prospective, not applied) no longer made its provisions prospective; J2 restored prospective from the text, so labels didn't move, but 1,859 conflicts were logged. A pending **commencement** still means not yet in force — the agreed rule is about pending insertions and substitutions (new text). Narrowed: only an insertion or substitution that is prospective and not applied is pending for the new text; a pending commencement keeps its meaning (test added; 46 projection tests pass). Dry run 2 (`lr36_dry2`) running.
