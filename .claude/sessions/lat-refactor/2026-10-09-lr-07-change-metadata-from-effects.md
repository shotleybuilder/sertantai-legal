---
session: 'LR-07: Change Metadata from Effects'
status: active
opened: 2026-10-09
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "Retained repeal read as everywhere when the feed is silent on territory but lists savings, while the note names a territory (2010/404 reg.14 'omitted (E.)'; 2020/7 s.8 'expires in part')"
    category: territory
    module: EffectTerritory
    affected: 8
    fix: "LatTerritoryCheck: compare a note's territory hint with an :effect_everywhere claim and report disagreement (notes as hints, never as the source) — LR-05"
    status: open
---

# Session: LR-07 Change Metadata from Effects (ACTIVE)

## Problem

`AmendmentNote` derives each note's `effect`, `effective_from`, `changed_by` and `change_id` from note text, and `LatStatus` builds row status (`in_force_partial`, `repealed_saved`) and row `effective_from` / `changed_by` on top of it. Notes are editorial and editable — not law (Jason, 2026-10-09: "building on sand"). These facts come from the effects layer (affecting provision, InForce dates and qualifications, applied, savings) where an effect exists; commencement by territory (LR-02 grounding) belongs here as status. Notes stay notes: `amendment_annotations` keeps their text, id and placement for display and as hints.

## Todo

- ✅ Map each LAT fact to its effects source (and to the amending law where no effect exists) — see Fact map
- ✅ effect / effective_from / changed_by from effects; note-only changes kept as notes, flagged (`fact_provenance`, `change_provenance`)
- ✅ Row status from effects: partial / prospective / commencement by territory; repealed_saved from savings
- ✅ From LR-03 checks: a retained repeal whose effect extent equals the row's extent makes no territory claim (1989/14 s.3(5)(aa)/(ba)/(c)(ia): "Act repealed (S.)" on S-only rows) — wholly in force → repealed status here
- ✅ fractalaw contract impact (fields, hashes) → LH-05 (listed below; fractalaw not told yet)
- ✅ Classified diff; review (text diff runs 1-4, change diff runs 1-2; Gemini accepted)

## Dependencies

- ✅ LR-03 (effects probe, effect ids) — closed 2026-10-09: EffectIndex (ChangeId / key- / orphan joins), EffectTerritory.claim, provenance

## Pending tests this session must turn green (from LR-02)

`mix test --only pending` — tagged `pending: "LR-07"`:
- retained for no territory: the whole extent, repealed_saved
- a retained repeal with no territory (savings / purposes) is repealed_saved everywhere

## Fact map (todo 1)

Probe 2026-10-09 (DB notes × stored changes feed, offline). Notes carrying a `key-` id: amendment 39,645 / 51,902 (76%), commencement 14,514 / 15,548 (93%), modification 11,684 / 16,179 (72%), extent_editorial ~0.

| LAT fact | Now (note text) | From effects | Where no effect |
|---|---|---|---|
| note `effect` | first verb before "by" | effect Type's leading verb (`EffectIndex` `@type_verb`); "coming into force" → commenced; modification types → modified | note verb, provenance `note` |
| note `effective_dates` / `effective_from` | d.m.yyyy before "by"; latest | every dated `InForce` (ChangesFeed keeps only the earliest today — keep the list); from = latest; prospective → nil | note dates, provenance `note` |
| note `changed_by` | first citation after "by" | `Effect.affecting` (AffectingURI) | note citation |
| row `effective_from` / `changed_by` | latest dated note on the row or an ancestor | latest dated effect joined to the row (markup join, then ancestors) | notes |
| `prospective` | CLML `Status` | unchanged — markup outranks effects | — |
| `repealed` | text markers | unchanged — markup | — |
| `repealed_saved` | "savings" in a repeal note | repeal effect's `Savings` refs; retained repeal covering the row's extent (LR-03 claim) | note hint, flagged |
| `in_force_partial` | "for specified purposes" in a note | the provision's commencement / insertion effect: dated `InForce` all purpose-qualified, none "wholly in force" / "in so far as not already in force" | note hint, flagged |
| commencement by territory | — | `InForce` qualified "for E." etc. (LR-03 territory scopes) | — |

