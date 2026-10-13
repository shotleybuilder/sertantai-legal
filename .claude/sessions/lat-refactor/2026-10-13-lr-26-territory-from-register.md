---
session: 'LR-26: Territory from the Register'
status: closed
opened: 2026-10-13
closed: 2026-10-13
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md

summary: >
  The labels timeline now answers "where" as well as "when": each period carries the provision's territory, today's from
  the reviewed parse-time calculation and earlier/later periods from dated changes in the register, unknown wherever it
  can't be dated safely. Two rebuilds (479,265 periods); as at today territory is known for 310,656 provisions, nowhere
  for 9,866 (repealed) and unknown for 19,636.

decisions:
  - what: "Territory can't move into the register wholesale; the register dates the parse's territorial claims"
    why: "Today's 'where' composes change claims over the row's words (LR-02/03), which needs the text structure only the parse has; 13,726 of 13,797 exclusions rest on dated claims"
    result: "no territory collector needed (territory_provenance + register dates)"
  - what: "D1′ (consensus after Gemini, approved): today's period = extent minus excluded; earlier periods roll an exclusion back only for dated single-date removals, else unknown; later periods narrow by dated territorial repeals (staged: unknown); nothing left = repealed; status disambiguates nowhere vs unknown"
    why: "Jason: 'we have to publish what we know is true'; Gemini showed rolling back composed exclusions (insertions narrow, repeals remove), extent changes and staged per-territory dates could publish a wrong territory"
    result: "today's territory = today's columns (0 differences in a five-law check); unknown before today 26,373"
  - what: "Rows with no extent take the extent their devolved type fixes (SSI/ASP S, WSI/ANAW E+W, NI instruments NI); UK Acts/SIs with none stay unknown"
    why: "The legislature fixes the extent (the parser's own law_extent table); a UK instrument with no RestrictExtent has no stated extent"
    result: "+5,624 provisions with a known territory today"
  - what: "Rebuilds R and R2 (dry run → Jason → apply); Gemini acceptance dropped"
    why: "Jason"
    result: "479,265 periods, code_version d6c29123"

metrics:
  timeline: { periods: 479265, code_version: d6c29123, laws: 1066 }
  territory_today: { known: 310656, nowhere: 9866, unknown: 19636 }
  territory_unknown_before_today: 26373
  exclusions: { rows: 13797, all_claims_dated: 13726, undated_claim: 71 }
  rows_without_extent: { total: 32828, laws: 274, uksi: 21812, ssi: 4092, wsi: 2455, nisr: 2386, ukpga: 2083 }

lessons:
  - title: Not every fact belongs in the register; some only need its dates
    detail: "Territory composes change claims over a provision's words, which needs the parsed text. The register's job was dating those claims, not re-deriving them; checking that 13,726 of 13,797 exclusions were datable settled the design in one query."
    tag: schema
  - title: "'Nothing left' has more than one cause"
    detail: "A whole-extent exclusion means repealed everywhere, or not yet in force anywhere (nothing live). Reading the second as 'nowhere' would have marked 369 prospective provisions repealed in future periods; the today-vs-columns check and a look at the 'unknown' rows exposed it."
    tag: data
  - title: A consensus review is cheaper than a defended draft
    detail: "Gemini's review of D1 named three ways the draft could publish a wrong territory (composed rollback, extent changes, staged per-territory dates). Folding them in as 'unknown unless safe' before building avoided rework; the staged case also exposed a status bug (a repeal 'for E.'/'for W.' read as everywhere)."
    tag: data
  - title: Check every 'unknown' bucket for a cause the data already answers
    detail: "25,058 of 25,427 unknown-today rows had no extent; for devolved instruments the type fixes it (the parser already knew). Unknown should mean no source, not a source not yet consulted."
    tag: data

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
  - pattern: "A provision not yet in force anywhere has its whole extent 'excluded' (nothing live), which the territory step read as 'nowhere' and marked repealed in future periods"
    category: label-territory
    module: LabelProjection (territories)
    affected: "369 provisions today (prospective, extent = excluded) and their future periods"
    fix: "not commenced → territory unknown in every period, never 'nowhere'"
    status: fixed
artifacts:
  - backend/lib/sertantai_legal/scraper/label_projection.ex (territory per period, staged-territory change extent, not-commenced rule)
  - backend/lib/sertantai_legal/scraper/label_timeline.ex (excluded_extent, claims, devolved type extent)
  - backend/lib/sertantai_legal/scraper/lat_parser/effects.ex (type_extent/1)
  - backend/lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex ('same as affected' normalised)
  - backend/lib/sertantai_legal/legal/lat_label_timeline.ex (territory documented)
  - backend/lib/mix/tasks/lat.timeline.ex (territory_unknown_before_today)
  - backend/test/sertantai_legal/scraper/label_projection_test.exs, legislation_gov_uk/changes_feed_test.exs
  - backend/data/code-reviews/2026-10-13-lr-26-territory-rule.md
  - backend/data/reports/lat-refactor/lr26_dry*.csv, lr26_rebuild*.csv (gitignored)

