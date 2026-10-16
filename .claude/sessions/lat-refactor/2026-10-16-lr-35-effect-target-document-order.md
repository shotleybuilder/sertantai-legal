---
session: 'LR-35: EffectTarget Document Order'
status: closed
opened: '2026-10-16'
closed: '2026-10-16'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'EffectTarget now resolves an effect''s ranges in document order (as EffectIndex already did) and a range covers what lies wholly within it, from its first element''s start to the end of its last
  element''s contents. Applied by a store re-parse of all 1,066 laws 2026-10-16: 175 laws'' joins changed, 384 label changes in 23 laws, all live; unknown today 18,340 → 18,326. Two side effects opened
  as LR-36 and LR-37.'
decisions:
- what: 'D1: document order for EffectTarget'
  why: the parser ran two orders (EffectIndex document order, EffectTarget xmerl's `//` order) and span/3 documents document order; xmerl's order let 's. 2-7' reach Chapter headings far away
  result: 12 Chapter headings and 11 EU articles no longer wrongly repealed
- what: 'D2: a range covers what lies wholly within it'
  why: document order alone made 's. 2-7' reach the Part 2 element that starts inside (Fire (Scotland) Act 2005 Part 2 would have read repealed) and 'Pt. 3-5' stop at Part 5's heading
  result: Part 2 untouched; Part ranges take their last Part whole
- what: Apply now; side effects as their own sessions
  why: the fixes are wrong repeals; LR-37's 47 lost dates become honest unknowns; LR-36's flaw predates LR-35
  result: LR-36 (pending substitution reads prospective, 117 rows) and LR-37 (orphan join vs range effects, 47 rows) opened
metrics:
  wave_2026_10_16:
    laws: 1066
    errors: 0
    rows: 374866
    enriched_carried: 287676
    dropped: 0
    stale_after: 0
    predicted_label_changes_live: 384
    mismatches: 0
    unknown_today_before: 18340
    unknown_today_after: 18326
  measure:
    laws_join_changes: 175
    parse_differences: 20642
    effects_changed_doc_order_only: 844
    label_changes: 384
    laws_label_changes: 23
lessons:
- title: A performance refactor is the cheapest place to find an order bug
  detail: LR-31's zero-diff gate failed only because a one-walk tree used document order where xmerl's xpath hadn't; keeping the refactor bug-compatible and opening a session for the order kept both honest.
  tag: tooling
- title: Fixing an order exposes the rules that relied on it
  detail: Document order alone created a new fault (a Part starting inside a range), surfaced a pre-existing one (pending substitutions read prospective, LR-36) and an interaction (LR-19's held rule vs
    range effects, LR-37). Dry-run the label effect and read the losers, not only the totals.
  tag: data
bugs:
- pattern: 'EffectTarget''s id order is xmerl''s //*[@id] order (each node''s children in turn: all Parts before their sections), not document order; span/3 resolves ranges over it'
  category: wrong join
  module: EffectTarget
  affected: 175 laws' effect joins; 384 label changes in 23 laws (applied 2026-10-16)
  fix: Build the tree in document order (Xml.descendants/1); dry run the joins and labels; Jason decides
  status: fixed
- pattern: A range of provisions took a Part or Chapter that only starts inside it, and stopped at its last element instead of after its contents ('Pt. 3-5' without Part 5's contents)
  category: wrong join
  module: EffectTarget.span/3
  affected: asp 2005/5 Part 2 (would have read repealed); asc 2023/3 Part 5; the 175 laws
  fix: 'D2: a range covers what lies wholly within it (first''s start to last''s contents end)'
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/effect_target.ex
- backend/test/sertantai_legal/scraper/effect_target_test.exs
- backend/data/reports/lat-refactor/lr35_compare2.csv
- backend/data/reports/lat-refactor/lr35_effects.csv
- backend/data/reports/lat-refactor/lr35_dry2.csv
- backend/data/reports/lat-reparse/lr35_wave.csv
depends_on:
- 2026-10-15-lr-31-pipeline-performance
- 2026-10-15-lr-29-container-ref-overreach
enables:
- LR-36 prospective substitution status
- LR-37 orphan join and range effects
---

# Session: LR-35 EffectTarget Document Order (CLOSED)

## Problem

Found by LR-31 E2 (2026-10-16). `EffectTarget.tree/1` took its id order from xpath `//*[@id]`, which xmerl returns as each node's children in turn (part-II, part-III … before section-1), not document order. `span/3` ("every id from first to last in document order") and range resolution run over that order, so a range ("ss. 50 - 55", "regs. 17 to 21") can take the wrong elements when it crosses a level. A one-walk tree in true document order changed the effect joins of 161 laws (about 6,200 rows' `effect_joins` / `effect_ids`, 106 `territory_provenance`, 47 note joins, 23 `excluded_extent`; e.g. apni 1969/6 Part II gains a whole-Part join). LR-31 kept xmerl's order (`Xml.descendants_xmerl/1`) so its refactor changes no output; this session decides the fix.

## Todo

- ✅ Measure: classify the 161 laws' join changes under document order (below)
- ✅ Jason 2026-10-16: "Agree recommendations" (D1 document order; D2 a range covers what lies wholly within it)
- ✅ Build: tree in document order with each position's contents end (`ends`); `span/3` takes elements wholly within first's start .. last's contents end; ids-only trees unchanged (6 tests)
- ✅ Dry run → Jason ("Go") → NAS backup → `mix lat.reparse --store only` over all 1,066 laws (the parser version covers all) → verify: 0 errors, 0 stale, 384/384 predicted label changes live, 18,326 unknown today

## Dependencies

- ✅ LR-31 E2 committed (0e70306c: the helpers and the xmerl-order tree)

## Measure (2026-10-16)

**Two orders in one parser.** `EffectIndex`'s ids (`//@id`, the refs fallback and `as_given` spans) are in document order (checked: EPA 1990, apni 1969/6, uksi 1996/1527); `EffectTarget.tree`'s were xmerl's `//*[@id]` order (each node's children in turn). `span/3` documents "in document order".

