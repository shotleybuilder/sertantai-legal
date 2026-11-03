---
session: HSWA Blob Parser Fix
status: closed
opened: 2026-08-19
closed: 2026-08-20
outcome: success

summary: >
  Fixed the HSWA blob parser bug by expanding S1 (DefinitionListStrategy) to match
  Term-bearing non-Definition UnorderedLists, and S3 to skip them. HSWA went from
  31 blob definitions (3000-6400 chars each) to 67 clean definitions. OH&S unlinked
  dropped 241→211 (-30).

decisions:
  - what: Expand S1 to match Term-bearing lists rather than creating a new S4 strategy
    why: >
      The HSWA pattern IS a definition list — structurally identical to Class="Definition"
      (ListItem + Term elements), just missing the class attribute. S1 already knows how
      to extract from ListItem+Term. Adding a new strategy would duplicate that logic.
    result: "2-line change to S1 (find non-Definition lists with Terms), 5-line change to S3 (skip them)"
  - what: TDD approach — fixture first, failing tests, then fix
    why: User requirement. Proves the fix is behaviour-preserving for existing tests while adding new coverage.
    result: "5 RED tests → all GREEN, 811 total tests pass, 0 regressions"

metrics:
  diagnostic:
    family: "OH&S"
    unlinked: 211
    actionable: 182
    ceiling: 29
    term_not_found: 100
    no_citation: 75
    parent_unparsed: 3
    parent_revoked: 18
    parent_not_in_lrt: 11
    term_normalisation: 4
  hswa_reparse:
    before_defs: 31
    after_defs: 67
    before_max_blob: 6404
    after_blobs_over_600: 2
  offshore_1996_reparse:
    defs: 21
    blobs: 0
  tests: { total: 811, new: 5, failures: 0 }

lessons:
  - title: "HSWA blob was NOT inline semicolons — it was a structured list without Class=\"Definition\""
    detail: >
      The original bug description said "inline ;-separated definitions without Definition list XML".
      Investigation revealed the XML actually has proper structure: UnorderedList Decoration="none"
      with each definition in its own ListItem with Term elements. The real issue was S1 only
      matching Class="Definition", not the missing-class variant. Always examine the XML before
      assuming the structure.
    tag: data

bugs:
  - pattern: "HSWA 1974 section 53 parsed as giant unsplit blob — each definition contains 3000-6400 chars of the whole section"
    category: term_not_found
    module: DefinitionParser
    affected: 0
    fix: "S1 expanded to match Term-bearing non-Definition lists; S3 skips them. HSWA: 31 blobs → 67 clean defs."
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/definition_parser/definition_list_strategy.ex
  - backend/lib/sertantai_legal/scraper/definition_parser/section_term_strategy.ex
  - backend/test/fixtures/legislation_gov_uk/section_ukpga_1974_37_s53.xml
  - backend/test/fixtures/legislation_gov_uk/section_uksi_1996_913_reg2.xml
  - backend/test/sertantai_legal/scraper/definition_parser_test.exs

depends_on:
  - 2026-08-19-ohs-resolution-audit
  - 2026-08-19-stale-citation-cleanup

enables:
  - Section-Level Definition Extraction session (P6)
---

# Session: HSWA Blob Parser Fix (CLOSED)

## Problem

HSWA 1974 section 53 (interpretation) is parsed as a single giant blob per definition — the "employee" entry is 4,833 chars containing the ENTIRE interpretation section from that term to the end. The parser correctly extracts each `<Term>` element but includes all subsequent text up to the section boundary. This causes: (a) 27 HSWA definitions flagged as cross-refs when they're substantive definitions, (b) citation extractor picks up wrong law references from other definitions embedded in the blob, (c) Offshore Installations Regs 1996 (UK_uksi_1996_913) has the same issue.

The root cause is that HSWA's interpretation section uses inline `;`-separated definitions without `<UnorderedList Class="Definition">` XML structure, so Strategy S1 doesn't match and S2/S3 grab the full text.

## Todo

- ✅ Examine XML — HSWA s53 uses `<UnorderedList Decoration="none">` with `<Term>` elements in `<ListItem>`, not `Class="Definition"`
- ✅ Examine XML — UK_uksi_1996_913 reg 2 uses same pattern
- ✅ Save XML fixtures for both laws
- ✅ Write failing tests (RED) — 5 tests: no blobs >600 chars, >=30 defs, employee concise, substance concise, definition_list source
- ✅ Implement fix (GREEN) — S1 expanded to match Term-bearing non-Definition lists, S3 skips them
- ✅ Reparse HSWA (67 defs, 2 >600 chars) + Offshore 1996 (21 defs, 0 blobs)
- ✅ Re-run resolver + diagnostic — OH&S: 241→211 unlinked (-30), term_not_found 110→100, parent_unparsed 24→3

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the bug
- ✅ Stale Citation Cleanup (2026-08-19) — completed before this session
