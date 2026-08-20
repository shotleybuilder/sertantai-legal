---
session: Substantive Section Definition Parsing
status: closed
opened: 2026-08-20
closed: 2026-08-20
outcome: success

summary: >
  Root cause of FOOD's sub-90% was not missing section-level parsing but misclassified citation
  definitions. Definitions like "the Act means the Food Safety Act 1990" had citation=false,
  inflating the cross-ref denominator by 19. Added definition_is_law_name? check to
  Definition.new/1. FOOD 86.3%->91.8%. All 19 safety families now above 90%.

decisions:
  - what: Fix citation classification rather than build demand-driven section parser
    why: >
      Investigation revealed 11 of 15 FOOD term_not_found from Food Safety Act were
      citation definitions (term=act, def=the Food Safety Act 1990), not cross-references.
      They inflated the denominator. Fixing the flag was simpler and more correct than
      building section-level parsing infrastructure.
    result: FOOD 86.3% to 91.8%, denominator 190 to 171

metrics:
  diagnostic_food:
    family: "FOOD"
    cross_refs: 171
    linked: 39
    effective_pct: 91.8
    no_citation: 14
    term_not_found: 38
    citation_defs_reclassified: 19
  all_families:
    above_90_pct: 19
    below_90_pct: 0
  tests:
    scraper_suite: 854
    failures: 0

lessons:
  - title: "Citation definitions (law-name abbreviations) must be excluded from cross-ref resolution"
    detail: >
      Definitions like 'the Act means the Food Safety Act 1990' are abbreviation
      definitions, not cross-references. They define what 'the Act' means in the SI,
      they don't reference a definition IN the Food Safety Act. When citation=false,
      the resolver tries to find term 'act' in the parent, fails, and reports
      term_not_found. The fix: detect when the definition text IS a law name and
      set citation=true. This is a data classification bug, not a parser coverage gap.
    tag: data
  - title: "When a metric won't move, question the metric before building more features"
    detail: >
      We built EU annex parsing, fixed Directive extraction, and added parenthetical
      title matching — all correct but none moved the FOOD %. The user asked 'what
      went wrong?' which led to examining the actual child definitions. The root cause
      was 19 law-name definitions inflating the denominator. The fix was 5 lines of
      regex, not a new parser strategy.
    tag: data
  - title: "Reparsing after Definition struct changes requires targeted reparse of affected laws"
    detail: >
      After adding definition_is_law_name? to Definition.new/1, existing DB rows still
      had citation=false. Had to identify and reparse the 10 specific laws whose citation
      definitions needed the new flag. The persist upsert updates the citation column.
    tag: data

bugs:
  - pattern: "Law-name definitions (act means the Food Safety Act 1990) not flagged as citations"
    category: term_not_found
    module: DefinitionParser (Definition struct)
    affected: 0
    fix: "Added definition_is_law_name? check to Definition.new/1 — detects when definition text IS a law name and sets citation=true"
    status: fixed
  - pattern: "Section-level definitions not parsed — terms defined in substantive sections (not interpretation section) absent from parent"
    category: term_not_found
    module: DefinitionParser
    affected: 72
    fix: "Partially mitigated by citation flag fix (reduces denominator). Full section parsing still needed for remaining term_not_found. See #153."
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser/definition.ex
  - backend/test/sertantai_legal/scraper/definition_parser/definition_test.exs

depends_on:
  - 2026-08-20-definition-fixes-final-batch
  - 2026-08-20-issue-152-eu-annex-parsing

enables:
  - "Corpus-wide reparse to propagate citation flag (law-name definitions across all families)"
---

# Session: Substantive Section Definition Parsing (CLOSED)

## Problem

UK Acts define many terms in substantive sections, not interpretation sections. 1,235 term_not_found corpus-wide have section refs in citations. Food Safety Act 1990 alone has 18 missing terms. This is the single largest remaining gap for definition resolution. See #153.

## Todo

- ✅ Analyse section XML for Food Safety Act — found structural defs + citation misclassification
- ✅ Design approach — fix citation flag on law-name definitions (simpler than section parser)
- ✅ Write failing tests — definition_is_law_name? detection (4 tests)
- ✅ Implement — added @definition_is_law_re + definition_is_law_name?/1 to Definition struct
- ✅ Reparse 10 affected FOOD laws to propagate citation flag
- ✅ Re-resolve — FOOD 91.8%, all 19 safety families above 90%

## Dependencies

- ✅ Definition Fixes Final Batch (2026-08-20) — S3 includes verb fix
- ✅ EU Regulation Annex Parsing (2026-08-20, #152) — closed, parse_annex/2 built
