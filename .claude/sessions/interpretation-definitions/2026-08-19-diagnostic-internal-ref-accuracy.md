---
session: Diagnostic & Internal Ref Accuracy
status: closed
opened: 2026-08-19
closed: 2026-08-20
outcome: success

summary: >
  Fixed 3 minor citation/normalisation bugs: stray semicolons before years in definition text,
  year-prefix SI abbreviation extraction ("the 2014 Acetylene Regulations"), and hyphen
  normalisation in term matching. OH&S no_citation dropped 81→75, term_not_found 119→110.

decisions:
  - what: Scope reduced from 8 todos to 3 — original internal_ref? and Diagnostic fixes already done
    why: Batch 1 (81619cc) and stale-citation-cleanup session already addressed 5 of 8 original items
    result: "Session completed in single pass, no wasted rework"

metrics:
  diagnostic:
    family: "OH&S"
    unlinked: 241
    actionable: 213
    ceiling: 28
    term_not_found: 110
    no_citation: 75
    parent_unparsed: 24
    parent_revoked: 18
    parent_not_in_lrt: 10
    term_normalisation: 4
  resolver:
    resolved: 1844
    citation_only: 4834
    internal: 2466
    unresolved: 624
    missing_parents: 810
  tests_added: 24

lessons:
  - title: "Year-prefix citation extraction surfaces new parent_unparsed findings"
    detail: >
      Adding the year-prefix pattern ("the 2014 Acetylene Regulations") caused parent_unparsed
      to jump from 7 to 24 — the extractor now correctly identifies citations that previously
      fell through to no_citation. The 24 all point at UK_ukpga_1979_2 (Consumer Safety Act).
      New extraction patterns don't just fix existing bugs, they reveal new resolution targets.
    tag: data

bugs:
  - pattern: "SI abbreviation with year prefix not extracted — 'the 2014 Acetylene Regulations' unresolvable"
    category: no_citation
    module: CitationExtractor
    affected: 0
    fix: "Added @year_prefix_re regex and extract_year_prefix_citation/1 function"
    status: fixed
  - pattern: "Semicolon before year in citations breaks extraction — 'Regulations ;2015'"
    category: no_citation
    module: DefinitionParser (text extraction)
    affected: 0
    fix: "Added semicolon-before-year strip in clean_definition/1"
    status: fixed
  - pattern: "Hyphen inconsistency in term normalisation — 'dual-purpose vehicle' vs 'dual purpose vehicle'"
    category: term_normalisation
    module: DefinitionParser (normalise_term)
    affected: 0
    fix: "Added hyphen-to-space replacement + whitespace collapse in normalise_term/1"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser/definition.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/test/sertantai_legal/scraper/definition_parser/definition_test.exs
  - backend/test/sertantai_legal/scraper/root_resolver/citation_extractor_test.exs

depends_on:
  - 2026-08-19-ohs-resolution-audit
  - 2026-08-19-stale-citation-cleanup

enables:
  - HSWA Blob Parser Fix session (P2)
  - Section-Level Definition Extraction session (P6)
---

# Session: Diagnostic & Internal Ref Accuracy (CLOSED)

## Problem

Minor citation extraction and normalisation bugs affect ~5 definitions in OH&S and ~50 corpus-wide. The original session scope included internal_ref? and Diagnostic.classify fixes, but those were already fixed in batch 1 (81619cc) and the stale-citation-cleanup session.

## Bugs to Fix

- ✅ Semicolon before year in citations — "Regulations ;2015" (2 affected)
- ✅ SI abbreviation with year prefix — "the 2014 Acetylene Regulations" (2 affected)
- ✅ Hyphen inconsistency in term normalisation — "dual-purpose" vs "dual purpose" (1 affected)

## Todo

- ✅ Fix semicolons in definition text — `clean_definition` strips `;` before 4-digit years
- ✅ Add year-prefix SI abbreviation pattern — `@year_prefix_re` + `extract_year_prefix_citation/1`
- ✅ Normalise hyphens in `normalise_term/1` — replace `-` with space, collapse whitespace
- ✅ Add tests — 24 new tests (Definition struct + year-prefix citation)
- ✅ Re-resolve (force: true) — 1,844 resolved (+4), 2,466 internal (-43), 624 unresolved (-19)
- ✅ Re-run diagnostic — OH&S: 241 unlinked (213 actionable, 28 ceiling), term_not_found 110 (-9), no_citation 75 (-6)
- ✅ Log fixed bugs in frontmatter

## Already Fixed (from original scope)

- ✅ `internal_ref?` check in Diagnostic.classify — fixed in batch 1 (81619cc)
- ✅ `@internal_ref_re` parenthesized section numbers — fixed in batch 1 (81619cc)
- ✅ "subsection" added to regex — fixed in batch 1 (81619cc)

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the bugs
- ✅ Stale Citation Cleanup (2026-08-19) — cleared stale data, added parent_revoked
