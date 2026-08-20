---
session: Stale Citation Cleanup & Parent Reparse
status: closed
opened: 2026-08-19
closed: 2026-08-20
outcome: success

summary: >
  Cleared 6,945 stale referenced_law_citation values and 319 wrongly-flagged references_other_law entries.
  Reparsed Roads (NI) Order 1993 (29 defs extracted). Added parent_revoked category to Diagnostic
  separating 32 ceiling items from 211 actionable findings. OH&S resolution baseline corrected from
  inflated 52.8% to accurate 36.2%.

decisions:
  - what: Clear ALL referenced_law_citation values rather than selectively filtering
    why: >
      70% had law name absent from definition text, but many valid citations stored in different
      word order. Selective filtering too error-prone (multi-year citations, abbreviated refs).
      Resolver re-populates correct ones on next run.
    result: "6,945 rows cleared, resolver re-populated correctly on re-run"
  - what: Use existing live column as repealed interpretation signal instead of adding new column
    why: >
      6/9 zero-def parent laws are fully revoked (live=❌). The live column already captures
      this — no schema change needed. User pointed this out after initial proposal to add a new column.
    result: "No migration needed, diagnostic now filters by live status"
  - what: Continental Shelf Act 1964 is session #4 scope, not a reparse problem
    why: >
      Children reference s1(7) substantive definitions, not interpretation section. Parser correctly
      found the 1 definition in s11A. Section-level definition extraction is a separate architectural task.
    result: "Deferred to Section-Level Definition Extraction session"

metrics:
  stale_data_cleanup:
    referenced_law_citation_cleared: 6945
    references_other_law_cleared: 319
    cross_refs_cleared: 231
    citations_cleared: 88
  zero_def_parents:
    total: 9
    revoked: 6
    no_interp: 2
    reparseable: 1
    defs_extracted: 29
  resolver:
    resolved: 1840
    citation_only: 4776
    internal: 2509
    unresolved: 643
    missing_parents: 815
  diagnostic:
    family: "OH&S"
    cross_refs: 381
    linked: 138
    unlinked: 243
    actionable: 211
    ceiling: 32
    term_not_found: 119
    no_citation: 81
    parent_unparsed: 7
    parent_revoked: 23
    parent_not_in_lrt: 9
    term_normalisation: 4

lessons:
  - title: "Previous 52.8% resolution rate was inflated by stale data"
    detail: >
      144 OH&S definitions were wrongly flagged as cross-refs, 139 of which had phantom links
      from stale referenced_law_citation values. The real baseline is 36.2%. Always clear stale
      cached fields before measuring resolution quality.
    tag: data
  - title: "live column on legal_register is the signal for repealed interpretation sections"
    detail: >
      Don't check XML for zero-def parent laws — check live status first. If live=❌ (revoked),
      the interpretation section is gone and there's nothing to extract. Saves investigation time
      every session.
    tag: data
  - title: "Diagnostic must separate actionable from ceiling categories"
    detail: >
      parent_revoked and parent_not_in_lrt are structural ceiling, not bugs to fix.
      Reporting them alongside actionable findings wastes investigation time every session.
      Added parent_revoked category and ceiling/actionable split to print_summary.
    tag: tooling

