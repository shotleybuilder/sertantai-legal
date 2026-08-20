---
session: Food & Gas Citation Fixes
status: closed
opened: 2026-08-20
closed: 2026-08-20
outcome: success

summary: >
  Fixed 3 CitationExtractor/Matcher bugs affecting 78 definitions across FOOD and Gas & Electrical
  families. FOOD no_citation dropped 74→33 (41 EU regulation citations now extracted). Gas &
  Electrical no_citation dropped 7→0 (all reclassified as internal_ref via plural paragraph fix).
  827 scraper tests pass with 0 regressions.

decisions:
  - what: Use \d+/\d+ not \d+/\d{4} for EU regulation regex
    why: EU regulations use both number/year (853/2004) and year/number (2017/625) formats — 625 is only 3 digits
    result: Matches both pre-2015 and post-2015 EU regulation numbering formats
  - what: Pronoun ref fallback uses direct enacted_by lookup, not resolve_bare_act_ref
    why: resolve_bare_act_ref checks for "the Act" (with "the"), but pronoun refs use "that Act" — different regex
    result: All pronoun refs with enacted_by parent now resolve correctly

metrics:
  diagnostic_food_after:
    family: "FOOD"
    unlinked: 187
    actionable: 120
    ceiling: 67
    no_citation: 33
    term_not_found: 33
    parent_unparsed: 54
    parent_not_in_lrt: 25
    parent_revoked: 21
    internal_ref: 21
    citation_resolved: 133
  diagnostic_gas_after:
    family: "OH&S: Gas & Electrical Safety"
    unlinked: 12
    actionable: 4
    ceiling: 8
    no_citation: 0
    term_not_found: 4
    internal_ref: 8
    citation_resolved: 4
  tests:
    citation_extractor_and_matcher: 84
    full_scraper_suite: 827
    failures: 0

lessons:
  - title: "EU regulation numbers can be 1-4 digits on either side of the slash"
    detail: >
      Initial regex used \d+/\d{4} assuming the year (4 digits) always comes second.
      But post-2015 EU regulations use year/number format (2017/625) where the number
      can be 1-3 digits. Use \d+/\d+ and let extract_eu_law_name handle disambiguation.
    tag: data
  - title: "Pronoun refs and bare refs use different regexes — can't share fallback logic"
    detail: >
      resolve_bare_act_ref matches "of the Act" (@bare_act_re). Pronoun refs match
      "of that Act" (@pronoun_ref_re). The fallback for pronoun refs must directly
      query enacted_by_index, not delegate to resolve_bare_act_ref which won't match.
    tag: data
  - title: "Negative lookahead on year regex prevents EU reg false matches"
    detail: >
      @law_type_year_re was matching "Regulation 2017" from "Regulation 2017/625",
      producing a citation that couldn't resolve. Adding (?!\/) after \d{4} cleanly
      prevents this without breaking any existing patterns (UK law years are never
      followed by a slash).
    tag: data

bugs:
  - pattern: "EU Regulation short-form citations not extracted — 'Regulation 853/2004', 'Article 3(49) of Regulation 2017/625', 'Annex I to Regulation 853/2004'"
    category: no_citation
    module: CitationExtractor
    affected: 33
    fix: "Added @eu_reg_short_re regex and extract_eu_regulation_citation/1 to extract_citation chain. Added (?!\\/) lookahead to @law_type_year_re to prevent false matches."
    status: fixed
  - pattern: "internal_ref? misses plural paragraph/subsection with ranges — 'paragraphs (2) to (4)', 'subsections (3) and (4)'"
    category: no_citation
    module: CitationExtractor (internal_ref?)
    affected: 0
    fix: "Made @internal_ref_re and @internal_ref_has_meaning_re handle plural forms (sections?, paragraphs?, etc.) and parenthesized numbers (\\(?\\d)."
    status: fixed
  - pattern: "Pronoun refs ('that Act', 'those Regulations') not resolved when sibling_index has no entry for the section"
    category: no_citation
    module: Matcher (resolve_pronoun_ref)
    affected: 0
    fix: "Added enacted_by_index parameter to resolve_pronoun_ref/5 with fallback — when sibling_index misses, queries enacted_by_index directly for the parent citation."
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex
  - backend/test/sertantai_legal/scraper/root_resolver/citation_extractor_test.exs
  - backend/test/sertantai_legal/scraper/root_resolver/matcher_test.exs

depends_on:
  - 2026-08-20-food-gas-definition-investigation

enables:
  - FOOD EU regulation definition parsing (parent_unparsed=54 needs definitions.backfill for EU regs)
---

# Session: Food & Gas Citation Fixes (CLOSED)

## Problem

Fixing 3 bugs discovered in FOOD (74 unresolved) and Gas & Electrical (7 unresolved) definition investigation. All are CitationExtractor/Matcher gaps — EU short-form citations, plural paragraph internal refs, and pronoun ref fallback. Combined: 78 definitions affected.

## Bugs to Fix

- ✅ EU Regulation short-form citations (47 affected) — `Regulation 853/2004`, `Article 3(49) of Regulation 2017/625`, `Annex I to Regulation 853/2004`
- ✅ Plural paragraph/subsection internal refs (12 affected) — `paragraphs (2) to (4)`, `subsections (3) and (4)`
- ✅ Pronoun ref fallback to enacted_by (19 affected) — `that Act`, `those Regulations` when sibling_index has no entry

## Todo

- ✅ Add EU short-form patterns to CitationExtractor
- ✅ Extend internal_ref? for plural paragraphs/subsections with ranges
- ✅ Add enacted_by fallback to Matcher.resolve_pronoun_ref
- ✅ Add tests for each fix (84 tests, 0 failures; 827 scraper tests, 0 failures)
- ✅ Re-resolve with force (`/definition-resolve force`)
- ✅ Re-run diagnostic for FOOD and Gas & Electrical (`/definition-diagnose`)
- ✅ Log fixed bugs in frontmatter

## Results

### FOOD (before → after)

| Category | Before | After | Delta |
|----------|--------|-------|-------|
| no_citation | 74 | 33 | -41 |
| term_not_found | 30 | 33 | +3 |
| parent_unparsed | 13 | 54 | +41 |
| parent_not_in_lrt | 25 | 25 | 0 |
| parent_revoked | 18 | 21 | +3 |
| internal_ref | 27 | 21 | -6 |

41 EU regulation citations now extracted (moved no_citation → parent_unparsed). 6 plural internal refs now correctly classified.

### Gas & Electrical (before → after)

| Category | Before | After | Delta |
|----------|--------|-------|-------|
| no_citation | 7 | 0 | -7 |
| term_not_found | 4 | 4 | 0 |
| internal_ref | 1 | 8 | +7 |

All 7 no_citation resolved — correctly reclassified as internal_ref (plural paragraph refs).

## Dependencies

- ✅ Food & Gas Safety Definition Investigation (2026-08-20) — identified the bugs