**Join note → effect through the markup, not the raw id.** Keyed notes whose id is in the feed: amendment 37,909 (96%), commencement 12,726 (88%), modification 11,244 (96%). The rest are mostly re-keyed effects: 2003/21 s.402(2A)'s note keeps `key-7e48…`; the feed has the same insertion (DEA 2017 Sch. 3 para. 47(3)) as `key-8616…`. LR-03's orphan join (markup ChangeId → provision → effect) resolves these; the note follows its CommentaryRef'd change elements. Legacy-id notes (24% of amendments) join the same way or stay notes.

**Where they disagree, effects are right** (samples):
- dates: amendment 2,055 differ — 1,873 are staged ("10.3.2022 for specified purposes, 10.5.2022 in so far as not already in force"): the note's latest vs the feed's earliest; with every InForce kept they agree. 182 are combined notes ("omitted (E.W.) … and revoked (S.) …") keyed to one effect — one note, several effects.
- changed_by: amendment 1,414 differ — Welsh SIs cited "S.I. 2013/755" (wsi), NI Acts "c. 23" (nia), "as substituted by" chains (the later instrument made the text), self-commencement ("see reg. 1"). Commencement notes: 5,708 have no `changed_by` from text; the effect has one.
- 7,548 / 188,228 effects have more than one dated InForce.

**Open for Jason:** commencement by territory — a status value (`in_force_partial` per territory?) is a fractalaw contract change (status_hash) → LH-05.

## Plan (draft, for Gemini then Jason)

Pipeline today: parse LAT (EffectIndex in context) → persist LAT → `CommentaryParser` (notes placed on rows by `commentary_refs`) → persist → `LatStatus.Apply.refresh` (DB only: re-parses note text into note fields, row status, row effective_from / changed_by).

1. **ChangesFeed keeps every InForce** — `Effect.in_force: [%{date, prospective, qualification, applied}]`; `in_force_date` / `in_force_qualifications` stay (LR-03 callers). Test-first on a feed fixture with a staged insertion.
2. **Note → effects join at parse time** (pure, `EffectIndex`): each change element the parser resolves (`LatTerritory.resolve_change`: ChangeId → key CommentaryRef → orphan) records `{CommentaryRef, effect_id}`; a note's effects = those of the change elements citing it, else its own `key-` id when the feed has it (commencement / modification notes sit on the provision, not on change markup), else none. Rows carry `note_effects` beside `commentary_refs`.
3. **`ChangeFacts`** (new pure module): `note(note, [Effect])` → effect / effective_dates / effective_from / changed_by + `source: :effect | :note` (note text only when no effect); `row(effects, notes)` → row effective_from / changed_by (latest dated effect on the row or ancestors, notes where none); `status(row, effects, notes)` → partial from the provision's commencement / insertion InForce (all dated entries purpose-qualified, none wholly / not-already); repealed_saved from a repeal effect's `Savings` or LR-03's retained-repeal claim covering the extent. Prospective / repealed stay markup.
4. **Persist provenance** — `amendment_annotations.effect_ids text[]` + `fact_source text` (Ash migration); `LatStatus.Apply` reads effect ids and loads effects from the store (`:prefer`) for backfill, so refresh stays offline-capable. `AmendmentNote` stays as the no-effect fallback; `LatStatus` note regexes become the fallback only.
5. **Pending LR-02 tests + 1989/14 s.3(5)** green (retained repeal with effect extent = row extent → repealed_saved; no territory claim).
6. **Diff** — `lat.text_diff`-style classified diff of note fields and row status / effective_from / changed_by vs DB (store only, no writes): classes = effect agrees / effect corrects date / effect corrects changed_by / note-only / status transitions. Dry run → Jason → apply in LR-06's wave.
7. **fractalaw** — status values unchanged unless Jason adds commencement-by-territory; status_hash moves only where status changes; listed for LH-05, not flagged yet.

## Gemini plan review (2026-10-09)

`backend/data/code-reviews/2026-10-09-lr07-plan-gemini.md` (2.5 Pro). Taken:
- Row ↔ effect is primary, note ↔ effect secondary: row facts from the row's (and ancestors') effects via `EffectIndex` refs + markup joins, whether or not a note exists (plan 3).
- One note → several effects; ambiguous orphan joins stay unjoined (LR-03 already returns nil on disagreement); the no-effect fallback is explicit and counted.
- Per-field provenance (effect / note / none per fact), not one `fact_source` — a jsonb like LR-03's `territory_provenance`.
- Diff classes: status transitions (any `repealed → in_force` is a stop), provenance shifts, date / changed_by corrections, effect-derived → note-derived regressions, rows that lose an effect source.