bugs:
  - pattern: "referenced_law_citation populated from amendment annotations, not definition text — 80% wrong corpus-wide"
    category: term_not_found / systemic
    module: RootResolver Persister + Diagnostic
    affected: 0
    fix: "Cleared all 6,945 values to NULL. Resolver re-populates from text."
    status: fixed
  - pattern: "internal_ref? misses 'has the meaning given/assigned in regulation/section N' pattern — only catches 'given by'"
    category: no_citation
    module: DefinitionParser (Definition struct / internal_ref?)
    affected: 0
    fix: "Fixed in batch 1 (81619cc) — added @internal_ref_has_meaning_re pattern"
    status: fixed
  - pattern: "Short-name citations like 'TCPA 1990' not extracted — abbreviation not in citation_index"
    category: no_citation
    module: CitationExtractor
    affected: 0
    fix: "Fixed via #147 (72ebde5) — statute abbreviation extraction"
    status: fixed
  - pattern: "Definition list items bleed into each other — lettered sub-items (;b\", ;c\") not split"
    category: term_not_found
    module: DefinitionParser (definition_list_strategy)
    affected: 0
    fix: "Fixed via #148 (aae573c) — exclude nested Definition list text"
    status: fixed
  - pattern: "Bare 'the Act' references in SIs — 'given by section N of the Act' without naming which Act"
    category: no_citation
    module: CitationExtractor / Matcher
    affected: 0
    fix: "Fixed via #150 (c190778) — resolve via enacted_by parent"
    status: fixed
  - pattern: "Diagnostic doesn't check internal_ref? — inflates no_citation by 53 for OH&S alone"
    category: no_citation (misclassified)
    module: Diagnostic
    affected: 0
    fix: "Fixed in batch 1 (81619cc) — Diagnostic.classify checks internal_ref?"
    status: fixed
  - pattern: "Abbreviation-style law references (TCPA 1990, EA 1989) unresolvable — not in citation_index"
    category: no_citation
    module: CitationExtractor
    affected: 0
    fix: "Fixed via #147 (72ebde5) — statute abbreviation extraction"
    status: fixed
  - pattern: "Chapter number suffix '(c. N)' in citations pollutes title_index lookup — normalise_title keeps 'c N' in string"
    category: parent_not_in_lrt
    module: CitationExtractor / normalise_title
    affected: 0
    fix: "Fixed in batch 2 (7215d33) — strip (c. N) in normalise_title"
    status: fixed
  - pattern: "Apostrophe inconsistently stripped in term normalisation — both 'public body''s' and 'public bodys' exist as terms"
    category: term_normalisation
    module: DefinitionParser (Definition struct / normalise_term)
    affected: 0
    fix: "Fixed in batch 4 — data cleanup (37 duplicates deleted, 52 terms normalised)"
    status: fixed
  - pattern: "HSWA cited as 'Health and Safety at Work Act 1974' without 'etc.' — title_index misses it"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Fixed in batch 3 (fe7aee3) — etc. alias registration in title_index"
    status: fixed
  - pattern: "Title-stripping regex triggers on bare citations too — 'Road Traffic Regulation Act 1984' → 'Road Traffic' even without trailing section ref"
    category: parent_not_in_lrt
    module: resolve_law_name
    affected: 0
    fix: "Fixed in batch 1 (81619cc) — regex changed from .+ to \\d.* after keyword"
    status: fixed
  - pattern: "'(NI)' abbreviation in citations doesn't match '(Northern Ireland)' in title_index"
    category: parent_not_in_lrt
    module: Indexes / normalise_title
    affected: 0
    fix: "Fixed in batch 2 (7215d33) — expand (NI) to (Northern Ireland)"
    status: fixed
  - pattern: "Citation 'means' prefix captured — 'means the Fire and Rescue Services...' instead of 'the Fire and Rescue Services...'"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Fixed in batch 2 (7215d33) — strip means prefix in build_citation_index"
    status: fixed
  - pattern: "9 parent laws parsed with 0 definitions — parser silent failure or no interpretation section"
    category: term_not_found
    module: DefinitionParser
    affected: 0
    fix: "Investigated: 6/9 revoked, 2 no interp, 1 reparsed (Roads NI → 29 defs)"
    status: fixed
  - pattern: "Mangled EU citation 'Article 3(x) of Regulation 2016' — extractor captures article ref as law title"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Fixed in batch 5 (002291a) — EU citation extraction fix"
    status: fixed
  - pattern: "Scottish '(asp N)' suffix in citations pollutes title_index lookup key"
    category: parent_not_in_lrt
    module: CitationExtractor / resolve_law_name
    affected: 0
    fix: "Fixed in batch 3 (fe7aee3) — strip (asp N) in normalise_title"
    status: fixed
  - pattern: "internal_ref? regex misses paragraph/subsection with parenthesized numbers — 'paragraph (5)' not matched"
    category: no_citation
    module: CitationExtractor (internal_ref?)
    affected: 0
    fix: "Fixed in batch 1 (81619cc) — @internal_ref_has_meaning_re covers parenthesized numbers"
    status: fixed
  - pattern: "extract_named_law strips preamble too aggressively — 'Safety (Enforcing Authority...)' loses 'Health and'"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 0
    fix: "Fixed in batch 5 (002291a) — increased regex limit from 80 to 120 chars"
    status: fixed
  - pattern: "Laws parsed with 0 definitions — silent parser failure (Companies Act 2006, Product Safety Metrology Regs 2020)"
    category: term_not_found
    module: DefinitionParser
    affected: 0
    fix: "Companies Act reparsed (520 defs). Product Safety is genuinely 0 (amendment reg)."
    status: fixed
  - pattern: "Parser concatenates adjacent '\"X\" and \"Y\"' terms into single term (e.g. 'workat work', 'chief constableconstable')"
    category: term_normalisation
    module: DefinitionParser (definition_list_strategy or inline_text_strategy)
    affected: 0
    fix: "Data cleaned via #151 (90bd3b4). Parser fix still pending for new parses."
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex
  - backend/test/sertantai_legal/scraper/root_resolver/diagnostic_test.exs
  - .claude/skills/definition-parse/SKILL.md
  - .claude/skills/definition-resolve/SKILL.md
  - .claude/skills/definition-diagnose/SKILL.md
  - .claude/skills/definition-bugs/SKILL.md
  - .claude/skills/definition-qa/SKILL.md
  - .claude/commands/session-definition-bugfind-start.md
  - .claude/commands/session-definition-bugfix-start.md

