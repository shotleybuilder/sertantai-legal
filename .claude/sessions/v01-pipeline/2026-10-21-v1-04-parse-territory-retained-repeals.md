---
session: 'V1-04: Parse Territory for Retained Repeals'
status: active
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'The parse reads a retained repeal (<Repeal RetainText="true">) whose joined effect names no territory as repealed everywhere (EffectTerritory step 7, :effect_everywhere), though the affecting law is territorial: SI 2023/911 "(England)" omits SI 2010/404 reg.14, which Welsh SIs still amend in 2025-26; excluded_extent E+W, markup_status repealed_saved, and J2 holds the row repealed today'
    category: parse territory
    module: EffectTerritory.claim (parser; ParserVersion) / LatParser.Rows.assign_status
    affected: 'up to 1,319 repealed_saved rows in 15 laws from 2002 (and 1,281 in older laws) — measure which are effect_everywhere with a territorial affecting law'
    fix: 'be338f00: LawTerritory; Effect.affecting_territory; EffectTerritory step 6a :affecting_law (removals, text retained) — reaches the DB with the v0.1 re-parse'
    status: fixed
  - pattern: 'The parse makes no territory claim for a retained repeal whose joined effect is silent on territory (EffectTerritory step 8), though the affecting law is territorial: Forestry Act 1967 s.1(4)(a) repealed for S (asp 2018/8) and W (wsi 2013/755) keeps excluded_extent nil, so today reads E+W+S, not E'
    category: parse territory
    module: EffectTerritory.claim (parser; ParserVersion)
    affected: 'measure with the step-7 rows (retained repeals with no claim and a territorial affecting law)'
    fix: 'be338f00: a join gap, not step 8 — EffectIndex.with_orphans joins a legacy id spanning the law to its one whole-law repeal by the cited law; step 5 then claims S'
    status: fixed
  - pattern: 'A range record ("ss. 78(4B)-(4D) omitted", anaw 2015/4, 2015) reaches provisions inserted inside the range later (s.78(4BA)-(4BB), 2017): the register and the parse join it by document order, so the rows read repealed today though in force, and an earlier range insertion (2008/29, (4A)-(4D)) gives them an in-force period from 2012'
    category: register / effect target
    module: EffectIndex.new (as_given span) / ChangeCollector range expansion (lat_change_log_rows)
    affected: 'from 2002: 429 rows / 64 laws (inserted), 317 / 61 (substituted), 4 / 3 (repealed); older 658 / 488 / 62; text-change operations only'
    fix: a range reaches only provisions that existed at its date (no insertion record dated after it) — V1-05
    status: open
  - pattern: "Retained repeal read as everywhere when the feed is silent on territory but lists savings, while the note names a territory (2010/404 reg.14 'omitted (E.)'; 2020/7 s.8 'expires in part')"
    category: parse territory
    module: EffectTerritory
    affected: '2010/404 reg.14 (6 rows); 2020/7 s.8 fixed by V1-03'
    fix: 'be338f00: the affecting law territory (step 6a), from the law, never the note'
    status: fixed
---

# Session: V1-04: Parse Territory for Retained Repeals (ACTIVE)

## Problem

