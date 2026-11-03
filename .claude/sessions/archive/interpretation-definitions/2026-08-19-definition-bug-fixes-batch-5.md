---
session: Definition Bug Fixes Batch 5
status: closed
opened: 2026-08-19
closed: 2026-08-19
outcome: success

summary: >
  Fixed 2 citation extraction bugs — EU article-reference mangling (9 affected) and
  preamble strip too aggressive for long compound titles (2 affected). Two remaining
  bugs (consolidated act, FRS abbreviation) skipped as too small or already covered by #147.

decisions:
  - what: Reject extract_named_law matches starting with Article rather than stripping the prefix
    why: Article is not a law type keyword — any regex match starting with it is always an EU article reference misidentified as a UK law title. Rejecting lets extract_eu_law_name handle it correctly via the fallback path.
    result: 9 EU regulation citations now fall through to extract_eu_law_name

  - what: Add YYYY/NNN EU regulation format alongside existing NNN/YYYY
    why: EU citations use both formats — Regulation 2016/424/EU (year first) and Regulation No 1122/2009 (number first). The year-first format requires anchoring on 19xx/20xx to avoid ambiguity.
    result: Both formats now resolve to UK_eur_YYYY_NNN law names

  - what: Increase law_type_year_re capture limit from 80 to 120 chars
    why: Compound titles like Health and Safety (Enforcing Authority for Railways and Other Guided Transport Systems) Regulations are 88 chars — just over 80. The regex starts at Safety instead of Health, losing the prefix.
    result: Full compound titles up to 120 chars captured correctly

  - what: Skip consolidated Act mismatch and FRS abbreviation
    why: Consolidated Act needs a successor mapping mechanism (2 affected, overengineered). FRS is the same abbreviation class as #147 (2 affected, already tracked).
    result: 4 definitions remain unresolved, documented as known limitations

metrics:
  tests: { total: 1512, passed: 1512, failed: 0 }
  diagnostic_delta: { parent_not_in_lrt: -1, parent_unparsed: +1 }
  bugs_fixed: 2
  bugs_skipped: 2

lessons:
  - title: EU regulation citation formats are year/number OR number/year — must handle both with year-range anchoring
    detail: >
      Regulation 2016/424/EU has year first (YYYY/NNN), Regulation No 1122/2009 has
      number first (NNN/YYYY). Distinguishing them requires anchoring the year group
      on 19xx/20xx range. Without this, 1122 gets misidentified as a year.
    tag: data

bugs:
  - pattern: EU citation mangling — extract_named_law captures Article ref as law title
    category: parent_not_in_lrt
    module: CitationExtractor (extract_named_law)
    affected: 9
    fix: Reject matches starting with Article + add YYYY/NNN EU format to extract_eu_law_name
    status: fixed

  - pattern: extract_named_law 80-char limit truncates compound titles
    category: parent_not_in_lrt
    module: CitationExtractor (law_type_year_re)
    affected: 2
    fix: Increased limit from 80 to 120 chars
    status: fixed

  - pattern: Consolidated Act mismatch — 1974 Act not mapped to 1992 Consolidation Act
    category: parent_not_in_lrt
    module: Indexes
    affected: 2
    fix: Needs successor law mapping mechanism
    status: open

  - pattern: FRS abbreviation unresolvable — same class as TCPA abbreviation bug
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 2
    fix: Covered by #147
    status: open

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/citation_extractor.ex

depends_on:
  - interpretation-definitions/2026-08-19-definition-bug-fixes-batch-4

enables:
  - Resolver re-run to link EU regulation citations with corrected law names
---

# Session: Definition Bug Fixes Batch 5 (CLOSED)

## Problem

Citation edge cases — small CitationExtractor fixes for mangled EU citations, aggressive preamble stripping, consolidated act mismatches, and unresolvable abbreviations. Total: ~15 affected definitions.

## Todo

- ✅ Fix mangled EU citation — reject "Article" prefix in extract_named_law + add YYYY/NNN EU regulation format
- ✅ Fix extract_named_law preamble strip — increased regex limit from 80 to 120 chars for compound titles
- ❌ Consolidated Act mismatch (2 affected) — needs successor mapping mechanism, not worth for 2 rows
- ❌ FRS abbreviation (2 affected) — same class as #147 (abbreviation-style refs)
- ✅ Run tests — 1,512 pass, 0 failures
- ✅ Re-run diagnostic — parent_not_in_lrt: -1 (preamble fix), EU fix needs resolver re-run

## Dependencies

- ✅ Definition Bug Fixes Batch 4 (2026-08-19)
