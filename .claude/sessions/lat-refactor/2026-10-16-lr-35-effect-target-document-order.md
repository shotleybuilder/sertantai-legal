---
session: 'LR-35: EffectTarget Document Order'
status: pending
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

# Session: LR-35 EffectTarget Document Order (PENDING)

## Problem

Found by LR-31 E2 (2026-10-16). `EffectTarget.tree/1` took its id order from xpath `//*[@id]`, which xmerl returns as each node's children in turn (part-II, part-III … before section-1), not document order. `span/3` ("every id from first to last in document order") and range resolution run over that order, so a range ("ss. 50 - 55", "regs. 17 to 21") can take the wrong elements when it crosses a level. A one-walk tree in true document order changed the effect joins of 161 laws (about 6,200 rows' `effect_joins` / `effect_ids`, 106 `territory_provenance`, 47 note joins, 23 `excluded_extent`; e.g. apni 1969/6 Part II gains a whole-Part join). LR-31 kept xmerl's order (`Xml.descendants_xmerl/1`) so its refactor changes no output; this session decides the fix.

## Todo

- ⬜ Measure: classify the 161 laws' join changes under document order (right / wrong, against the law and the effect text)
- ⬜ Jason: adopt document order
- ⬜ Build (tree from `Xml.descendants/1`), zero other change; dry run → Jason → apply (re-parse, the joins are parse-time)

## Dependencies

- ⬜ LR-31 E2 committed (the helpers and the xmerl-order tree)
