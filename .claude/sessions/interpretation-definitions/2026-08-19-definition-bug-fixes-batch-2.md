---
session: Definition Bug Fixes Batch 2
status: closed
opened: 2026-08-19
closed: 2026-08-19
outcome: success

summary: >
  Fixed 3 title normalisation bugs in the CitationExtractor pipeline, moving 43 items
  out of parent_not_in_lrt into more refined diagnostic categories. Investigated the
  500-estimate TCPA abbreviation bug, found actual count is 28, and raised as #147.

decisions:
  - what: Strip 'means' prefix in build_citation_index rather than in extract_citation consumer
    why: The citation_index maps short names to full law titles — 'means the Scotland Act 1998' is not a law title. Fixing at the source ensures all consumers benefit.
    result: 504 citation_index entries cleaned, 14 definitions with stored 'means' prefix now resolvable

  - what: Add (c. N) chapter number strip to normalise_title rather than resolve_law_name
    why: Chapter numbers like '(c. 29)' are metadata appended to citations in legislation text. normalise_title is the single point where both title_index keys and citation lookups are normalised, so fixing here ensures consistency on both sides.
    result: 26 definitions with chapter number suffixes now match title_index

  - what: Expand (NI) to (Northern Ireland) in normalise_title with space-preceded lookbehind
    why: NI Orders are cited with abbreviated '(NI)' but LRT stores '(Northern Ireland)'. Lookbehind (?<=\s) prevents expanding UK(NI) which is a separate token.
    result: 2 Fire and Rescue Services (NI) Order citations now resolve

  - what: Raised TCPA abbreviation bug as GitHub issue #147 instead of fixing in-session
    why: Investigation showed actual affected count is 28 (not 500). The abbreviations are never defined as citation=true entries, so no citation_index lookup is possible. Fix requires a new feature (initials matching or static map), not a bug fix in existing code.
    result: Issue #147 created with full research, 3 solution approaches documented

metrics:
  tests: { total: 1512, passed: 1512, failed: 0 }
  diagnostic_delta: { parent_not_in_lrt: -43, parent_unparsed: +22, citation_ambiguous: +17, term_not_found: +4, no_citation: 0, term_normalisation: 0 }
  bugs_fixed: 3
  bugs_recharacterised: 1

lessons:
  - title: Bug affected counts from discovery sessions can be wildly inaccurate — verify before committing to a fix
    detail: >
      The TCPA abbreviation bug was estimated at 500 affected during the diagnostic
      session. Detailed investigation showed only 28 definitions match the pattern,
      and the fix requires a feature (abbreviation expansion) not a code change.
      Always run targeted SQL counts before scoping a fix session.
    tag: tooling

  - title: citation_index stores raw definition text including preamble — any cleanup must happen at index build time
    detail: >
      build_citation_index does String.trim(definition) on citation=true entries.
      504 of these start with 'means' which pollutes all downstream consumers.
      Cleaning at the source (index builder) is better than cleaning at each
      consumer, because the index is consumed in multiple places.
    tag: data

  - title: normalise_title abbreviation expansion needs word-boundary awareness
    detail: >
      Naive replacement of (NI) with (Northern Ireland) breaks UK(NI) which becomes
      'uknorthern ireland'. A lookbehind (?<=\s) ensures only space-preceded (NI)
      is expanded. Test with compound tokens like UK(NI) before committing.
    tag: data

bugs:
  - pattern: Citation 'means' prefix captured in citation_index — 504 entries polluted
    category: parent_not_in_lrt
    module: Indexes (build_citation_index)
    affected: 14
    fix: Strip 'means' prefix in build_citation_index + diagnostic resolve_law_name
    status: fixed

  - pattern: Chapter number suffix '(c. N)' in citations pollutes title_index lookup
    category: parent_not_in_lrt
    module: CitationExtractor (normalise_title)
    affected: 26
    fix: Strip (c. N) pattern in normalise_title before punctuation removal
    status: fixed

  - pattern: (NI) abbreviation in citations does not match (Northern Ireland) in title_index
    category: parent_not_in_lrt
    module: CitationExtractor (normalise_title)
    affected: 2
    fix: Expand (NI) to (Northern Ireland) in normalise_title with lookbehind
    status: fixed

  - pattern: Abbreviation-style law references (TCPA 1990, EA 1989) unresolvable — not in citation_index
    category: no_citation
    module: CitationExtractor
    affected: 28
    fix: Needs feature — initials matching against title_index or static abbreviation map. Raised as #147.
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/indexes.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex

depends_on:
  - interpretation-definitions/2026-08-19-definition-bug-fixes-batch-1

enables:
  - Definition Bug Fixes Batch 3 (HSWA etc., Scottish asp suffix — remaining normalisation bugs)
  - GitHub issue #147 (abbreviation-style citation feature)
---

# Session: Definition Bug Fixes Batch 2 (CLOSED)

## Problem

18 open definition bugs remain after batch 1. This session targets bugs in the CitationExtractor / title normalisation pipeline — all relate to citations being extracted but failing to match against the title_index.

## Todo

- ✅ Fix citation 'means' prefix capture (14 affected) — strip 'means' in build_citation_index + diagnostic resolve
- ✅ Fix chapter number '(c. N)' suffix polluting title lookup (26 affected) — strip in normalise_title
- ❌ Short-name citations 'TCPA 1990' (estimated 500, actual 28) — raised as #147, needs feature not bug fix
- ✅ Fix '(NI)' abbreviation not matching '(Northern Ireland)' in title_index (2 affected, was estimated 16) — swapped in from batch 3
- ✅ Run tests — 1,512 pass, 0 failures
- ✅ Re-run diagnostic — parent_not_in_lrt: -43, redistributed to parent_unparsed (+22), citation_ambiguous (+17), term_not_found (+4)

## Dependencies

- ✅ Definition Bug Fixes Batch 1 (2026-08-19) — top 3 bugs fixed
- ✅ Fire Domain Definition QA (2026-08-18)
- ✅ Transport Safety Definition QA (2026-08-18)
- ✅ Public & Consumer Safety Definition QA (2026-08-18)
- ✅ Mining, Offshore & Health Definition QA (2026-08-19)
