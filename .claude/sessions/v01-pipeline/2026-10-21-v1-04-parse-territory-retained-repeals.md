---
session: 'V1-04: Parse Territory for Retained Repeals'
status: pending
release: v0.1
opened: '2026-10-21'
parent: v01-pipeline/2026-10-21-v1-00-meta.md
bugs:
  - pattern: 'The parse reads a retained repeal (<Repeal RetainText="true">) whose joined effect names no territory as repealed everywhere (EffectTerritory step 7, :effect_everywhere), though the affecting law is territorial: SI 2023/911 "(England)" omits SI 2010/404 reg.14, which Welsh SIs still amend in 2025-26; excluded_extent E+W, markup_status repealed_saved, and J2 holds the row repealed today'
    category: parse territory
    module: EffectTerritory.claim (parser; ParserVersion) / LatParser.Rows.assign_status
    affected: 'up to 1,319 repealed_saved rows in 15 laws from 2002 (and 1,281 in older laws) — measure which are effect_everywhere with a territorial affecting law'
    fix: give the parser the affecting law's territory (the V1-03 rule — devolved type, the law's own title place, a register extent narrower than the UK) before the everywhere step; one shared pure module for parser and register
    status: open
---

# Session: V1-04: Parse Territory for Retained Repeals (PENDING)

## Problem

Jason 2026-10-21: "I cannot have recent laws with wrong territory metadata" — the most reliable and correct fix, at source, shipping with v0.1. SI 2010/404 reg.14 reads repealed everywhere today. The markup keeps its text (`RetainText="true"`) and Welsh SIs keep amending it, but the parse's territory claim (`EffectTerritory.claim/5`, step 7 `:effect_everywhere`, LR-07) reads a retained repeal whose effect has no territorial application as repealed everywhere. The effect here is the "(England)" SI 2023/911's. The parse writes `excluded_extent` E+W, `markup_status` `repealed_saved`, and J2 (markup wins today) then holds the label. V1-03 fixed the same gap in the register (a feed effect with no territory takes its affecting law's); the parse still has it.

## Todo

- ⬜ Measure: rows whose `territory_provenance` holds an `effect_everywhere` claim, by era, and how many have an affecting law with a territory (devolved type, own title place, narrower register extent); list a sample per kind
- ⬜ One rule, one module: move the law-territory rule (V1-03: `Collect.territory/3`'s devolved types, `ChangeCollector.title_place/1`, narrower register extent; nil when the amended law is devolved to the same territory) into a pure module both the register and the parser call; the DB lookup stays in the callers
- ⬜ Parser input: the parse context gets each affecting law's territory (built by `LatStagedParser` before the pure parse, as the effects are); `EffectTerritory.claim` uses it before step 7 — a territorial affecting law limits the removal to its territory, never "everywhere"
- ⬜ Tests first: SI 2010/404 reg.14 (excluded E, markup_status in_force, today W), a Welsh SI's retained repeal (W), a UK-wide law's retained repeal with savings (still everywhere: 1989/14 s.3(5)), an asp's (S)
- ⬜ Check `markup_status` / J2 afterwards: a retained repeal for part of the row's extent is in force elsewhere — J2 should no longer hold such rows repealed
- ⬜ Parse diff on the affected laws (`mix lat.parse_snapshot` / `lat.text_diff --store only`), classified; only territory fields and markup_status move
- ⬜ Gemini review of the change (parser territory rule), saved to `backend/data/code-reviews/`
- ⬜ Dry run → Jason → restore point (`legal_articles`, `amendment_annotations`, `lat_change_log`, `lat_label_timeline`) → re-parse (`mix lat.reparse --store only`, the laws whose parse changes; ParserVersion moves) — folded into the v0.1 relabel (V1-00)

## Dependencies

- ✅ V1-03 feed territory (the rule this reuses: `f5514bfd`, `086c2ab6`)
- ⬜ V1-03 closed (its 324-law preview spliced)