depends_on:
  - 2026-10-13-lr-24-label-projection
  - 2026-10-13-lr-23-change-log-collectors

enables:
  - LR-25 switch-over (the timeline answers where and when; sync drops status/effective_from/changed_by; extent_code replacement agreed with compliance later)
  - compliance per-site territory (v0.2) from the timeline's territory
---

# Session: LR-26 Territory from the Register — Where (CLOSED)

## Problem

A provision's territory (`extent_code`, `excluded_extent`, `territory_provenance`) is computed by `LatTerritory` inside the parse, from the provision's markup (RestrictExtent, change elements' Extent attributes) and the same feed effects the change register now holds (effect extent, territorial application). That makes two change systems reading one source, and it leaves out pre-2002 territory that only the amending law states (Utilities Act 2000 s. 110(4): "Any amendment … has the same extent as the enactment being amended"). Jason, 2026-10-13: territory moves into v0.1 — "we now have a better architecture to handle it". This answers LR-22's question 1: where a provision applies now.

## Todo

- ✅ Inventory: every territory path in `LatTerritory` / `LatParser.Effects` and which facts it reads (markup on the row, markup on a change, effect extent / application)
- ❌ Collector: change territory into `lat_change_log` — not needed: the claims already carry each change's territory (`territory_provenance`) and the register dates them (markup Extent of joined and unjoined change elements; the feed's extents are already recorded); the provision's own RestrictExtent stays a row fact (markup about the provision, not a change)
- ✅ Jason: the territory rule as a projection (D1′ approved) (base extent from the row's markup, narrowed or extended by changes, in date order; authority law > derived data > auto-derived > editorial)
- ✅ Tests first; territory in `LabelProjection` (pure); offline diff against today's `extent_code` / `excluded_extent` / `territory_provenance`, classified
- ❌ Gemini acceptance — dropped (Jason, 2026-10-13, at close; Gemini reviewed the rule, D1′ is the consensus)
- ✅ Timeline `territory` per period (W1): rebuild (dry run → Jason → apply), twice
- ✅ Feed's 'same as affected' extent (S+A+M+E…) normalised at source (LR-24 bug)
- ⏸️ Lands in the LR-25 switch-over with the "when" labels (LR-25's work)

## Decisions for Jason

- **R — Rebuild** approved and applied 2026-10-13 (479,097 periods, 77c801a2). **R2 — rebuild with the two fixes: approved and applied 2026-10-13** (479,265 periods, d6c29123)
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

## Rebuild 1 and two fixes (2026-10-13)

**Rebuild 1** (approved): 479,097 periods, `code_version` 77c801a2. As at today:
- 305,032 provisions have a known territory;
- 9,699 apply nowhere (repealed);
- **25,427 are unknown.**

Why they're unknown:
- **25,058 provisions (227 laws) have no `extent_code` in LAT**: uksi 21,812, ssi 4,092, wsi 2,455, nisr 2,386, ukpga 2,083. A devolved legislature's instrument has the extent its type fixes: SSI / ASP S; WSI / ANAW E+W; NI instruments NI. That's `LatParser.Effects.law_extent`'s table, used by the parser itself. **Fix:** the builder gives those rows that extent (`Effects.type_extent/1`). UK Acts and SIs with no extent stay unknown.
- **369 are prospective provisions** whose whole extent is "excluded" because nothing is live yet. Today J2 kept them prospective, but **future periods were marked repealed** (bug logged). **Fix:** not commenced means territory unknown in every period, never "nowhere". Test added; suite 2,680.

The table's `territory` documentation now states the convention: empty means nowhere when repealed, otherwise unknown.

**Dry run with the fixes** (`lr26_dry2`): 1,066 laws, 0 errors.
- **Periods:** 479,265.
- **As at today:** territory known 310,656 (+5,624: devolved types); nowhere (repealed) 9,866; unknown 19,636 (mostly UK Acts / SIs with no extent in LAT).
- **Unknown before today:** 26,373 provisions (was 32,167).
- **Status vs today's columns:** 40,214 changed (+142: not-commenced rows no longer repealed in future periods). R2 rebuild to Jason.

**Rebuild 2** (approved): 479,265 periods, `code_version` d6c29123, 0 errors. As at today: territory known 310,656, nowhere (repealed) 9,866, unknown 19,636. W1 is closed: the timeline is a "where" source.
