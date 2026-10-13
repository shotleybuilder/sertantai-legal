---
session: 'LR-26: Territory from the Register'
status: pending
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
---

# Session: LR-26 Territory from the Register — Where (PENDING)

## Problem

A provision's territory (`extent_code`, `excluded_extent`, `territory_provenance`) is computed by `LatTerritory` inside the parse, from the provision's markup (RestrictExtent, change elements' Extent attributes) and the same feed effects the change register now holds (effect extent, territorial application). That makes two change systems reading one source, and it leaves out pre-2002 territory that only the amending law states (Utilities Act 2000 s. 110(4): "Any amendment … has the same extent as the enactment being amended"). Jason, 2026-10-13: territory moves into v0.1 — "we now have a better architecture to handle it". This answers LR-22's question 1: where a provision applies now.

## Todo

- ⬜ Inventory: every territory path in `LatTerritory` / `LatParser.Effects` and which facts it reads (markup on the row, markup on a change, effect extent / application)
- ⬜ Collector: change territory into `lat_change_log` (markup Extent of joined and unjoined change elements; the feed's extents are already recorded); the provision's own RestrictExtent stays a row fact (markup about the provision, not a change)
- ⬜ Jason: the territory rule as a projection (base extent from the row's markup, narrowed or extended by changes, in date order; authority law > derived data > auto-derived > editorial)
- ⬜ Tests first; `TerritoryProjection` (pure); offline diff against today's `extent_code` / `excluded_extent` / `territory_provenance`, classified
- ⬜ Gemini acceptance
- ⬜ Lands in the LR-25 switch-over wave with the "when" labels

## Dependencies

- ⬜ LR-23 register filled
- ⬜ LR-24 projection pattern (the "when" labels) — LR-26 follows its shape
