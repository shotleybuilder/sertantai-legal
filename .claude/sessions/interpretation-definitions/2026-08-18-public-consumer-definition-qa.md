---
session: Public & Consumer Safety Definition QA
status: closed
opened: 2026-08-18
closed: 2026-08-18
outcome: success

summary: >
  Ran diagnostic against 4 PUBLIC/CONSUMER families (429 laws, 3,420 defs). Classified
  448 findings. Discovered 3 new bugs — the leading ')' parser truncation (2,006 defs
  corpus-wide) is the single highest-affected bug found across all sessions. Also found
  that known bugs compound: ') means' causes 46 false parent_not_in_lrt in Building Safety.

metrics:
  public_diagnostic: { total: 448, no_citation: 189, parent_not_in_lrt: 98, term_not_found: 91, parent_unparsed: 60, term_normalisation: 10 }
  no_citation_causes: { internal_ref: 82, other_mostly_paren_truncation: 99, welsh_si_single_law: 38 }
  parent_not_in_lrt_causes: { paren_means_compound: 46, genuinely_missing: 47, interpretation_act: 4, regex_strips_title: 1 }
  new_bugs: { leading_paren: 2006, internal_ref_gap: 743, apostrophe_inconsistency: 20 }
  bugs_logged: { new: 3, total_open_cumulative: 22 }

lessons:
  - title: Bugs compound — two small bugs produce a large false-positive category
    detail: >
      The leading ')' truncation (parser) and 'means' prefix (CitationExtractor) bugs
      individually affect different stages. But in Building Safety, they combine: the
      citation becomes ') means the Building Act 1984 section 126', which fails both
      normalise_title (leading ')') and title_index lookup ('means' prefix). The parent
      law IS in LRT — fixing either bug would unblock 46 items. Lesson: when classifying
      diagnostic results, check for compound causes before assuming genuinely missing.
    tag: tooling

  - title: A single Welsh SI can dominate a diagnostic category
    detail: >
      UK_wsi_2025_1321 (Welsh Building Regulations) contributed 38 of 99 'other'
      no_citation items — bilingual definitions with Welsh terms. The parser extracted
      them correctly but they all start with ')' and are internal refs. One law = 40% of
      an entire category. Always check per-law distribution before assuming a pattern is
      widespread.
    tag: data

bugs:
  - pattern: "Definition text starts with ')' — parser extracts text from middle of parenthetical XML"
    category: parser
    module: DefinitionParser
    affected: 2006
    fix: "Text extraction starts after closing paren of term element. Strip leading ')' and any trailing orphan parens from extracted definition text"
    status: open

  - pattern: "internal_ref? misses 'has the meaning given/assigned in regulation/section N' pattern — only catches 'given by'"
    category: no_citation
    module: DefinitionParser (Definition struct / internal_ref?)
    affected: 743
    fix: "Expand internal_ref? patterns to include 'has the meaning given in', 'has the meaning assigned', and leading ')' variants"
    status: open

  - pattern: "Apostrophe inconsistently stripped in term normalisation — both 'public body''s' and 'public bodys' exist as terms"
    category: parser
    module: DefinitionParser (Definition struct / normalise_term)
    affected: 20
    fix: "normalise_term should consistently handle apostrophes — either always strip or always preserve. Dedup on normalised form"
    status: open

artifacts:
  - .claude/sessions/interpretation-definitions/2026-08-18-public-consumer-definition-qa.md

depends_on:
  - interpretation-definitions/2026-08-18-transport-safety-definition-qa
  - interpretation-definitions/2026-08-18-fire-domain-definition-qa
  - interpretation-definitions/2026-08-17-resolution-diagnostic

enables:
  - Fix-bugs session — leading ')' truncation is highest-impact single fix (2,006 defs)
  - internal_ref? expansion would reclassify ~1,743 items (1,000 existing + 743 new pattern)
  - Next family investigation (Environmental, Workplace, Employment, etc.)
---

# Session: Public & Consumer Safety Definition QA (CLOSED)

## Problem

Continuing family-by-family definition parser/resolver bug surfacing. FIRE found 8 bugs, Transport found 5 more (19 total open). Now investigating public safety and consumer protection families. Building Safety has the highest xref density (369 xrefs from 187 laws), likely exercising construction/building regulation citation patterns. **Investigation-only** — log bugs, don't fix.

Families in scope:
- **PUBLIC: Building Safety** — 187 laws, 44 parsed, 1,755 defs, 279 unlinked xrefs
- **PUBLIC: Consumer / Product Safety** — 128 laws, 38 parsed, 1,103 defs, 94 unlinked xrefs
- **PUBLIC** — 60 laws, 16 parsed, 177 defs, 17 unlinked xrefs
- **PUBLIC: Data** — 54 laws, 10 parsed, 385 defs, 58 unlinked xrefs

## Todo

- ✅ Run diagnostic against PUBLIC and CONSUMER families — 448 findings across 5 categories
- ✅ Drill into each category — found 3 new bugs (leading `)` 2,006 corpus-wide, internal_ref? gap 743, apostrophe inconsistency ~20)
- ✅ Cross-check against known bugs — `) means` compound causes 46 of 98 parent_not_in_lrt; Companies Act 0-defs confirmed again
- ✅ Log all discovered bugs in frontmatter (3 new bugs logged)

## Dependencies

- ✅ Resolution Diagnostic — diagnostic module built (2026-08-17)
- ✅ Fire Domain Definition QA — 8 bugs logged (2026-08-18)
- ✅ Transport Safety Definition QA — 5 bugs logged, concatenated terms revised to 72 (2026-08-18)

## Baseline

| Family | Laws | Parsed | Defs | Xrefs | Unlinked |
|--------|------|--------|------|-------|----------|
| Building Safety | 187 | 44 (24%) | 1,755 | 369 | 279 (76%) |
| Consumer / Product Safety | 128 | 38 (30%) | 1,103 | 106 | 94 (89%) |
| PUBLIC | 60 | 16 (27%) | 177 | 20 | 17 (85%) |
| PUBLIC: Data | 54 | 10 (19%) | 385 | 64 | 58 (91%) |
| **Total** | **429** | **108 (25%)** | **3,420** | **559** | **448 (80%)** |

## Diagnostic Results

| Category | Count | Building / Consumer / Public / Data |
|----------|-------|-----|
| `no_citation` | 189 | 125 / 38 / 7 / 19 |
| `parent_not_in_lrt` | 98 | 76 / 11 / 6 / 5 |
| `term_not_found` | 91 | 53 / 19 / 3 / 16 |
| `parent_unparsed` | 60 | 21 / 25 / 1 / 13 |
| `term_normalisation` | 10 | 4 / 1 / 0 / 5 |

### no_citation breakdown (189)

- **82** internal refs (known bug)
- **99** "other" — dominated by `) has the meaning given in regulation N` pattern (parser truncation + internal_ref? gap compound bug)
- **38** of the 99 from a single Welsh SI (UK_wsi_2025_1321)

### parent_not_in_lrt breakdown (98)

- **46** — `) means` compound bug (parser `)` truncation + means prefix). Almost all point to Building Act 1984 which IS in LRT
- **47** — genuinely missing
- **4** — Interpretation Act 1978 (known)
- **1** — regex-strips-title (known)

### Key finding: `) means` compound bug

The parser truncation bug (leading `)`) and `means` prefix bug compound in Building Safety. Citation extractor captures `) means the Building Act 1984 section 126` — the `)` makes normalise_title fail, and `means` pollutes the lookup. Building Act 1984 IS in LRT and parsed (83 defs), so fixing the extraction would resolve 46 items immediately.
