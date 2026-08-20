---
session: EU Regulation Annex Definition Parsing
status: closed
opened: 2026-08-20
closed: 2026-08-20
outcome: partial

summary: >
  Built parse_annex/2 to extract definitions from EU regulation annex Division elements using
  curly-quote 'Term' means patterns. 52 definitions extracted from Reg 853/2004 Annex I. Also
  fixed Directive citation extraction and parenthetical law title matching. FOOD 61.1%→87.9%
  effective resolution across the day's work. 90% target not reached — remaining gap is truncated
  Welsh SI data and substantive section parsing (#153).

decisions:
  - what: Parse annex definitions via regex on Division text, not a new XML strategy
    why: EU annex XML has no Term elements, no P2/P1, no Definition lists — just Division elements with plain text. Regex on text_content is the only viable approach.
    result: 52 definitions extracted from single annex, clean pattern match
  - what: Extended @eu_reg_short_re to also match Directive patterns
    why: (?!\/) lookahead on @law_type_year_re correctly blocks "Directive 2009/54/EC" from named law extraction, but nothing downstream handled bare Directive YYYY/NN patterns
    result: 8 more FOOD definitions moved from no_citation to citation_resolved
  - what: Added @law_type_year_paren_re for parenthetical content before year
    why: >
      Food Labelling Regulations (Northern Ireland) 1996 has parenthetical between
      title and year, breaking @law_type_year_re
    result: 2 more FOOD definitions resolved

metrics:
  diagnostic_food:
    family: "FOOD"
    cross_refs: 190
    linked: 36
    unlinked: 154
    effective_pct: 87.9
    no_citation: 23
    term_not_found: 51
    citation_ambiguous: 3
    parent_not_in_lrt: 25
    parent_revoked: 22
    internal_ref: 21
  annex_parsing:
    reg_853_2004_before: 2
    reg_853_2004_after: 54
    annex_defs_extracted: 52
  tests:
    scraper_suite: 850
    failures: 0

lessons:
  - title: "EU regulation annexes use a completely different XML structure — Division elements with plain text, no Term tags"
    detail: >
      UK legislation uses P2/P1 elements with Term tags and Definition lists. EU retained
      law uses Division elements containing numbered definitions in plain text with curly
      single quotes. None of the 3 existing parser strategies work on this structure. The
      fix is a separate parse_annex/2 entry point, not a new strategy plugged into parse/2.
    tag: data
  - title: "Fixing citation extraction can mask parser coverage problems"
    detail: >
      FOOD no_citation dropped 74→33 after EU reg extraction fix, but term_not_found rose
      from 33→69 after parsing those EU regs. The citations were extracted correctly but the
      parent laws had almost no definitions parsed. Annex parsing (52 defs) then dropped
      term_not_found to 51. Always check what happens to term_not_found after fixing
      no_citation — the problem may just shift downstream.
    tag: data
  - title: "Only Reg 853/2004 had annex definitions matching the curly-quote pattern"
    detail: >
      Checked 5 other EU regulations (178/2002, 852/2004, 617/2008, 1169/2011, 2017/625) —
      none had annexes with the 'Term' means pattern. Some had no annexes at all (404),
      others had annex content without definition patterns. The annex parser is not a
      general solution for all EU regs.
    tag: data
  - title: "Welsh SIs (UK_wsi_2014_2303) have truncated definition text — empty quotes and bare parentheses"
    detail: >
      13 of the remaining FOOD no_citation are from UK_wsi_2014_2303 with definition text
      like '("") has the meaning given in Directive'. The empty quotes suggest the term was
      stripped during parsing. Reparsing this specific law may recover the missing text.
    tag: data

bugs:
  - pattern: "EU Regulation annex definitions not parsed — terms defined in Annex I absent from parent definitions"
    category: term_not_found
    module: DefinitionParser
    affected: 0
    fix: "Added parse_annex/2 function extracting definitions from Division elements using curly-quote 'Term' means patterns. 52 defs from Reg 853/2004 Annex I."
    status: fixed
  - pattern: "Welsh SI UK_wsi_2014_2303 has truncated definition text — empty quotes and bare parentheses produce 13 no_citation"
    category: no_citation
    module: DefinitionParser
    affected: 13
    fix: "Reparse UK_wsi_2014_2303 — truncated text may be a parse artefact from bilingual XML handling"
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/test/sertantai_legal/scraper/definition_parser_test.exs
  - backend/test/sertantai_legal/scraper/root_resolver/citation_extractor_test.exs
  - backend/test/fixtures/legislation_gov_uk/annex_eur_2004_853.xml

depends_on:
  - 2026-08-20-food-gas-citation-fixes
  - 2026-08-20-definition-fixes-final-batch

enables:
  - "Substantive Section Definition Parsing (#153)"
  - "Welsh SI reparse for truncated definition text"
---

# Session: EU Regulation Annex Definition Parsing (CLOSED)

## Problem

EU Regulations define key terms in Annex I (and other annexes), not in main articles. Parser only extracts from body XML, missing annex definitions. Reg 853/2004 has 2 definitions extracted but 22 children need terms like "meat", "poultry", "fresh meat" from Annex I. See #152.

## Todo

- ✅ Fetch and examine Annex I XML structure for Reg 853/2004
- ✅ Design parser strategy — parse_annex/2 with regex on Division text (no Term/P2 elements)
- ✅ Write failing tests with annex XML fixture (7 tests)
- ✅ Implement annex definition extraction (52 defs from Reg 853/2004)
- ✅ Parse annexes for affected EU regulations (only 853/2004 had matching patterns)
- ✅ Re-resolve and verify — FOOD 82.6%→87.9% (also fixed Directive + parenthetical citations)

## Dependencies

- ✅ Food & Gas Citation Fixes (2026-08-20) — EU reg citations now extracted
- ✅ Definition Fixes Final Batch (2026-08-20) — S3 includes verb, other fixes