**Fix built (tests first, 3 tests):** `EffectTarget.tree/1` in document order (`Xml.descendants/1`). Parse compare against the xmerl-order baseline (`lr31-snapshot`): 12,633 differences in 161 laws (`lr35_compare.csv`). Per effect (`lr35_effects.csv`): 844 effects change; 813 only gain rows, 20 only lose (226 row joins), 11 both.

| Range in the effect's text | Effects | Row joins changed |
|---|---|---|
| Subsection ("reg. 20(11)-(17)", "s. 6(1)-(6)") | 500 | 3,234 |
| Section ("s. 55-106 (Pt. 3)", "regs 3–6, 8") | 323 | 1,817 |
| Container ("Pt. 3-5", "Pt. 2-6") | 6 | 3,614 |
| Other | 15 | 146 |

Under xmerl's order a range missed what lay between its ends at deeper levels (reg. 20(16)(b) under "reg. 20(11)-(17)"; cross-headings between "s. 55-106"). Document order takes them.

**Second finding: a range stops at its last element, not after its contents.** "Pt. 3-5" in document order runs from Part 3 to the Part 5 element itself: Parts 3 and 4 entire, Part 5's heading only (asc 2023/3: 1,202 rows gained, Part 5's contents not among them). Under xmerl's order it took only the three Part elements. For a section range the end's own subsections are reached through their ancestor anyway; for a container range they aren't.

## Label dry run, document order alone (`lr35_dry`, parse path, 161 laws)

0 errors; 500 label changes in 29 laws; unknown today 6,686 → 6,674 in those laws. The changes show both sides:

- **Fixes:** under xmerl's order asp 2005/5's repeal of "s. 2-7" reached the headings of Chapters 2–10 (`pt.2.ch.2` … `pt.2.ch.10`), which aren't near those sections; document order drops them (12 headings repealed → in force).
- **A new fault:** in document order the same range reaches `pt.2`, the Part 2 element, because Part 2 *begins* between s.2 and s.7 — and Part 2 of the Fire (Scotland) Act 2005 would read **repealed since 2013** though most of it is in force. The mirror of the "Pt. 3-5" finding: a container that starts inside a range but runs past it isn't in it, and one that ends a range is in it whole.

So document order alone is not the fix; a range needs a rule for containers it only partly covers.

## Decisions for Jason

- **D1. Document order** for `EffectTarget` (recommended): one order in the parser, as `span/3` documents.
- **D2. A range covers what lies wholly within it** (recommended): from the start of its first element to the end of its last element's contents; an element is in the range when all of it is. So "Pt. 3-5" is Parts 3, 4 and 5 entire; "s. 2-7" is ss. 2–7 with the cross-headings and subsections between, but not Part 2, which starts inside and runs past s.7. The refs fallback (`EffectIndex` flat spans, no tree) is unchanged.

## Build (2026-10-16, D1 + D2)

`EffectTarget.tree/1` in document order, recording where each position's contents end (`ends`); `span/3` runs from `first`'s start to the end of `last`'s contents and keeps every element wholly inside. An ids-only tree (`flat/1`, the refs fallback) has no contents: unchanged. Tests: tree order, "s. 2-7"-shaped range without the Part that starts inside, a range of Parts taken whole, the flat fallback. 1,769 scraper tests pass.

Parse compare against the xmerl-order baseline: 20,642 differences in 175 laws (`lr35_compare2.csv`; effect_joins 10,256, effect_ids 10,209, territory_provenance 75, note joins 47, unjoined_changes 47, excluded_extent 8). Label dry run (`lr35_dry2`, parse path, 175 laws) running.

## Dry run 2 (`lr35_dry2`, parse path, 175 laws, D1 + D2)

0 errors; 384 label changes in 23 laws; unknown today in those laws 6,875 → 6,861; no rows added or removed.

**Checked fixes:**
- asp 2005/5 (Fire (Scotland) Act): `pt.2` unchanged, so the Part 2 regression is gone. The 12 Chapter headings (`pt.2.ch.2` … `ch.10`) that "s. 2-7" wrongly repealed under xmerl's order go back to in force; the cross-heading `h.6`, inside ss. 2-7, is repealed with them.
- eur 2006/561: the saved repeal of "Art. 15-19" no longer reaches Articles 11 and 14 (11 rows repealed_saved → in force).
- uksi 2026/318: reg. 11(1)(c)-(i) commence on 19 Jan 2027 (the law's own commencement effect), so their in-force date empties (4 rows).

**Two side effects, each its own bug and session:**
- **LR-37** (eur 2006/1013, 47 rows lose their date): the range now reaches Art. 2A's sub-paragraphs, whose insertion markup joins the effect directly; LR-19's "held by another change" then refuses Art. 2A(1)'s legacy orphan id the same effect, and its markup reads "changed, date unknown".
- **LR-36** (ukpga 1988/52 s.127(3)(a)-(d) in force → prospective): a pending (never commenced) substitution of s.127(1)-(4) now reaches them; D3 already reads s.127(1)-(3) prospective today though their text is in force — a pre-existing flaw (117 rows corpus-wide where the label says prospective and the markup in force).

## Apply (2026-10-16)

NAS backup; `mix lat.reparse --laws <all 1,066> --store only --tag lr35_wave`: 0 errors; rows 374,866 → 374,866; enriched 287,676 carried, 0 dropped or changed. Verify: `lat.stale --strict` 0; 384 of 384 predicted label changes live; 18,326 provisions unknown today (18,340 − 14, as predicted).
