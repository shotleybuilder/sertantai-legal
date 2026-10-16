---
session: 'LR-35: EffectTarget Document Order'
status: active
opened: 2026-10-16
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "EffectTarget's id order is xmerl's //*[@id] order (each node's children in turn: all Parts before their sections), not document order; span/3 resolves ranges over it"
    category: wrong join
    module: EffectTarget
    affected: "161 laws' effect joins (6,200 rows) differ under document order"
    fix: "Build the tree in document order (Xml.descendants/1); dry run the joins and labels; Jason decides"
    status: open
---

# Session: LR-35 EffectTarget Document Order (ACTIVE)

## Problem

Found by LR-31 E2 (2026-10-16). `EffectTarget.tree/1` took its id order from xpath `//*[@id]`, which xmerl returns as each node's children in turn (part-II, part-III … before section-1), not document order. `span/3` ("every id from first to last in document order") and range resolution run over that order, so a range ("ss. 50 - 55", "regs. 17 to 21") can take the wrong elements when it crosses a level. A one-walk tree in true document order changed the effect joins of 161 laws (about 6,200 rows' `effect_joins` / `effect_ids`, 106 `territory_provenance`, 47 note joins, 23 `excluded_extent`; e.g. apni 1969/6 Part II gains a whole-Part join). LR-31 kept xmerl's order (`Xml.descendants_xmerl/1`) so its refactor changes no output; this session decides the fix.

## Todo

- ✅ Measure: classify the 161 laws' join changes under document order (below)
- ⬜ Jason: D1 document order; D2 a range covers what lies wholly within it
- ⬜ Build (tree from `Xml.descendants/1`), zero other change; dry run → Jason → apply (re-parse, the joins are parse-time)

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