Not taken: a `note_effects` join table — effects aren't DB rows (no FK to enforce); `effect_ids text[]` with a GIN index if reverse lookup is ever needed.

For Jason: `effective_from` = earliest dated InForce (first legal effect, Gemini) vs latest (fully in force, today's rule, `LAT-QA-SAMPLE-SPEC`); and territorial commencement as partial status.

## Decisions (Jason, 2026-10-09)

- `effective_from` = **latest** dated InForce (fully in force) — today's contract kept; every date in `effective_dates`; partial status covers the gap.
- Territorial commencement → **`in_force_partial`** (no new status value): partly in force until every territory of the row's extent has commenced. Status-hash movement listed for LH-05.

## Built (2026-10-09)

- `ChangesFeed.Effect.in_force` — every InForce entry (date, prospective, qualification, applied).
- Joins: `LatTerritory.note_effects/1` (commentary ref → joined effect per change), rows' `note_effects` / `effect_ids` (own change joins + whole-provision + effects naming the provision, words-level excluded), `CommentaryParser.with_effects/3` (markup joins + own id), `LatStagedParser.fetch_changes/2`.
- `ChangeFacts` (pure): `note/3`, `effect_fact/1`, `kind/2`, `partial?/3`, `saved?/1`, `holders/1`, `resolve/5`.
- `EffectTerritory`: `{nil, :effect_not_in_force}` (prospective & unapplied, or every qualifier scoped elsewhere) and `{nil, :effect_unreadable}` (territory named, unreadable) — both remove nothing; `qualifier_territory/1`, `except_territory/1`.
- `mix lat.change_diff` — classified field diff vs DB with a notes-only baseline (`cause`: lr07 | parse).

## Rules the sample diffs forced (4 laws: 1995/21, 1984/55, 1977/500, 1991/56)

- **Whole-extent retained repeal needs a joined effect.** Markup alone said "everywhere" on 7,521 rows in text-diff run 1; 1967/10 s.28 ("Act repealed (S.)" under a legacy `M_F_` id, join missed) proved a missed join is not "everywhere". The LR-02 pending tests were rewritten to carry a joined effect; a new test pins "no effect → no claim".
- **Applied effects aren't prospective**: 24,921 applied effects carry an undated InForce read as prospective.
- **Words-level effects** ("words substituted", ref often only the section) join a row through its change markup only, and an ancestor passes down only whole-provision changes (1995/21 s.192A(6) was taking s.192A(b)'s 2015 words change).
- **Partial**: the provision's own commencement / whole-provision effects complete one another; each words-level amendment is judged alone (1984/55 s.91A(5)); a purposes entry ("for W. for specified purposes") is completed by a commenced entry for its territory; territorial partial needs an entry still to come (undated or after today) — a territory the effect doesn't mention is a feed gap (1995/21 s.136A lists only "for S."); "except in relation to W." is the rest of the extent. Only a commencement effect says "wholly in force"; else the notes no effect joined decide (1984/55 s.12(3)).
- **Effects silent on dates** (older effects) keep the note's dates, `dates_source: note`.

Decided (Jason, 2026-10-09):
- Row `effective_from` / `changed_by` inherit only an ancestor's **whole-provision** changes, not its words-level ones (contract text was "on it or an ancestor" → LH-05). 1995/21 s.157(1)(a) loses 2008; 1984/55 s.1(1)(f) 2023 → 2004.
- **Feed Savings counts**: a repeal effect's `ukm:Savings` ("(with …)") makes a repealed row `repealed_saved` — structured effect data, above notes. D2 ("only with a note mentioning savings") is superseded. Change-diff run 1: 2,039 rows (1,874 'with' only, 90 note says savings, 75 neither).

## Full-corpus runs

- Text diff run 1: the whole-extent rule on markup alone moved 7,521 rows vs LR-03 run 8 → needs a joined effect. Run 2: still 7,878 — LR-03's rule-3 synthetic whole-provision repeals (dots) carry joined effects → `Change.synthetic`, skipped (status, not territory). Run 3 running.
- Change diff run 1 (before the synthetic fix): 162,593 changed fields; notes from effects 65,648 / text 25,026. Findings fixed: a law commencing itself ("see reg. 1") made 47,381 rows `changed_by` = itself → nil (the date stands); footnote citations ("OJ L 182, 21.6.2014, p.52.") gave rows dates → a note naming no change and no instrument isn't a change; a whole-provision insertion's own InForce completes commencement (asp 2003/2 s.51A, source effect).
- Text diff run 3: 2,348 rows vs LR-03 run 8; 27 in_force among them showed a silent effect read as everywhere (1988/52 s.4(6) "repealed (E.W.)", 2010/404 reg.14, 2020/7 s.8) → `:effect_everywhere` needs positive evidence (purposes, savings, effect extent covering the row).
- Text diff run 4: 2,233 rows vs LR-03 run 8 (excluded_extent only; 3 text); 2,113 already `repealed_saved` in the DB (the notes said so), 98 repealed, 3 prospective, 19 in_force (1989/14 s.3(5) ×6 — the LR-03 item; heads of revoked-with-savings laws; residue: 2010/404 reg.14 ×6, 2020/7 s.8 ×2 → open bug, LR-05). Checks unchanged: 9 conflicts, 2 child-live, 1 other.
- Change diff run 2: 109,245 changed fields (lr07 106,074, parse 3,171). Notes from effects 65,648 / text 25,026; row status source effect 196,698 / markup 182,226 / note 525. Largest: commencement dates filled from effects (22,035), changed_by filled (19,285), dates later (12,549) / earlier (6,463), repealed → repealed_saved from feed Savings (2,126), partial gained 1,296 / lost 841. Fixed after: a uksi-held Welsh SI commencing itself (wsi twin) is itself.

## Persistence (2026-10-09)

Ash migration `20261009175920_lr07_effect_ids` (dev + test migrated; `lat` view recreated with the columns): `legal_articles.effect_ids`, `change_provenance` (%{status, change}); `amendment_annotations.effect_ids`, `fact_provenance` (%{facts, dates}). Both parse paths write them (`LatStagedParser`; the LRT scrape's `StagedParser.persist_body_lat`, which until now parsed with no effects — LR-03 territory from effects never ran there). `LatStatus.Apply.refresh` resolves through `ChangeFacts.resolve/5` (effects from `opts[:effects]` or the store); `mix lat.status --store`. Stored rows hold no `effect_ids` until re-parsed: the LR-06 wave (re-parse → refresh) is what lands LR-07's facts; `mix lat.status` alone gives the notes-only baseline.

## fractalaw contract impact → LH-05 (not flagged)

| field | hashed? | change |
|---|---|---|
| `status` | `status_hash` | values unchanged; moves: partial from effects (incl. territorial — pending entries only), `repealed_saved` from feed Savings (D2 superseded); change-diff run 2: repealed → saved 2,126, partial +1,296 / −841 |
| `effective_from` / `changed_by` (rows; Zenoh `data_server`) | no | from effects; ancestors pass down whole-provision changes only; a law's own commencement dates the row with `changed_by` nil; ~22k rows gain commencement dates |
| `excluded_extent` | no | whole extent for retained repeals with `:effect_everywhere` evidence (~2,233 rows vs LR-03, 2,113 already `repealed_saved`) |
| notes `effect` / `effective_from` / `changed_by` | no | from effects (65,648 notes) |
| notes `change_id` | evidence for LatCause / lat_changes | unchanged (hash of law + text) |
| `effect_ids`, `change_provenance`, `fact_provenance` | no | new, legal-only for now |

## Gemini acceptance (2026-10-09)

`backend/data/code-reviews/2026-10-09-lr07-acceptance-gemini.md` (2.5 Pro): **accept** for dry run → apply. Taken: the dates fallback was blocked when *any* joined effect was prospective — now only when all are (test). Already covered: "data loss" (`emptied` classes) and effect-over-note corrections are diff classes. Not a risk as read: unmentioned territories don't keep a row partial (feed gap, not "not in force"). To LR-04: split `ChangeFacts.resolve/5`, comment `group_partial?/3`, move `twin/1` beside `AmendmentNote.resolve_law/2`.
