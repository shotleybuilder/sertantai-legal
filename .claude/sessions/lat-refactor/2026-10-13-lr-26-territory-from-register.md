---
session: 'LR-26: Territory from the Register'
status: active
opened: 2026-10-13
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "legislation.gov.uk feed spells AffectingEffectsExtent 'same as affected' as S+A+M+E+A+S+A+F+F+E+C+T+E+D; stored as an extent code it reads as Scotland (+ junk)"
    category: feed-extent
    module: ChangesFeed (parse)
    affected: "17,881 lat_change_log records"
    fix: "ChangesFeed normalises it to nil at parse (test); the register picks it up on the next re-collect (LR-25 hook)"
    status: fixed
  - pattern: "A repeal staged per territory ('for E.' 1.1.2001, 'for W.' 1.1.2002) with no extent of its own read as a repeal everywhere: the provision shown repealed while it applies in S"
    category: label-status
    module: LabelProjection (change_extent)
    affected: "found by test; counted in the territory dry run"
    fix: "a change whose in-force entries each name a territory reaches their union"
    status: fixed
---

# Session: LR-26 Territory from the Register — Where (ACTIVE)

## Problem

A provision's territory (`extent_code`, `excluded_extent`, `territory_provenance`) is computed by `LatTerritory` inside the parse, from the provision's markup (RestrictExtent, change elements' Extent attributes) and the same feed effects the change register now holds (effect extent, territorial application). That makes two change systems reading one source, and it leaves out pre-2002 territory that only the amending law states (Utilities Act 2000 s. 110(4): "Any amendment … has the same extent as the enactment being amended"). Jason, 2026-10-13: territory moves into v0.1 — "we now have a better architecture to handle it". This answers LR-22's question 1: where a provision applies now.

## Todo

- ✅ Inventory: every territory path in `LatTerritory` / `LatParser.Effects` and which facts it reads (markup on the row, markup on a change, effect extent / application)
- ⬜ Collector: change territory into `lat_change_log` (markup Extent of joined and unjoined change elements; the feed's extents are already recorded); the provision's own RestrictExtent stays a row fact (markup about the provision, not a change)
- ✅ Jason: the territory rule as a projection (D1′ approved) (base extent from the row's markup, narrowed or extended by changes, in date order; authority law > derived data > auto-derived > editorial)
- ✅ Tests first; territory in `LabelProjection` (pure); offline diff against today's `extent_code` / `excluded_extent` / `territory_provenance`, classified
- ⬜ Gemini acceptance
- ⬜ Timeline `territory` per period (W1): rebuild (dry run → Jason → apply)
- ✅ Feed's 'same as affected' extent (S+A+M+E…) normalised at source (LR-24 bug)
- ⬜ Lands in the LR-25 switch-over with the "when" labels

## Decisions for Jason

- **R — Rebuild** the timeline with territory (dry run below). **Jason: approve**
- **D1′ — approved 2026-10-13, built.** Consensus after Gemini (see "Gemini on D1")**: Jason approves the consensus ("we have to publish what we know is true"). **Jason: approve D1′**
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

## Gemini on D1 (2026-10-13)

`backend/data/code-reviews/2026-10-13-lr-26-territory-rule.md`. **VERDICT: ACCEPT WITH CHANGES.**

Points where D1 could publish a wrong territory (not merely unknown):
1. **Rolling back a composed exclusion.** Today's `excluded_extent` composes several claims over the words (insertions narrow, repeals remove). Undoing one claim by date can re-include a territory another claim still excludes, or one a narrowing insertion never covered.
2. **The provision's own extent can change over time** (an extent change). Today's `extent_code` carried back would be wrong.
3. **Staged in-force entries per territory** ("1.4.2025 for E., 1.4.2026 for W.") mean one claim narrows the territory in steps, not at one date.
4. **"Unknown" vs "nowhere"** must be distinguishable.

Agreed (no change): today's parse result is the authoritative current period; notes never read; future dated repeals narrow from their date. Not taken: a `territory_provenance` column on the timeline (more schema; the row's provenance and change ids already trace it), an array type for territory (the codes are "E+W+S+NI" text, as `extent_code`).

## D1′ — consensus

For each period:
1. **Today's period:** `territory` = `extent_code` minus `excluded_extent` (the reviewed current calculation).
2. **Earlier periods, exact only when safe:** an exclusion is rolled back before its date only when every claim behind it is a **dated removal** (a repeal or omission, with one in-force date or staged dates whose territories can be read per stage). Then the territory before the date includes that territory again.
3. **Unknown otherwise** (territory empty for periods before today):
   - a claim behind the exclusion is undated (71 rows);
   - a claim is a narrowing insertion or substitution;
   - the provision has an extent change on it;
   - a staged claim's territories can't be read.
4. **Later periods:** a dated territorial repeal not yet in force narrows the territory from its date (by stage where staged); unreadable → unknown from that date.
5. **Nowhere vs unknown:** when no territory is left, the period's status is `repealed`. An empty territory with status repealed means "nowhere"; with any other status, "unknown". Same pattern as LR-24 T1: the status disambiguates, no new values or columns.
6. Notes are never read; "same as affected" is normalised at the feed parser.

## Build and dry run (2026-10-13)

**Built** in `LabelProjection` (the timeline's second pass; the rules sit with the "when" rules, no separate module), following D1′:
- **Today's period:** `extent_code` minus `excluded_extent`.
- **Earlier periods:** an exclusion is rolled back only when every claim behind it is a dated single-date removal; otherwise unknown.
- **Later periods:** dated territorial repeals narrow the territory; a staged one is unknown.
- **Nothing left:** status `repealed`, territory empty ("nowhere"). A repealed period has no territory.
- **A change's territory** also comes from in-force entries that each name a territory (bug above).
- **The builder** passes each row's `excluded_extent` and `territory_provenance` claims. `ChangesFeed` normalises "same as affected".
- **Tests:** 9 territory cases. Suite 2,679.

The first dry run crashed at law 719 (uksi 2007/79): a later repeal after nothing was left subtracted from "nowhere". Fixed with a test.

**Dry run** (`lr26_dry`): 1,066 laws, 0 errors.
- **Periods:** 479,097 (+3,022 from territorial splits).
- **Today's territory equals today's columns** (`extent_code` minus `excluded_extent`; repealed = none). A five-law check (1974/37, 1990/43, 1974/40, 1968/73) gave 0 differences among provisions with a row today.
- **Provisions whose territory is unknown before today: 32,167.** The causes: an exclusion behind an undated or narrowing claim, a staged one, or an extent change.
- **Status vs today:** 40,072 changed (as LR-24, with the staged-territory repeals corrected), of which 33,626 are unknown (no row).
