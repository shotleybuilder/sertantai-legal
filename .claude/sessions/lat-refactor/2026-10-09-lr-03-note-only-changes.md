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

## Pending tests this session must turn green (from LR-02)

`mix test --only pending` — tagged `pending: "LR-03"`:
- note territory (no attribute)
- note territory, no attribute (1990/8 s.150(1)(b) "or 24ZA(c)")
- note territory, no attributes
- retained for some territories (note)
- a Part inserted for W (note only): 2010/2214 Pt. 2B
- retained for E+W with an inner E+W insertion: plain + excluded (Q3; 1974/40 s.30(5))
- attribute and note both name territories: union (Q1; 1996/1527 reg.16(1))
- a signature whose parts are retained-repealed for S (1989/1263 signed.72)
- a section repealed for S by a note in its number only: 1974/40 s.101
- a note-only repeal adds to an element repeal for other territories: 1993/12 s.18
- a Part repeal "except in relation to ss. 13-15" doesn't touch s.13 (Q2; 1984/22)
- a provision repealed in one territory (from the note) keeps its text and status
- the Repeal's own Extent and its note's territory together
- a Repeal wrapping whole Text elements counts too
- the territory can come from the repeal's note

## From LR-02's acceptance review (Gemini, `backend/data/code-reviews/2026-10-09-lr02-acceptance-gemini.md`)

- Effects are **additive**: take LR-02's segments and markup territory as given; don't re-parse text or change `LatTerritory`'s rules.
- **Provenance**: every territory claim records its source (markup vs effect) — distinguishable downstream.
- **Precedence**: a documented rule for markup vs effect disagreement (default: markup), else flag for review.
- Pure, unit-testable effect interpretation (one effect record × segments → claim).