depends_on:
  - 2026-08-19-ohs-resolution-audit

enables:
  - Diagnostic & Internal Ref Accuracy session (P1+P5+P7)
  - HSWA Blob Parser Fix session (P2)
  - Section-Level Definition Extraction session (P6)
  - All future definition QA sessions via the new skill system
---

# Session: Stale Citation Cleanup & Parent Reparse (CLOSED)

## Problem

`referenced_law_citation` is wrong for 80% of entries corpus-wide (4,018 of 5,000 sampled). The root_resolver persister writes amending Act citations from previous runs, which poison subsequent resolver and diagnostic runs. Additionally, 9 parent laws parsed with 0 definitions and the Continental Shelf Act 1964 has only 1 definition despite 14 children referencing it. Clearing stale data and reparsing parents is the highest-impact, lowest-effort fix.

## Todo

- ✅ Clear all `referenced_law_citation` values — set NULL on 6,945 rows (82,034 now all NULL)
- ✅ Clear `references_other_law` on 319 defs that don't match current patterns (231 cross-refs, 88 citations)
- ✅ Check XML structure for 9 zero-def parent laws — 6 revoked (live=❌), 2 no interp, 1 reparseable (Roads NI)
- ✅ Repealed interp signal: `live` column on legal_register already provides this — no new column needed
- ✅ Reparse Roads (NI) Order 1993 — 29 definitions extracted and upserted
- ✅ Continental Shelf Act 1964 — 1 def is correct (s11A "installation"); 14 children reference s1(7) substantive defs → session #4 scope
- ✅ Re-run resolver (force: true) — 1,840 resolved, 4,776 citation_only, 2,509 internal, 643 unresolved
- ✅ Run diagnostic — OH&S: 381 cross-refs, 138 linked (36.2%), 243 unlinked (211 actionable, 32 ceiling)
- ✅ Add `parent_revoked` category to Diagnostic — separates revoked parents from actionable findings
- ✅ Diagnostic test suite — 30 tests covering all categories, fuzzy matching, summarise, print_summary

### Zero-def parent laws (OH&S)

- UK_nisi_1984_1821 (Fire Services NI Order 1984) — 1 child
- UK_nisi_1991_762 (Food Safety NI Order 1991) — 1 child
- UK_nisi_1993_3160 (Roads NI Order 1993) — 1 child
- UK_ukpga_1894_60 (Merchant Shipping Act 1894) — 1 child
- UK_ukpga_1971_40 (Fire Precautions Act 1971) — 1 child
- UK_ukpga_1997_24 — 1 child
- UK_uksi_1997_831 — 1 child
- UK_uksi_2009_716 — 2 children
- UK_uksi_2020_1460 — 3 children

## Results

Previous baseline was inflated by stale data: 144 OH&S definitions were wrongly flagged as cross-refs, 139 of which had phantom links from stale `referenced_law_citation` values.

| Metric | Before | After | Notes |
|--------|--------|-------|-------|
| Cross-refs | 525 | 381 | -144 wrongly-flagged removed |
| Linked | 277 | 138 | -139 phantom links removed |
| Unlinked | 248 | 243 | -5 actual improvement |
| Resolution | 52.8% | 36.2% | Now accurate (was inflated) |

| Diagnostic | Before | After | Delta |
|------------|--------|-------|-------|
| term_not_found | 158 | 141 | -17 |
| no_citation | 70 | 81 | +11 (correctly reclassified) |
| parent_not_in_lrt | 15 | 9 | -6 |
| parent_unparsed | 1 | 8 | +7 (correct parent found) |
| term_normalisation | 4 | 4 | 0 |

### Key findings

- **Zero-def parents**: 6/9 are fully revoked (live=❌), no defs to extract. `live` column is the signal — no new column needed.
- **Continental Shelf Act**: 1 def is correct. Children reference s1(7) substantive definitions — session #4 scope.
- **Roads (NI) Order 1993**: 29 definitions extracted (was 0). Only actionable zero-def parent.

## Dependencies

- ✅ OH&S Resolution Audit (2026-08-19) — identified the bugs
