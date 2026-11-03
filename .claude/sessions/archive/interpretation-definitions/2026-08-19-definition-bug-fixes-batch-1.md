---
session: Definition Bug Fixes Batch 1
status: closed
opened: 2026-08-19
closed: 2026-08-19
outcome: success

summary: >
  Fixed top 3 definition parser/resolver bugs by affected count. Title-stripping
  regex fix immediately moved 114 items from parent_not_in_lrt to correct categories.
  Parser fixes (leading ')' strip, internal_ref? expansion) apply on next re-parse.
  All 1,512 tests pass.

decisions:
  - what: Title-stripping regex fix uses digit anchor instead of restructuring
    why: The simplest distinguisher between "Regulation Act" (title word) and "regulation 5" (section ref) is that section refs are always followed by a digit. Changing .+ to \d.* after the keyword handles all observed cases.
    result: 114 parent_not_in_lrt items correctly reclassified, 0 regressions

  - what: Leading ')' strip placed in clean_definition not text_content
    why: clean_definition is called by Definition.new/1 for every definition. Fixing at this level means all 3 parser strategies benefit without strategy-specific changes.
    result: Single-point fix covering all definition sources

  - what: internal_ref? strips leading ')' before pattern matching
    why: 2,006 definitions start with ')' which disrupts all regex patterns. Stripping it before matching is simpler than adding ')?' to every pattern.
    result: Both @internal_ref_re and @internal_ref_has_meaning_re benefit from the strip

metrics:
  tests: { total: 1512, passed: 1512, failed: 0 }
  diagnostic_delta: { parent_not_in_lrt: -114, term_not_found: +120, parent_unparsed: -22, no_citation: +102, term_normalisation: +6, citation_ambiguous: +3 }
  bugs_fixed: 5
  bugs_remaining: 18

lessons:
  - title: Resolver fixes show immediately in diagnostic; parser fixes need re-parse
    detail: >
      The title-stripping regex fix applies at diagnostic query time — results
      changed immediately. But clean_definition and internal_ref? changes only
      apply when Definition.new/1 is called during parsing. Existing DB records
      retain old values. A re-parse of affected laws is needed to see the full
      impact of parser fixes.
    tag: tooling

bugs:
  - pattern: "Definition text starts with ')' — parser extracts text from middle of parenthetical XML"
    category: parser
    module: DefinitionParser
    affected: 2006
    fix: "Added leading ')' strip in clean_definition"
    status: fixed

  - pattern: "internal_ref? not catching many genuine internal refs — inflates no_citation bucket"
    category: no_citation
    module: CitationExtractor
    affected: 1000
    fix: "Added @internal_ref_has_meaning_re pattern and leading ')' strip in internal_ref?"
    status: fixed

  - pattern: "internal_ref? misses 'has the meaning given/assigned in regulation/section N' pattern"
    category: no_citation
    module: CitationExtractor
    affected: 743
    fix: "Same fix as above — added 'has/have the meaning given/assigned/provided' regex"
    status: fixed

  - pattern: "resolve_law_name regex strips words in law TITLES — singular 'Regulation' matched as section ref"
    category: parent_not_in_lrt
    module: Diagnostic + Matcher (resolve_law_name)
    affected: 295
    fix: "Changed regex from .+ to \\d.* after keyword — requires digit after section/regulation/article"
    status: fixed

  - pattern: "Title-stripping regex triggers on bare citations too"
    category: parent_not_in_lrt
    module: resolve_law_name
    affected: 18
    fix: "Same regex fix — \\d.* instead of .+"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser/definition.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex

depends_on:
  - interpretation-definitions/2026-08-18-fire-domain-definition-qa
  - interpretation-definitions/2026-08-18-transport-safety-definition-qa
  - interpretation-definitions/2026-08-18-public-consumer-definition-qa
  - interpretation-definitions/2026-08-19-mining-offshore-health-definition-qa

enables:
  - Re-parse batch to apply parser fixes to existing definitions in DB
  - Bug fixes batch 2 targeting next tier (definition list bleed, concatenated terms, etc.)
---

# Session: Definition Bug Fixes Batch 1 (CLOSED)

## Problem

4 bug-surfacing sessions discovered 23 open bugs in the definition parser and resolver. This session fixes the top 3 by affected count, addressing ~4,062 definitions. All bugs have exact code locations identified.

Bugs to fix:
1. **Leading `)` parser truncation** (2,006 defs) — `definition_list_strategy.ex:extract_via_term_element/1` doesn't strip leading `)` from definition text
2. **internal_ref? expansion** (1,000 + 743 = ~1,743) — `definition.ex:@cross_ref_patterns` misses "has the meaning given in", "has the meaning assigned", and leading `)` variants
3. **Title-stripping regex** (~313) — `diagnostic.ex:resolve_law_name/2` and `matcher.ex:resolve_to_root/4` regex matches "Regulation" in law titles

## Todo

- ✅ Fix leading `)` in definition text extraction — strip `\A\)\s*` in clean_definition
- ✅ Expand internal_ref? patterns — added @internal_ref_has_meaning_re + leading `)` strip in internal_ref?
- ✅ Fix title-stripping regex — changed `.+` to `\d.*` after keyword in 3 locations
- ✅ Run tests — 1,512 pass, 0 failures
- ✅ Re-run diagnostic — regex fix moved 114 items from parent_not_in_lrt → term_not_found; parser fixes (#1, #2) need re-parse to show in DB

## Dependencies

- ✅ Fire Domain Definition QA (2026-08-18)
- ✅ Transport Safety Definition QA (2026-08-18)
- ✅ Public & Consumer Safety Definition QA (2026-08-18)
- ✅ Mining, Offshore & Health Definition QA (2026-08-19)
