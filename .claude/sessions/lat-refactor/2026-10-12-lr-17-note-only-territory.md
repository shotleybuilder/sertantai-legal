---
session: 'LR-17: Territory Only in a Note'
status: pending
opened: 2026-10-12
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Retained repeal read as everywhere when the feed is silent on territory but lists savings, while the note names a territory (2010/404 reg.14 'omitted (E.)'; 2020/7 s.8 'expires in part')"
    category: lat-territory
    module: EffectTerritory
    affected: 8
    fix: "known limit until LR-08 (unapplied effects / the amending law's text); LatTerritoryCheck flags them"
    status: open
---

# Session: LR-17 Territory Only in a Note (PENDING)

## Problem

8 rows (LR-07 residue) read a repeal as reaching everywhere: the changes feed lists savings but no territory, and only the note names one (2010/404 reg.14 "omitted (E.)"; 2020/7 s.8 "expires in part"). Under "notes are hints" the note can't decide it; the amending law's own text could (LR-08, unscheduled). `LatTerritoryCheck` reports them as `:note_territory_hint`.

## Todo

- ⬜ List the 8 rows with the note, the effect and the amending provision
- ⬜ Decide: known limit, or read the 8 amending provisions from the store (a small LR-08 slice)

## Decisions for Jason

- **D1 — Known limit, or resolve these 8 from the amending laws**

## Dependencies

- ✅ LR-07 closed; LR-06 wave 4 applied
