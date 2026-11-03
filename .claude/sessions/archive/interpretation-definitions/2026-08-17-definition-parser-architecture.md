---
session: Definition Parser Architecture
status: closed
opened: 2026-08-17
closed: 2026-08-17
outcome: success

summary: >
  Decomposed 766-line definition parser monolith into 6 focused modules using TDD.
  Fixed section_id bug (fingerprint-based parent lookup → P2/P1 top-down walk),
  introduced Definition struct, consolidated text extraction, and achieved Gemini
  Grade A acceptance. 58 parser tests (11 new), 1,462 full suite, 0 failures.

decisions:
  - what: TDD red/green/refactor cycle for the inversion
    why: Section_id bug was highest-value fix; writing failing tests first proved the bug existed and confirmed the fix worked
    result: 3 tests failed against fingerprint implementation, all green after inversion

  - what: Walk P2/P1 elements top-down instead of fingerprint search
    why: Fingerprint search (first 40 chars of first ListItem, Enum.find over all P2s) was O(n), non-deterministic (first match wins), and caused wrong section_ids for Definition lists in later sections
    result: Deleted 5 functions (find_section_id, find_ancestor_id, detect_scope_from_context, detect_delegated_preamble, first_item_fingerprint), -63 lines

  - what: "Definition struct with new/1 constructor"
    why: Same 10-field map constructed in 4 places with identical normalisation. Adding :source required editing all 4 — struct centralises construction and prevents field-addition bugs
    result: "Single Definition.new/1 with @enforce_keys, 4 call sites simplified to keyword-list construction"

  - what: Consolidate on text_content/1 (renamed xmerl_text)
    why: Two text extraction approaches (xpath-based extract_plain_text with known Term reordering bugs vs xmerl_text tree walk that was always correct). Dual approaches were a foot-gun for future maintainers
    result: Deleted extract_plain_text, extract_text_with_abbreviations, interleave_text_parts. Surfaced a new bug — S2 needed to skip <Term> elements (S3 territory) now that text_content produced cleaner text

  - what: Keep _is_welsh param in S3 extract/3 despite being unused
    why: Uniform extract/3 interface across all strategies matters more than removing one unused param. Breaking interface consistency for a cosmetic change is net negative
    result: Declined Gemini suggestion, kept _is_welsh prefixed with underscore

  - what: XmlUtils.section_elements/1 shared helper
    why: All 3 strategies repeated the same P2/P1 iteration with P2-child rejection on P1. Gemini flagged the duplication
    result: Single helper returning {p2s, p1s} tuple, used by all 3 strategy extract/3 functions

metrics:
  parser_lines: { before: 766, after_inversion: 703, after_struct: 642, after_text: 573, final_orchestrator: 67 }
  module_count: { total: 6, largest: 177, smallest: 67 }
  tests: { parser: 58, new: 11, full_suite: 1462, failures: 0 }
  functions_deleted: { fingerprint: 5, text_extraction: 3, dedup_map_sites: 4 }
  gemini_reviews: { count: 2, inversion_endorsed: true, final_grade: "A" }

