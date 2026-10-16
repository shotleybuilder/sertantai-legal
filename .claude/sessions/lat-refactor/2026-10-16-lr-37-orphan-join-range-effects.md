---
session: 'LR-37: Orphan Join and Range Effects'
status: active
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

# Session: LR-37 Orphan Join and Range Effects (ACTIVE)

## Problem

Found in LR-35's dry run (2026-10-16). eur 2006/1013 Art. 2A-2C were inserted by uksi 2019/590 (one effect, "Art. 2A-2C", in force 2020-12-31). Under xmerl's order the range reached only the three Article elements; in document order it reaches their sub-paragraphs, whose insertion markup joins the effect directly. Article 2A(1) carries a legacy ChangeId (`key-451023…`, not in the feed) that used to take this effect through its note (LR-19 orphan join); now the effect is "held" by the sub-paragraphs' markup, so the orphan is refused, its markup is unexplained, and 47 rows read "changed, date unknown". It's the same insertion: the held rule is reading one range effect's markup pieces as rival claims.

## Todo

- ✅ Measure: the cause isn't the held rule (below)
- ⬜ Jason: the rule (an orphan's locations are structural elements) and apply
- ✅ Build (tests first) and dry run (`lr37_dry`)
- ⬜ Apply: re-parse of the 6 laws → verify

## Dependencies

- ✅ LR-35 applied (2026-10-16)

## Measure (2026-10-16): the cause isn't the held rule

The orphan id (`key-451023…`, not in the feed) marks the whole inserted block: 211 markup pieces across Arts 2A-2C. No piece joins effect `key-4bc0…` directly, so it isn't "held". LR-19's orphan join takes the lowest element common to the pieces' locations (`title-I`), else asks every next-level location to agree on one effect. The locations include ids of **inline** elements: `c00026` / `c00027` are `<Citation>` elements inside Art. 2A's heading (`<P1group><Title>…<Citation id="c00026">`), with no effect on them, so the agreement failed. Under xmerl's order "Art. 2A-2C" happened to reach `title-I`, which hid this; LR-35's correct ranges exposed it. Inline elements carry ids constantly (in a 150-body sample: CitationSubRef 42,104, Citation 17,127, Term 2,900, links).

## Rule built (tests first)

An orphan change's location is its nearest **structural** id: inline elements carrying ids (Citation, CitationSubRef, Term, Definition, Abbreviation, Acronym, ExternalLink, InternalLink, FootnoteRef) are skipped (`LatParser.Effects`, `@inline_ids`). Test: `lat_parser/orphan_location_test.exs` (the eur 2006/1013 shape). 34 related tests pass.

**Measure (`lr37-snapshot` compare):** 335 parse differences in 6 laws; orphans now joining their effect (89 changes no longer unexplained): eur 2006/1013 47, WIA 1991 27, EPA 1990 8, uksi 2017/1013 3, WCA 1981 2. One join lost: ukpga 1996/18 s.235(1)'s legacy id `d29p25739` (note c16337431 loses its pointer to 1998/23); no label changes.

**Label dry run (`lr37_dry`, parse path, 6 laws):** 122 changes, all gains: effective_from gained 61, changed_by gained 61 (eur 2006/1013's 47 dates back; 16 EPA, 6 uksi 2017/1013, 4 WCA, 2 WIA). Nothing lost.
