---
session: Food & Gas Safety Definition Investigation
status: closed
opened: 2026-08-20
closed: 2026-08-20
outcome: success

summary: >
  Investigated FOOD (61.1% resolution, 74 unresolved) and Gas & Electrical (65.0%, 7 unresolved).
  Root cause: 64% of FOOD's no_citation are EU Regulation short-form refs the extractor doesn't handle.
  All 7 Gas & Electrical gaps are plural paragraph internal refs. 3 new bugs logged.

metrics:
  diagnostic_food:
    family: "FOOD"
    cross_refs: 190
    unlinked: 187
    actionable: 117
    ceiling: 70
    no_citation: 74
    term_not_found: 30
    parent_unparsed: 13
    internal_ref: 27
    parent_not_in_lrt: 25
    parent_revoked: 18
  diagnostic_gas:
    family: "OH&S: Gas & Electrical Safety"
    cross_refs: 20
    unlinked: 12
    actionable: 11
    ceiling: 1
    no_citation: 7
    term_not_found: 4
    internal_ref: 1

lessons:
  - title: "FOOD definition gaps are dominated by EU Regulation references, not UK law"
    detail: >
      47 of 74 FOOD no_citation items reference EU Regulations in short-form
      ('Regulation 853/2004', 'Article 3(49) of Regulation 2017/625'). The CitationExtractor
      handles 'Directive YYYY/NN/EC' and 'Regulation (EC) No NNN/YYYY' but not the bare
      'Regulation NNN/YYYY' format common in food safety law. Different domains have
      different citation conventions — always check the actual corpus before assuming
      existing patterns cover it.
    tag: data

bugs:
  - pattern: "EU Regulation short-form citations not extracted — 'Regulation 853/2004', 'Article 3(49) of Regulation 2017/625', 'Annex I to Regulation 853/2004'"
    category: no_citation
    module: CitationExtractor
    affected: 47
    fix: "Add patterns for EU short-form: 'Regulation NNN/YYYY' (no 'No.' prefix), 'Article N of Regulation NNN/YYYY', 'Annex to Regulation NNN/YYYY'"
    status: open
  - pattern: "internal_ref? misses plural paragraph/subsection with ranges — 'paragraphs (2) to (4)', 'subsections (3) and (4)'"
    category: no_citation
    module: CitationExtractor (internal_ref?)
    affected: 12
    fix: "Extend @internal_ref_re to allow plural 'paragraphs/subsections' + parenthesized numbers + 'to/and' ranges"
    status: open
  - pattern: "Pronoun refs ('that Act', 'those Regulations') not resolved when sibling_index has no entry for the section"
    category: no_citation
    module: Matcher (resolve_pronoun_ref)
    affected: 19
    fix: "Fall back to enacted_by parent when sibling_index miss for pronoun refs in SIs"
    status: open

depends_on:
  - 2026-08-19-ohs-resolution-audit
  - 2026-08-19-stale-citation-cleanup

enables:
  - Food & Gas Citation Fixes session (2026-08-20, pending)
---

# Session: Food & Gas Safety Definition Investigation (CLOSED)

## Problem

FOOD family at 61.1% resolution (74 unresolved out of 190 cross-refs). OH&S: Gas & Electrical Safety at 65.0% (7 unresolved out of 20). All laws already parsed — the gap is in citation extraction and resolution, not parsing coverage.

## Todo

- ✅ Run diagnostic for FOOD — 187 unlinked (117 actionable, 70 ceiling), 74 no_citation, 30 term_not_found
- ✅ Run diagnostic for Gas & Electrical — 12 unlinked (11 actionable, 1 ceiling), 7 no_citation, 4 term_not_found
- ✅ Investigate no_citation patterns — see findings below
- ✅ Log 3 new bugs in frontmatter

## Known Open Bugs (8)

- Concatenated terms (72) — DefinitionParser
- Section-level definitions (72) — DefinitionParser
- Continental Shelf Act (14) — DefinitionParser
- International conventions (12) — CitationExtractor
- Consolidated Act mismatch (2+2) — Indexes
- FRS abbreviation (2+2) — Indexes/CitationExtractor

## Dependencies

- ✅ OH&S Resolution Audit — established diagnostic workflow
- ✅ Stale Citation Cleanup — cleared stale data
- ✅ Diagnostic improvements — parent_revoked, internal_ref, citation-resolved metrics
