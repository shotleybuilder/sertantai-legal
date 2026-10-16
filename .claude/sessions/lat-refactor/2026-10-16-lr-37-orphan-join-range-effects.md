---
session: 'LR-37: Orphan Join and Range Effects'
status: pending
opened: 2026-10-16
parent: lat-refactor/2026-10-09-lr-00-meta.md
bugs:
  - pattern: "An orphan change id (ChangeId not in the feed) is refused the effect its note cites when markup elsewhere in the same range effect holds it: LR-19's 'held by another change' reads a range effect's own markup pieces as rival claims"
    category: lost join
    module: LatParser.Effects (held set) / EffectIndex.with_orphans
    affected: "eur 2006/1013 Art. 2A: 47 rows lose their date under LR-35"
    fix: "Markup occurrences joined to the same effect through its range aren't another change; let an orphan take an effect held only by occurrences of that effect's own range; Jason decides"
    status: open
---

# Session: LR-37 Orphan Join and Range Effects (PENDING)

## Problem

Found in LR-35's dry run (2026-10-16). eur 2006/1013 Art. 2A-2C were inserted by uksi 2019/590 (one effect, "Art. 2A-2C", in force 2020-12-31). Under xmerl's order the range reached only the three Article elements; in document order it reaches their sub-paragraphs, whose insertion markup joins the effect directly. Article 2A(1) carries a legacy ChangeId (`key-451023…`, not in the feed) that used to take this effect through its note (LR-19 orphan join); now the effect is "held" by the sub-paragraphs' markup, so the orphan is refused, its markup is unexplained, and 47 rows read "changed, date unknown". It's the same insertion: the held rule is reading one range effect's markup pieces as rival claims.

## Todo

- ⬜ Measure: orphans refused only because the effect is held by occurrences inside that effect's own range
- ⬜ Jason: the rule
- ⬜ Build, dry run → Jason → apply (re-parse)

## Dependencies

- ✅ LR-35 applied (2026-10-16)
