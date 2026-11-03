---
session: Definition Fixes Final Batch
status: closed
opened: 2026-08-20
closed: 2026-08-20
outcome: partial

summary: >
  Fixed 5 of 6 remaining open bugs (FRS abbreviation expansion, international convention
  diagnostic category, S3 "includes" verb, Continental Shelf Act reparse). 841 tests pass.
  18/19 safety families above 90% target. FOOD stuck at 82.6% — root cause is parser coverage
  of EU regulation annexes and UK Act substantive sections, not citation extraction. Raised
  #152 and #153 for the two parser features needed to close the gap.

decisions:
  - what: Defer consolidated Act mismatch (2 affected)
    why: Parent is revoked (ceiling), successor mapping mechanism not worth building for 2 definitions
    result: 2 definitions remain as parent_revoked ceiling
  - what: Scope section-level definitions as S3 includes verb only, defer broader untagged parsing
    why: Untagged substantive section definitions need a new parser strategy — too large for this batch
    result: Raised #153 for dedicated session

metrics:
  tests:
    scraper_suite: 841
    failures: 0
  resolution_by_family:
    above_90_pct: 18
    below_90_pct: 1
    food_effective_pct: 82.6
  diagnostic_food:
    family: "FOOD"
    cross_refs: 190
    linked: 18
    unlinked: 172
    actionable: 105
    ceiling: 67
    no_citation: 33
    term_not_found: 69
    citation_ambiguous: 3
    parent_not_in_lrt: 26
    parent_revoked: 20
    internal_ref: 21

lessons:
  - title: "Citation extraction fixes can expose parser coverage gaps — no_citation→parent_unparsed→term_not_found"
    detail: >
      FOOD no_citation dropped 74→33 after EU reg extraction fix. But parsing those EU regs
      revealed only 2 definitions in Reg 853/2004 vs 22 children expecting terms like "meat".
      The terms are in Annex I, not main articles. Fixing citation extraction just shifted the
      bottleneck from "can't find the law" to "can't find the term in the law".
    tag: data
  - title: "EU Regulations define terms in annexes, not articles — parser needs annex support"
    detail: >
      UK legislation puts definitions in interpretation sections. EU Regulations put them in
      annexes (Annex I of Reg 853/2004 defines all food terms). The parser has no annex
      support, so EU reg parents appear parsed but empty. This is the root cause of FOOD's
      82.6% — not a citation extraction problem.
    tag: data
  - title: "Abbreviation expansion must handle 'ABBREV Act YYYY' → replace ABBREV+Type, not just ABBREV"
    detail: >
      First attempt at FRS expansion replaced "FRS" with "Fire and Rescue Services Act",
      producing "Fire and Rescue Services Act Act 2004". The title already contains "Act"
      from extract_named_law. Fix: regex-replace "FRS Act" as a unit.
    tag: data

bugs:
  - pattern: "'FRS' and other common abbreviations not in title_index — 'FRS Act 2004' can't resolve to Fire and Rescue Services Act"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Added 'frs' to @statute_abbreviations + expand_abbreviation_in_title to expand initials in extracted named law titles"
    status: fixed
  - pattern: "FRS abbreviation unresolvable — same class as TCPA abbreviation bug"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Same fix as above — abbreviation expansion in extract_citation chain"
    status: fixed
  - pattern: "International convention refs (SOLAS, UNCLOS, MLC, ICAO Annex 13, Radio Regulations) can't resolve — not UK legislation"
    category: no_citation
    module: CitationExtractor
    affected: 0
    fix: "Added international_convention? detector + :international_convention diagnostic category (ceiling)"
    status: fixed
  - pattern: "Continental Shelf Act 1964 has only 1 definition extracted but 14 children reference it"
    category: term_not_found
    module: DefinitionParser
    affected: 13
    fix: "S3 'includes' verb support extracted 'installation'. Remaining 13 children need untagged term parsing (#153)."
    status: fixed
  - pattern: "Concatenated terms bug is 72 pairs / 51 laws corpus-wide, not 6 as estimated in FIRE session"
    category: parser
    module: DefinitionParser
    affected: 0
    fix: "Code fix already in place from session #151. All stale data cleaned. No new code needed."
    status: fixed
  - pattern: "EU Regulation annex definitions not parsed — terms defined in Annex I absent from parent definitions"
    category: term_not_found
    module: DefinitionParser
    affected: 30
    fix: "New parser strategy needed for annex XML. See #152."
    status: open
  - pattern: "Substantive section definitions not parsed — terms defined outside interpretation sections absent from parent"
    category: term_not_found
    module: DefinitionParser
    affected: 1235
    fix: "Demand-driven or proactive section parsing. See #153."
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/matcher.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/section_term_strategy.ex
  - backend/test/fixtures/legislation_gov_uk/section_includes_verb.xml

depends_on:
  - 2026-08-19-ohs-resolution-audit
  - 2026-08-20-food-gas-definition-investigation
  - 2026-08-20-food-gas-citation-fixes

enables:
  - "EU Regulation Annex Parsing (#152)"
  - "Substantive Section Definition Parsing (#153)"
---

# Session: Definition Fixes Final Batch (CLOSED)

## Problem

Fixing all 8 remaining open bugs (6 unique patterns) affecting 178 definitions across DefinitionParser, CitationExtractor, and Indexes. TDD approach — write failing tests first, then implement fixes.

## Bugs to Fix

- ✅ FRS abbreviation (2 affected) — expand abbreviations in extracted named law titles
- ✅ International conventions (12 affected) — new :international_convention diagnostic category
- ✅ Concatenated terms (72 affected) — code fix already in place (session #151), needs reparse only
- ✅ Continental Shelf Act 1964 (14 affected) — S3 "includes" verb + untagged defs overlap with section-level
- ✅ Section-level definitions — S3 "includes" verb fix done; broader untagged-term parsing deferred
- ⏸️ Consolidated Act mismatch (2 affected) — deferred, parent_revoked ceiling, not worth successor mapping for 2 items

## Todo

- ✅ Write failing tests for each bug (RED)
- ✅ Implement fixes (GREEN) — 841 scraper tests, 0 failures
- ✅ Re-parse affected laws (Continental Shelf Act — installation now extracted)
- ✅ Re-resolve with force
- ✅ Re-run diagnostic — 18/19 families >90%, FOOD at 82.6% (parser coverage gap, not extraction)
- ✅ Log fixed bugs in frontmatter

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified most bugs
- ✅ Food & Gas Definition Investigation (2026-08-20) — identified EU regulation bugs (now fixed)
- ✅ Food & Gas Citation Fixes (2026-08-20) — fixed EU reg, plural internal ref, pronoun ref bugs
