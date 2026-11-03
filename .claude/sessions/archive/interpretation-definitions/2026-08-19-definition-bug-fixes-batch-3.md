---
session: Definition Bug Fixes Batch 3
status: closed
opened: 2026-08-19
closed: 2026-08-19
outcome: success

summary: >
  Fixed 2 remaining title normalisation bugs — 'etc.' alias registration in title_index
  and Scottish (asp N) suffix stripping. Moved 9 items out of parent_not_in_lrt.
  Combined with batches 1 and 2, parent_not_in_lrt has dropped from 1,368 to 1,202 (-166).

decisions:
  - what: Register alias keys without 'etc' in build_title_index rather than stripping 'etc' in normalise_title
    why: 563 laws have 'etc.' in their title. Stripping from normalise_title would change all their keys and risk false matches. Adding alias entries is additive — existing lookups unchanged, new lookups also work.
    result: Both "health and safety at work etc act" and "health and safety at work act" resolve to UK_ukpga_1974_37

  - what: Combine (asp N) strip with existing (c. N) strip in a single regex
    why: Both are legislative numbering suffixes — chapter numbers for UK Parliament Acts, asp numbers for Scottish Acts. Same pattern, same fix location in normalise_title.
    result: Single regex handles both patterns

metrics:
  tests: { total: 1512, passed: 1512, failed: 0 }
  diagnostic_delta: { parent_not_in_lrt: -9, parent_unparsed: +6, term_not_found: +3, no_citation: 0, term_normalisation: 0, citation_ambiguous: 0 }
  cumulative_parent_not_in_lrt_reduction: { baseline: 1368, current: 1202, delta: -166, batches: 3 }
  bugs_fixed: 2

lessons:
  - title: Title alias registration is safer than normalisation changes for optional title components
    detail: >
      'etc.' appears in 563 law titles. Stripping it from normalise_title would change
      the canonical key for all of them and risk collisions with laws whose titles
      differ only by 'etc.'. Adding alias keys is additive — the primary key stays
      unchanged, and the alias provides a fallback path. Use this pattern for any
      optional title component (abbreviations, honorifics, etc.).
    tag: data

bugs:
  - pattern: HSWA cited without 'etc.' — title_index only has key with 'etc'
    category: parent_not_in_lrt
    module: Indexes (build_title_index)
    affected: 3
    fix: Register alias keys without 'etc' in build_title_index for all 563 affected laws
    status: fixed

  - pattern: Scottish (asp N) suffix in citations pollutes title_index lookup key
    category: parent_not_in_lrt
    module: CitationExtractor (normalise_title)
    affected: 6
    fix: Combined with (c. N) strip regex in normalise_title
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/indexes.ex
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex

depends_on:
  - interpretation-definitions/2026-08-19-definition-bug-fixes-batch-2

enables:
  - Further bug fix batches targeting remaining open bugs (concatenated terms, bare Act refs, definition list bleed)
---

# Session: Definition Bug Fixes Batch 3 (CLOSED)

## Problem

Remaining title normalisation bugs in the CitationExtractor pipeline. Small fixes where citation text doesn't match the title_index due to naming conventions. Total: ~25 affected definitions.

## Todo

- ✅ Fix 'etc.' alias in title_index — register keys with and without 'etc' for all 563 affected laws (HSWA ~3 directly affected)
- ✅ Fix Scottish '(asp N)' suffix polluting title lookup key (6 affected) — combined with (c. N) regex
- ✅ Run tests — 1,512 pass, 0 failures
- ✅ Re-run diagnostic — parent_not_in_lrt: -9, redistributed to parent_unparsed (+6), term_not_found (+3)

## Dependencies

- ✅ Definition Bug Fixes Batch 2 (2026-08-19) — (NI) fix pulled into batch 2
