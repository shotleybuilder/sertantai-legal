---
session: Definition Parser
status: pending
opened: 2026-08-13
---

# Session: Definition Parser (PENDING)

## Problem

UK legislation defines terms in "Interpretation" sections using patterns like `"workplace" means...`. We need to extract these term/definition pairs from LAT text. The legacy legl project (`shotleybuilder/legl`) had a working regex-based parser — port it to sertantai-legal with tests.

## Todo

- ⬜ Create `definition_parser.ex` in `lib/sertantai_legal/scraper/`
- ⬜ Port `filter_interpretation_sections/1` — split LAT records into interpretation vs rest
- ⬜ Port `interpretation_patterns/1` — regex patterns for single/double/triple quoted terms
- ⬜ Port `parse_interpretation_section/3` — apply patterns, extract term/definition tuples
- ⬜ Port `definition_scope/1` — detect law/part/provision scope from context phrases
- ⬜ Port cross-reference detection (`definition_references_another_law?/1`)
- ⬜ Port term/definition cleaning (strip articles, trailing punctuation, footnote markers)
- ⬜ Write unit tests with fixture LAT data from known laws (e.g. RIDDOR reg 2, Workplace Regs reg 2)
- ⬜ Test against edge cases: Welsh bilingual terms, empty definitions, amendment text exclusions

## Dependencies

- ✅ LAT data exists in `legal_articles` table (97K+ sections parsed)
- ✅ legl source available at `github.com/shotleybuilder/legl` for reference
- ⬜ No schema dependency — this session is pure parsing logic, returns structs

## Acceptance Criteria

Parser can take LAT records for a known law (e.g. UK_uksi_1999_3242 Workplace Regulations) and return a list of `{term, definition, scope, references_other_law?}` tuples matching the definitions in that law's Interpretation section.
