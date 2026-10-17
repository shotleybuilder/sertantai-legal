---
session: 'LR-37: Orphan Join and Range Effects'
status: closed
opened: '2026-10-16'
closed: '2026-10-17'
outcome: success
parent: lat-refactor/2026-10-09-lr-00-meta.md
summary: 'The 47 dates eur 2006/1013 lost under LR-35 came from LR-19''s orphan join counting inline elements (Citation ids in a heading) as locations, not from the held rule as first logged. An orphan''s
  location is now its nearest structural id; applied by a store re-parse of all 1,066 laws 2026-10-17: 122 label gains in 6 laws, none lost.'
decisions:
- what: An orphan change's location is its nearest structural id; inline ids (Citation, CitationSubRef, Term, Definition, Abbreviation, Acronym, links, FootnoteRef) are skipped
  why: no effect lands on a citation; inline ids are everywhere (CitationSubRef 42,104 and Citation 17,127 in a 150-body sample) and broke the orphan's next-level agreement
  result: 89 previously unexplained changes join their effect in 5 laws; eur 2006/1013's 47 dates back
- what: Apply by re-parsing all 1,066 laws
  why: the parser version covers every law (0 stale is the wave's check)
  result: 0 errors, 0 stale, 122/122 predicted label changes live
metrics:
  wave_2026_10_17:
    laws: 1066
    errors: 0
    minutes: 59
    rows: 374866
    enriched_carried: 287676
    stale_after: 0
    predicted_label_changes_live: 122
    unknown_today: 18326
  measure:
    laws_changed: 6
    parse_differences: 335
    unexplained_changes_joined: 89
    joins_lost: 1
    label_gains: 122
    label_losses: 0
lessons:
- title: Log the symptom, not the suspected cause, until it's traced
  detail: LR-37 was opened as 'the held rule reads a range effect's markup as rival claims'; tracing the 211 markup pieces showed no piece held the effect at all — inline Citation ids were the cause.
  tag: data
- title: Ids in CLML aren't only on provisions
  detail: Citation, CitationSubRef, Term and links carry ids far more often than provisions do; any logic that walks 'the nearest id' must say which ids are structural.
  tag: data
bugs:
- pattern: 'An orphan change id (ChangeId not in the feed) is refused the effect its note cites when markup elsewhere in the same range effect holds it: LR-19''s ''held by another change'' reads a range
    effect''s own markup pieces as rival claims'
  category: lost join
  module: LatParser.Effects (held set) / EffectIndex.with_orphans
  affected: eur 2006/1013 47 rows; 89 unexplained changes in 5 laws now joined; 122 label gains (applied 2026-10-17)
  fix: 'Cause was not the held rule: an orphan''s locations counted inline elements'' ids (a heading''s <Citation id=''c00026''>), which carry no effect, so the next-level agreement failed. Locations are
    now structural ids only.'
  status: fixed
artifacts:
- backend/lib/sertantai_legal/scraper/lat_parser/effects.ex
- backend/test/sertantai_legal/scraper/lat_parser/orphan_location_test.exs
- backend/data/reports/lat-refactor/lr37-snapshot.compare.csv
- backend/data/reports/lat-refactor/lr37_dry.csv
- backend/data/reports/lat-reparse/lr37_wave.csv
depends_on:
- 2026-10-16-lr-35-effect-target-document-order
enables:
- LR-36 prospective substitution status
- parallel re-parse (LR-31 follow-on)
---

# Session: LR-37 Orphan Join and Range Effects (CLOSED)

## Problem

Found in LR-35's dry run (2026-10-16). eur 2006/1013 Art. 2A-2C were inserted by uksi 2019/590 (one effect, "Art. 2A-2C", in force 2020-12-31). Under xmerl's order the range reached only the three Article elements; in document order it reaches their sub-paragraphs, whose insertion markup joins the effect directly. Article 2A(1) carries a legacy ChangeId (`key-451023…`, not in the feed) that used to take this effect through its note (LR-19 orphan join); now the effect is "held" by the sub-paragraphs' markup, so the orphan is refused, its markup is unexplained, and 47 rows read "changed, date unknown". It's the same insertion: the held rule is reading one range effect's markup pieces as rival claims.

## Todo

- ✅ Measure: the cause isn't the held rule (below)
- ✅ Jason (2026-10-17: "Go ahead"): the rule and apply
- ✅ Build (tests first) and dry run (`lr37_dry`)
- ✅ Apply: NAS backup; re-parse of all 1,066 laws from the store (`lr37_wave`, 59 min) → verify: 0 errors, 0 stale, 122/122 label changes live, unknown today 18,326

## Dependencies

- ✅ LR-35 applied (2026-10-16)

## Measure (2026-10-16): the cause isn't the held rule

The orphan id (`key-451023…`, not in the feed) marks the whole inserted block: 211 markup pieces across Arts 2A-2C. No piece joins effect `key-4bc0…` directly, so it isn't "held". LR-19's orphan join takes the lowest element common to the pieces' locations (`title-I`), else asks every next-level location to agree on one effect. The locations include ids of **inline** elements: `c00026` / `c00027` are `<Citation>` elements inside Art. 2A's heading (`<P1group><Title>…<Citation id="c00026">`), with no effect on them, so the agreement failed. Under xmerl's order "Art. 2A-2C" happened to reach `title-I`, which hid this; LR-35's correct ranges exposed it. Inline elements carry ids constantly (in a 150-body sample: CitationSubRef 42,104, Citation 17,127, Term 2,900, links).

## Rule built (tests first)

An orphan change's location is its nearest **structural** id: inline elements carrying ids (Citation, CitationSubRef, Term, Definition, Abbreviation, Acronym, ExternalLink, InternalLink, FootnoteRef) are skipped (`LatParser.Effects`, `@inline_ids`). Test: `lat_parser/orphan_location_test.exs` (the eur 2006/1013 shape). 34 related tests pass.

**Measure (`lr37-snapshot` compare):** 335 parse differences in 6 laws; orphans now joining their effect (89 changes no longer unexplained): eur 2006/1013 47, WIA 1991 27, EPA 1990 8, uksi 2017/1013 3, WCA 1981 2. One join lost: ukpga 1996/18 s.235(1)'s legacy id `d29p25739` (note c16337431 loses its pointer to 1998/23); no label changes.

**Label dry run (`lr37_dry`, parse path, 6 laws):** 122 changes, all gains: effective_from gained 61, changed_by gained 61 (eur 2006/1013's 47 dates back; 16 EPA, 6 uksi 2017/1013, 4 WCA, 2 WIA). Nothing lost.
