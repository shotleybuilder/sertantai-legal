---
session: 'LR-26: Territory from the Register'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-26 Territory from the Register — Where (ACTIVE)

## Problem

A provision's territory (`extent_code`, `excluded_extent`, `territory_provenance`) is computed by `LatTerritory` inside the parse, from the provision's markup (RestrictExtent, change elements' Extent attributes) and the same feed effects the change register now holds (effect extent, territorial application). That makes two change systems reading one source, and it leaves out pre-2002 territory that only the amending law states (Utilities Act 2000 s. 110(4): "Any amendment … has the same extent as the enactment being amended"). Jason, 2026-10-13: territory moves into v0.1 — "we now have a better architecture to handle it". This answers LR-22's question 1: where a provision applies now.

## Todo

- ✅ Inventory: every territory path in `LatTerritory` / `LatParser.Effects` and which facts it reads (markup on the row, markup on a change, effect extent / application)
- ⬜ Collector: change territory into `lat_change_log` (markup Extent of joined and unjoined change elements; the feed's extents are already recorded); the provision's own RestrictExtent stays a row fact (markup about the provision, not a change)
- ⬜ Jason: the territory rule as a projection (base extent from the row's markup, narrowed or extended by changes, in date order; authority law > derived data > auto-derived > editorial)
- ⬜ Tests first; `TerritoryProjection` (pure); offline diff against today's `extent_code` / `excluded_extent` / `territory_provenance`, classified
- ⬜ Gemini acceptance
- ⬜ Timeline `territory` per period (W1): rebuild (dry run → Jason → apply)
- ⬜ Feed's 'same as affected' extent (S+A+M+E…) normalised at source (LR-24 bug)
- ⬜ Lands in the LR-25 switch-over with the "when" labels

## Decisions for Jason

- **D1 — The territory rule (per period)**, see "Proposed rule". Today's "where" stays the reviewed LR-02/03 calculation; the register dates it; undatable means unknown.

## Dependencies

- ✅ LR-23 register filled (132,965 records)
- ✅ LR-24 timeline `lat_label_timeline` (476,075 periods; `territory` column empty, W1); LR-26 fills `territory` per period
- Truth rules from LR-24 apply: never a wrong value; unknown is implied (no value), undatable is said; notes only point

## Inventory (2026-10-13)

Today a row's "where" is `extent_code` (the provision's own markup extent, RestrictExtent) minus `excluded_extent`: the territories where none of its words still apply. It's computed in the parse (`LatTerritory.excluded/2`, LR-02/03, Gemini-accepted rules) from the row's text segments:
- each change element's territory is claimed by `EffectTerritory.claim/5`, in this order: the effect's territorial application → the markup Extent → in-force qualifiers ("for S.") → not in force (removes nothing) → a narrower effect extent → unreadable → everywhere (savings or purposes) → no claim;
- the claims compose from the outside in over the row's words: a retained repeal removes its territory; an insertion narrows to where it applies; substitutions are bracketed.

Each claim is recorded in `territory_provenance` (source, territory, change_id, effect_id).

**This can't move into the register wholesale.** "Which words are live where" needs the text structure (which words sit inside which change), which only the parse has. What the register adds is dates: each claim's `effect_id` is a register change with in-force dates.

Measured:
- rows with any territory claim: 28,163;
- rows with an `excluded_extent`: 13,797, of which **13,726 have every claim dated in the register**; 71 rest on a claim with no dated effect (markup only).

## Proposed rule (D1)

For each timeline period:
1. **The period containing today:** `territory` = `extent_code` minus `excluded_extent`, the reviewed current calculation. It's authoritative for now (markup + effects), and the timeline doesn't recompute it.
2. **Earlier periods:** a territorial exclusion applies only from its claim's date. Before the date, that territory is still live. If every claim behind the exclusion is dated, earlier periods are exact.
3. **A claim with no date** (71 rows): the territory for periods before today is unknown (empty), never today's value carried back.
4. **Later periods:** a territorial repeal in force after today (dated, not yet applied) narrows the territory from its date: the row's territory minus the repeal's territory (application, else effect extent; "same as affected" = the row's).
5. **No territory left** (excluded = the whole extent) means the provision applies nowhere: status repealed for that period, consistent with today's columns.
6. Notes are never read. The garbled "same as affected" extent is normalised at the feed parser (LR-24 bug).