Jason 2026-10-21: "I cannot have recent laws with wrong territory metadata" — the most reliable and correct fix, at source, shipping with v0.1. SI 2010/404 reg.14 reads repealed everywhere today. The markup keeps its text (`RetainText="true"`) and Welsh SIs keep amending it, but the parse's territory claim (`EffectTerritory.claim/5`, step 7 `:effect_everywhere`, LR-07) reads a retained repeal whose effect has no territorial application as repealed everywhere. The effect here is the "(England)" SI 2023/911's. The parse writes `excluded_extent` E+W, `markup_status` `repealed_saved`, and J2 (markup wins today) then holds the label. V1-03 fixed the same gap in the register (a feed effect with no territory takes its affecting law's); the parse still has it, both ways. Over-claim: step 7 reads SI 2010/404 reg.14 as repealed everywhere. No claim: step 8 leaves Forestry Act 1967 s.1(4)(a), repealed for S (asp 2018/8) and W (wsi 2013/755), with no exclusion, so today reads E+W+S instead of E. Both are retained repeals (`RetainText="true"`, no Extent) whose affecting law is territorial.

## Todo

- ✅ Measure both ways (2026-10-21, from the DB, no parse; below): rows with an `effect_everywhere` claim, and retained repeals with no claim, whose affecting law has a territory (devolved type, own title place, narrower register extent); by era, a sample per kind
- ✅ One rule, one module (`LawTerritory`; `Collect.territory/3` and `ChangeCollector.title_place/1` delegate; in ParserVersion and LabelVersion inputs): move the law-territory rule (V1-03: `Collect.territory/3`'s devolved types, `ChangeCollector.title_place/1`, narrower register extent; nil when the amended law is devolved to the same territory) into a pure module both the register and the parser call; the DB lookup stays in the callers
- ✅ Whole-law join (`EffectIndex.with_orphans`, last resort, `:keep` only, the cited law's one applied whole-law repeal): a retained repeal whose change id spans the law (legacy `M_F_` id, no `key-`) joins the law's "Act repealed" effect (no provisions named), the note's law agreeing — Forestry's no-claim is a join gap, not step 8
- ✅ Parser input (`Effect.affecting_territory`, filled by `LatStagedParser.with_affecting_territory/2`; `EffectTerritory` step 6a `:affecting_law`, removals only): the parse context gets each affecting law's territory (built by `LatStagedParser` before the pure parse, as the effects are); `EffectTerritory.claim` uses it before steps 7 and 8 — a territorial affecting law limits the removal to its territory: never "everywhere", never "no claim"
- ✅ Tests first (red, then green: `law_territory_test.exs`, V1-04 cases in `effect_territory_test.exs`; in-memory parse checked on both laws below): SI 2010/404 reg.14 (excluded E, markup_status in_force, today W), Forestry Act 1967 s.1(4)(a) (excluded S+W, today E), a Welsh SI's retained repeal (W), a UK-wide law's retained repeal with savings (still everywhere: 1989/14 s.3(5)), an asp's (S)
- ✅ Check `markup_status` / J2 afterwards (SI 2010/404 reg.14: in_force, so J2 no longer holds it repealed): a retained repeal for part of the row's extent is in force elsewhere — J2 should no longer hold such rows repealed
- ✅ Parse diff on the affected laws (below) (`mix lat.parse_snapshot` / `lat.text_diff --store only`), classified; only territory fields and markup_status move
- ✅ Gemini review of the change (`backend/data/code-reviews/2026-10-21-v1-04-parse-territory-gemini.md`: rows showing only numbers now count as retained, 0 rows moved; the rest noted below) (parser territory rule), saved to `backend/data/code-reviews/`
- ✅ Close the identical open bug in LR-07 and LR-17 ("Retained repeal read as everywhere when the feed is silent on territory …": 2010/404 reg.14; its 2020/7 s.8 half is V1-03's expiry fix) as fixed here
- ⬜ Territory audit, laws from 2002, after the fix: rows in force today whose territory is unknown or the whole extent while the register holds a dated territorial repeal (or insertion) narrower than the row; each a fix here or a listed known limit — nothing left unexplained for v0.1
- ⬜ Dry run → Jason → restore point (`legal_articles`, `amendment_annotations`, `lat_change_log`, `lat_label_timeline`) → re-parse (`mix lat.reparse --store only`, the laws whose parse changes; ParserVersion moves) — folded into the v0.1 relabel (V1-00)

## Measure (2026-10-21)

From the DB (`territory_provenance` joined to `lat_change_log` by effect id; the affecting law's territory by the V1-03 rule), script in the scratchpad (`v104/measure.exs`):

| | ≥2002 | <2002 |
|---|---|---|
| Step 7 `effect_everywhere`, affecting law territorial | 47 rows / 17 laws | 63 / 12 |
| Step 7 `effect_everywhere`, affecting law UK-wide (right) | 3,311 / 220 | 1,922 / 113 |
| Proxy: a territorial law's repeal on a wider row, not excluded, row in force | 341 / 82 | 582 / 75 |

- Step 7, ≥2002 territorial: SI 2010/2215 by "(England)" SI 2023/906 (14 rows), SI 2010/404 by SI 2023/911 (6), SI 2008/1597 and 2014/1638 by GB SI 2014/3248 (7), and Welsh laws (anaw 2016/3, wsi 2013/755, 2019/390, 2025/1192) on E+W rows. Most of these rows read repealed already: another repeal covers the other territory.
- The proxy is wide: it holds words-level repeals, which the parse brackets correctly. The exact set is what the parse diff moves.
- **Forestry Act 1967 s.1(4)(a) is a join gap, not step 8.** Its retained repeal carries a legacy id (`M_F_d297e506…`, the whole Act's, note "Act repealed (S.) … asp 8"). The feed's effect is `repealed` "Act" (asp 2018/8; no provisions named; effect extent S; savings ss.80, 83). `EffectIndex.with_orphans` only joins effects that name provisions, so the change joins nothing and no claim is made. Joined, step 5 (effect extent narrower) already gives S.

## Design (2026-10-21)

- **`LawTerritory` (pure, new):** where a law's changes reach. It takes `Collect.territory/3` (devolved type; register extent narrower than the UK; nil when the amended law is devolved to the same territory) and `ChangeCollector.title_place/1`, with defdelegates left behind. The register lookup (title, geo_extent) stays in the callers.
- **The parser's input:** `LatStagedParser.law_effects` fills a new `Effect.affecting_territory` field from the register (impure, one query per affecting law). `EffectTerritory` stays pure.
- **`EffectTerritory.claim`, a new step after 6 (`:affecting_law`):** when every joined effect (the keyed effect and its parallels) has an affecting territory, their union, if narrower than the row's extent, is the claim. It comes after the feed's application, the markup Extent, the in-force qualifiers and the effect extent (explicit data first), and before step 7 "everywhere" and step 8 "no claim". A territorial law never changes text outside its territory.
- **Removals only (revised 2026-10-21, on the Forestry check):** the first cut applied the rule to insertions too, and Forestry Act 1967 s.1(1A) then read as Wales-only. That provision was inserted by the Welsh SI 2013/755 (the Natural Resources Body for Wales Order) and defines "the appropriate forestry authority" for England as well. A devolved instrument made jointly with UK ministers can insert text that applies across the border, so a law's type is no legal limit for an insertion. Retained text (`RetainText`) is legislation.gov.uk's own sign that a repeal is partial, and that sign plus the affecting law's territory is strong. An insertion carries no such sign, so it keeps today's reading.
- **The whole-law orphan join:** the last resort for a `:keep` change id that joins no provision effect, when the law has exactly one applied whole-law repeal whose affecting law the change's note cites.
- **Note:** the parse now reads the register (each affecting law's title and extent). That is a new input, and it changes only when the register does.

## In-memory parse check (2026-10-21)

- **SI 2010/404 reg.14 and its children:** `excluded_extent` E (was E+W), `markup_status` in_force (was repealed_saved), provenance `affecting_law: E`. Today: Wales.
- **Forestry Act 1967 s.1(4)(a):** `excluded_extent` S (was nil). The legacy retained repeal joins the asp 2018/8 "Act repealed" effect, and step 5 (effect extent S) claims it. The rest of the Act follows (S excluded throughout). Not "S+W" as first planned: the Welsh SI 2013/755 omitted its words outright (not retained), so no W exclusion; what the words themselves say ("as regards England") is content, not extent.
- **s.1(4)(b):** repealed (the 2019/734 omission), now with S excluded too; its status was already repealed.

## Parse diff (2026-10-21)

`mix lat.text_diff --store only` on the 348 laws the change can touch, and on 40 control laws outside that set (`backend/data/reports/lat-refactor/v104_control.csv`: 0 rows changed). Three runs:

1. **First cut:** 567 rows / 32 laws. Too wide: the rule also narrowed whole-provision repeals the parser adds from the effects layer on rows whose text is gone ("…"). NERCA 2006 s.73, repealed by an Act whose register extent is E+W, read as live in Scotland. A UK Act's repeal commonly "has the same extent as the provision repealed", and removed text is repealed wholly. (Kept in `v104_run1/`.)
2. **Only markup `RetainText`:** 457 rows / 3 laws. Too narrow: it dropped SI 2010/2215's 13 rows, where the effects layer repeals for England (SI 2023/906) and legislation.gov.uk still shows the text.
3. **Final, retained = the row still shows words (`Change.retained`):** 472 rows / 4 laws (`v104_diff.csv`); territory checks 0 findings.

| Class | Rows | Law | Reading |
|---|---|---|---|
| excluded nil → S | 443 | Forestry Act 1967 | the asp 2018/8 "Act repealed (S.)" now joined (whole-law join) ✅ |
| excluded nil → E | 13 | SI 2010/2215 | "(England)" SI 2023/906's repeals; in force in Wales ✅ |
| brackets removed (+ S) | 8 | Forestry Act 1967 | an "[E+W: …]" bracket now covers every live territory, so plain ✅ |
| excluded E+W → E | 6 | SI 2010/404 reg.14 | in force in Wales ✅ |
| text: words / brackets added | 6 | TCPA 1990 | Welsh substitutions now read "[W: new] [E: old]" (were both run together) ✅ |
| excluded E+W → E+W+S | 2 | Forestry Act 1967 | "…" rows (s.1(2A), s.7AA): already repealed; S added ✅ |
| excluded nil → W | 2 | TCPA 1990 s.78(4BA), (4BB) | ❌ wrong, but the cause predates V1-04: anaw 2015/4's range "s.78(4B)-(4D) omitted" (2015) reaches subsections inserted in 2017. The labels are already wrong (repealed since 2017). → V1-05 |

**V1-05 (new bug, frontmatter):** range records reach provisions inserted later. From 2002: 429 rows / 64 laws (inserted), 317 / 61 (substituted), 4 / 3 (repealed). A label-side and effect-target fix of its own; proposed as a pending v0.1 session.

## Gemini review (2026-10-21, gemini-2.5-pro)

- **Rows of numbers only:** a row showing only "1990 c. 8" failed the "still shows text" test. It now counts letters or numbers. In the 5 candidate laws holding such rows, 0 rows moved.
- **Statutory exceptions:** a devolved authority given power to repeal outside its territory. Removals with retained text only; the risk is accepted, and each such claim is recorded as `affecting_law` in `territory_provenance` (queryable for the audit).
- **The orphan join needs exactly one whole-law repeal:** with two or more there is no join, a safe failure.
- **The "…" convention is legislation.gov.uk's rendering:** noted in the code.

## Territory audit, laws from 2002 (2026-10-21)

Rows the register says a territorial law repealed wholly (`repealed` / `revoked` / `omitted`, not words; dated, on or before today; the territory from the feed or `LawTerritory`) that still read with no exclusion for it after this fix (`v104_diff` spliced over the stored parse; markup not repealed): **2 provisions** (`v104/audit.exs` in the scratchpad). A rolled-back relabel shows both labels stay wrong:

| Row | Register | Label after relabel | Should be |
|---|---|---|---|
| Coronavirus Act 2020 s.78 | NI repealed 2021-08-27 (nia 2021/8); E repealed 2021-12-09 (SI 2021/1399) | in force W+NI from 2021-08-27 | W |
| SI 2016/1105 reg.72(2)(b) | NI omitted 2020-12-31 ("(Northern Ireland) (EU Exit)" SI 2020/678); markup repeals GB (E+W+S) | in force NI from 2020-12-31 | repealed |

**Cause:** today's territory is the row's extent minus the parse's `excluded_extent` (LR-26 D1′). The parse adds a whole-provision repeal from the effects layer (rule 3) only when none of the provision's change markup joins an effect (Jason 2026-10-09). reg.72(2)(b)'s markup joins the GB repeal, so the applied NI repeal, which has no markup, is never added. s.78 (provenance: effect application E, markup NI; the row has no text of its own) is likely the same gap; not yet traced. **Jason decides** (it changes his 2026-10-09 rule): rule 3 per effect (each applied whole-provision effect that no markup on the provision joins), measured first; or both rows listed as known limits.

## Related (not in this session)

- **LH-07 Welsh SI duplicates (#178), v0.1:** a Welsh SI held under a `uksi` name escapes the devolved-by-type rule. The title-place rule catches most ("… (Wales) Regulations"); the identity fix is LH-07's.
- **QQ-00 fractalaw tree bugs** (an NI law's jurisdiction matching GB orgs; a Not node disapplying a law's own jurisdiction): fractalaw's applicability trees, not legal's labels.

## Dependencies

- ✅ V1-03 feed territory (the rule this reuses: `f5514bfd`, `086c2ab6`)
- ✅ V1-03 closed 2026-10-21 (its last preview spliced: `v01_final`; pushed `6f37582d`)