lessons:
  - title: text_content consolidation surfaces hidden strategy overlaps
    detail: >
      Replacing extract_plain_text (xpath-based) with text_content (tree walk)
      changed the text output for S2's inline scan. The cleaner document-order text
      from text_content matched the inline_def_pattern on elements containing <Term>
      elements — which should be S3's territory. Fix: S2 now skips elements with
      <Term> (same skip guard pattern as Definition lists). Consolidating to one
      text extraction approach is correct, but test immediately — the behavioural
      change in text output can cause strategy boundary violations.
    tag: data

  - title: TDD red phase proves the bug before you fix it
    detail: >
      Writing the section_id test first (waste defined in both reg-2-1 and reg-67-4)
      produced exactly the expected failure: "Expected 2 'waste' definitions, got 1:
      ['regulation-2-1']". The second waste definition got wrong section_id, dedup
      merged them, and one was silently lost. Seeing the failure message confirmed
      the root cause before writing any fix code.
    tag: tooling

  - title: Uniform strategy interface enables clean orchestration
    detail: >
      All 3 strategies export extract/3 with identical signature (parsed, law_name, is_welsh).
      The orchestrator is 67 lines — just parse XML, call all three, deduplicate.
      When Gemini suggested removing _is_welsh from S3 (unused), we declined because
      breaking interface uniformity costs more than an unused parameter.
    tag: tooling

  - title: S2 unconditional P1 scan needs P2-child rejection
    detail: >
      Removing the if p2_results != [] guard from S2 (to match the "run unconditionally"
      principle) caused double-counting. P1 elements containing P2 children were scanned
      by both the P2 pass and the P1 pass, producing duplicates with different section_ids
      (P2's @id vs P1's @id). Fix: same P2-child rejection used by S1 and S3 — now
      centralised in XmlUtils.section_elements/1.
    tag: data

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/definition.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/xml_utils.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/definition_list_strategy.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/inline_text_strategy.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/section_term_strategy.ex
  - backend/lib/sertantai_legal/scraper/definition_persister.ex
  - backend/test/sertantai_legal/scraper/definition_parser_test.exs
  - backend/data/code-reviews/2026-08-17-definition-parser-inversion.md
  - backend/data/code-reviews/2026-08-17-definition-parser-final-acceptance.md

depends_on:
  - interpretation-definitions/2026-08-16-definition-parser-refactor

enables:
  - Re-parse all laws to fix stale section_ids from fingerprint era
  - Definition links junction table ElectricSQL shape (from backfill session)
  - Investigate 1,086 empty-definition parser records across 89 laws
---

# Session: Definition Parser Architecture (CLOSED)

## Problem

The definition parser (`definition_parser.ex`, 766 lines) works correctly for the common case but has a known section_id bug caused by fingerprint-based parent lookup, duplicated map construction across 4 call sites, dual text-extraction approaches with different correctness properties, and all logic in a single module. An architectural review (2026-08-17) and Gemini external review both recommend the same set of structural improvements.

The section_id bug: Definition lists outside regulation-2 (e.g. regulation-67-4 in Environmental Permitting Regs) get the wrong section_id because `find_section_id` uses `Enum.find` with text containment over all P2 elements — first match wins, not closest ancestor.

## Todo

- ✅ TDD Red: 3 failing tests for section_id bug (waste in reg-2-1 + reg-67-4, dedup loses second def)
- ✅ TDD Green-from-start: Definition list in P3 under P2 (passes, confirms inversion safety)
- ✅ TDD Green-from-start: Structural invariant tests on both fixtures (Workplace Regs + RIDDOR)
- ✅ TDD Green-from-start: Malformed XML edge cases (no Body, empty Body, no definitions)
- ✅ Invert S1: walk P2/P1 top-down, eliminate 5 fingerprint functions (766→703 lines), 3 failing tests now green
- ✅ Extract `Definition` struct with `new/1` constructor, replace 4 map construction sites (parser 703→642 lines)
- ✅ Consolidate text extraction on `text_content/1` + `xpath_list/2` helper (642→573 lines, deleted 3 functions)
- ✅ S2 now skips elements with `<Term>` elements (S3 territory) — caught by text_content behavioural change
- ✅ Module decomposition: 6 modules, largest 177 lines, orchestrator 67 lines, @spec on all public functions
- ✅ Remove S2 internal P2→P1 conditional — scan both unconditionally with P2-child rejection on P1
- ✅ Add `:debug` logging for regex compile failures in `extract_definition_after_term`
- ✅ `@spec` on all public and private functions across all 6 modules
- ✅ Final test pass — 1,462 tests, 0 failures
- ✅ Gemini final acceptance review — Grade A, production-ready

### Gemini suggestions (non-blocking)

- ✅ `term_welsh` now uses `normalise_term/1` (strips quotes, articles) instead of just `downcase`
- ✅ Tightened `context` spec on `parse/2` to `%{:law_name => String.t(), optional(:type_code) => String.t()}`
- ✅ Strategy specs use `Definition.scope()` instead of `atom()` (3 call sites)
- ❌ Remove `_is_welsh` from S3 — kept for uniform `extract/3` interface across all strategies
- ✅ Extracted `XmlUtils.section_elements/1` — returns `{p2s, p1s}` with P2-child rejection, used by all 3 strategies

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
