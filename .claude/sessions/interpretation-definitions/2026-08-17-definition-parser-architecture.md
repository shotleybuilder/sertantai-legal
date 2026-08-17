---
session: Definition Parser Architecture
status: pending
opened: 2026-08-17
depends_on:
  - interpretation-definitions/2026-08-16-definition-parser-refactor
---

# Session: Definition Parser Architecture (PENDING)

## Problem

The definition parser (`definition_parser.ex`, 766 lines) works correctly for the common case but has a known section_id bug caused by fingerprint-based parent lookup, duplicated map construction across 4 call sites, dual text-extraction approaches with different correctness properties, and all logic in a single module. An architectural review (2026-08-17) and Gemini external review both recommend the same set of structural improvements.

The section_id bug: Definition lists outside regulation-2 (e.g. regulation-67-4 in Environmental Permitting Regs) get the wrong section_id because `find_section_id` uses `Enum.find` with text containment over all P2 elements — first match wins, not closest ancestor.

## Todo

- ⬜ TDD: Write failing tests for section_id bug (multiple Definition lists at different sections)
- ⬜ TDD: Write failing test for Definition list in P3/P4 nested under P2
- ⬜ TDD: Write structural invariant test (non-nil term, law_name matches, source atom, section_id type)
- ⬜ TDD: Write malformed XML edge case tests (truncated XML, missing Body, encoding errors)
- ⬜ Invert S1: walk P2/P1 top-down, eliminate fingerprint functions — make failing tests green
- ⬜ Extract `Definition` struct with `new/1` constructor, replace 4 map construction sites
- ⬜ Consolidate text extraction: replace `extract_plain_text` and `extract_text_with_abbreviations` with `text_content/1` (renamed `xmerl_text`)
- ⬜ Extract `xpath_list/2` and `xpath_string/2` helpers, replace ~10 nil-guard sites
- ⬜ Module decomposition: orchestrator + strategy modules + XmlUtils + Definition struct
- ⬜ Add `@spec` to all public and private functions
- ⬜ Remove S2 internal P2→P1 conditional, scan both unconditionally
- ⬜ Add `:debug` logging for runtime regex compile failures in `extract_definition_after_term`
- ⬜ Final test pass + Gemini review of completed refactor

## Dependencies

- ✅ Definition Parser Refactor session — `:source` provenance, unconditional strategies, single `deduplicate/1`
- ✅ Gemini review endorsing inversion approach (`backend/data/code-reviews/2026-08-17-definition-parser-inversion.md`)

## Approach: TDD for the inversion

The section_id bug is the highest-value fix. TDD approach:

**Red phase** — write tests that fail against the current fingerprint-based implementation:

1. **Same term in two sections**: XML with "emission" defined in both regulation-2-1 (Definition list) and regulation-67-4 (Definition list). Assert both get correct section_ids. Current code gives regulation-67-4's definitions `section_id: "regulation-2-1"` (wrong).

2. **Definition list nested in P3 under P2**: XML where a Definition list sits inside a P3 element under a P2. Assert section_id is the P2's id. Current fingerprint search may find the wrong P2.

3. **Definition list at P1 level (no P2 wrapper)**: XML with Definition list directly in P1para (EU directive pattern). Assert section_id is the P1's id.

4. **Multiple Definition lists in same P2**: Two Definition lists under one P2 (different preambles). Assert both get that P2's section_id.

**Green phase** — implement the inversion:

Replace `parse_definition_lists` to iterate P2/P1 elements top-down, check each for child `//UnorderedList[@Class='Definition']`, extract with the element's known `@id`. Delete `find_section_id`, `find_ancestor_id`, `detect_scope_from_context`, `detect_delegated_preamble`, `first_item_fingerprint`.

**Refactor phase** — structural improvements (struct, text consolidation, module decomposition) while keeping all tests green.

## Target module structure

```
lib/sertantai_legal/scraper/
├── definition_parser.ex              # Orchestrator: parse/2, deduplicate/1
├── definition_parser/
│   ├── definition.ex                 # %Definition{} struct + new/1 constructor
│   ├── xml_utils.ex                  # text_content/1, xpath_list/2, xpath_string/2
│   ├── definition_list_strategy.ex   # S1: structured Class="Definition" lists
│   ├── inline_text_strategy.ex       # S2: regex scan for "term" means...
│   └── section_term_strategy.ex      # S3: <Term> in running P2/P1 text
└── definition_persister.ex           # Unchanged (already clean)
```

Each strategy module exports a single `extract/3` function taking `(parsed_xml, law_name, is_welsh)` and returning `[%Definition{}]`. The orchestrator calls all three and deduplicates.
