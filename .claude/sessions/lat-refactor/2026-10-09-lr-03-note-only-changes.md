---
session: 'LR-03: Effects Layer'
status: pending
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-03 Effects Layer (PENDING)

## Problem

Rescoped 2026-10-09 (Jason: "we're going the wrong way in the chain"). Changes the text markup doesn't carry — a whole section repealed with no `Repeal` element (1974/40 s.101, 1993/12 s.18), a change element with no `Extent`, an except-clause (1984/22 Pt. II "except in relation to ss. 13-15") — must come from the **effects layer** (changes feed), not note prose. Notes are hints of where to look. LR-02's note-text territory fallback (`NoteTerritory`, ~27,500 elements) is interim and is replaced here where an effect exists.

## Todo

- ⬜ Probe: changes-feed cache — keep each effect's id; coverage by law and by year; join rates effect ↔ note (`Commentary/@id` = effect id for `key-` notes) and effect ↔ markup `ChangeId`; legacy (`c…`) notes with no effect
- ⬜ Whole-provision changes not marked in the text, from effects (AffectedProvisions refs + territorial application) → `excluded_extent` (3 pending fixtures)
- ⬜ Change territory from effects for elements without `Extent`; note text only where no effect exists, flagged as such (or the amending law)
- ⬜ Classified diff; review

## Dependencies

- ⬜ LR-02 closed
- ✅ `LegislationGovUk.ChangesFeed` (#168), cache `data/cache/changes-feed*`
