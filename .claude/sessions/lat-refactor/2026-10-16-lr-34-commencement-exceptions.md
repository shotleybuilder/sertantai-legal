---
session: 'LR-34: Commencement Exceptions'
status: pending
opened: 2026-10-16
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-34 Commencement Exceptions (PENDING)

## Problem

LR-33 gives each law one start (`LawStart`: the general date its commencement clause states). Many clauses carry dated exceptions for particular provisions: "Subject to paragraph (3), this Order comes into force on [date]; Articles 45(4)(d) and (5)(a) and 48 come into force on the first day of the second month following …" (uksi 2015/1947), "Regulation 12 shall come into operation on 31st May 2015" (nisr 2015/236). Those provisions take the law's general date today. P1 (Jason 2026-10-16) put the exceptions on their provisions.

## Todo

- ⬜ Measure: clauses with dated exceptions across the corpus, and the provisions they name
- ⬜ Resolve the named provisions to rows (the `ProvisionText` / `EffectTarget` grammar, "Articles 45(4)(d) and 48", "Part II", "regulation 26, with the exception of paragraph (4)")
- ⬜ Write them as provision-level `commencement` records (a `LawStart` treatment each), J1 starting the row at its own commencement
- ⬜ Dry run → Jason → apply

## Dependencies

- ⬜ LR-33 law start applied
