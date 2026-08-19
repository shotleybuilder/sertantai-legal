---
session: Mining, Offshore & Health Definition QA
status: closed
opened: 2026-08-19
closed: 2026-08-19
outcome: success

summary: >
  Ran diagnostic against 6 mining/offshore/health families (973 laws, 2,114 defs).
  316 findings almost entirely explained by known bugs — no new major patterns. One
  new bug found: chapter number suffix "(c. N)" pollutes title lookup (26 affected).
  Confirmed definition-list-bleed cascades into citation extraction.

metrics:
  diagnostic: { total: 316, no_citation: 117, parent_unparsed: 98, term_not_found: 58, parent_not_in_lrt: 41, term_normalisation: 2 }
  no_citation_causes: { internal_ref_given_by: 50, paren_truncation: 34, internal_ref_construed: 19, internal_ref_has_meaning: 5, other: 9 }
  bugs_logged: { new: 1, total_open_cumulative: 23 }

lessons:
  - title: Diminishing returns on family-by-family investigation after 4 sessions
    detail: >
      Sessions 1-3 discovered 16 new bugs. Session 4 found 1 new bug and confirmed
      known patterns. The bug taxonomy is stabilising — further family investigations
      will mostly confirm existing bugs rather than surface new ones. Time to shift
      from discovery to fixing.
    tag: tooling

  - title: Definition-list-bleed cascades into citation extraction
    detail: >
      When definitions bleed together, the citation from a LATER definition gets
      applied to ALL earlier definitions in the same blob. UK_wsi_2020_1609 had
      "Children Act 1989" (from parental responsibility) applied to face covering,
      food and drink business, etc. The bleed bug has a multiplier effect — each
      bled definition corrupts N subsequent citations, not just its own text.
    tag: data

bugs:
  - pattern: "Chapter number suffix '(c. N)' in citations pollutes title_index lookup — normalise_title keeps 'c N' in string"
    category: parent_not_in_lrt
    module: CitationExtractor / normalise_title
    affected: 26
    fix: "normalise_title should strip '(c. N)' patterns (Act chapter numbers) before lookup, similar to (asp N) stripping"
    status: open

artifacts:
  - .claude/sessions/interpretation-definitions/2026-08-19-mining-offshore-health-definition-qa.md

depends_on:
  - interpretation-definitions/2026-08-18-public-consumer-definition-qa
  - interpretation-definitions/2026-08-18-transport-safety-definition-qa
  - interpretation-definitions/2026-08-18-fire-domain-definition-qa

enables:
  - Fix-bugs session — bug taxonomy now stable, 23 open bugs prioritised by affected count
  - Remaining families (Environmental, Employment, Workplace) likely yield few new bugs
---

# Session: Mining, Offshore & Health Definition QA (CLOSED)

## Problem

Continuing family-by-family definition parser/resolver bug surfacing. Three prior sessions surfaced 22 open bugs. Now investigating mining, offshore safety, and health families. Coronavirus (558 laws) is the largest by count but sparsely parsed (6%); Public Health has the highest unlinked rate (116 from 25 parsed). **Investigation-only** — log bugs, don't fix.

Families in scope:
- **HEALTH: Coronavirus** — 558 laws, 34 parsed, 222 defs, 53 unlinked xrefs
- **HEALTH: Public** — 170 laws, 25 parsed, 525 defs, 116 unlinked xrefs
- **HEALTH: Drug & Medicine Safety** — 121 laws, 9 parsed, 155 defs, 20 unlinked xrefs
- **OH&S: Offshore Safety** — 58 laws, 17 parsed, 434 defs, 49 unlinked xrefs
- **HEALTH: Patient Safety** — 41 laws, 9 parsed, 455 defs, 49 unlinked xrefs
- **OH&S: Mines & Quarries** — 25 laws, 12 parsed, 323 defs, 29 unlinked xrefs

## Todo

- ✅ Run diagnostic against target families — 316 findings across 5 categories
- ✅ Drill into each category — no_citation 108/117 explained by known bugs; parent_not_in_lrt dominated by genuinely missing laws
- ✅ Cross-check against 22 known bugs — all confirmed; 1 new bug found (chapter number suffix); bleed bug confirmed to cascade into citation extraction
- ✅ Log all discovered bugs in frontmatter (1 new bug logged)

## Dependencies

- ✅ Fire Domain Definition QA — 8 bugs (2026-08-18)
- ✅ Transport Safety Definition QA — 5 bugs (2026-08-18)
- ✅ Public & Consumer Safety Definition QA — 3 bugs, leading ')' truncation found (2026-08-18)

## Baseline

| Family | Laws | Parsed | Defs | Xrefs | Unlinked |
|--------|------|--------|------|-------|----------|
| Coronavirus | 558 | 34 (6%) | 222 | 64 | 53 (83%) |
| Public Health | 170 | 25 (15%) | 525 | 131 | 116 (89%) |
| Drug & Medicine Safety | 121 | 9 (7%) | 155 | 22 | 20 (91%) |
| Offshore Safety | 58 | 17 (29%) | 434 | 67 | 49 (73%) |
| Patient Safety | 41 | 9 (22%) | 455 | 53 | 49 (92%) |
| Mines & Quarries | 25 | 12 (48%) | 323 | 29 | 29 (100%) |
| **Total** | **973** | **106 (11%)** | **2,114** | **366** | **316 (86%)** |

## Diagnostic Results

| Category | Count | Key patterns |
|----------|-------|-------------|
| `no_citation` | 117 | 74 internal refs (known), 34 paren truncation (known), 6 EU/external refs, 3 other |
| `parent_unparsed` | 98 | Coverage gap — not a bug |
| `term_not_found` | 58 | Companies Act 0-defs (9), parent coverage gaps, 4 silent parser failures |
| `parent_not_in_lrt` | 41 | 15 def-list-bleed cascade (wrong citation from bled text), 26 chapter number suffix "(c. N)", genuinely missing |
| `term_normalisation` | 2 | Minor near-misses |

### Key findings

**No new major bugs** — this session confirmed known bugs dominate. 108 of 117 no_citation are explained by internal_ref? gap + paren truncation. The one new bug is chapter number suffix "(c. N)" polluting title lookup (26 affected).

**Def-list-bleed cascades into citation extraction**: UK_wsi_2020_1609 (Welsh Coronavirus regs) had all definitions bled into one blob. The "Children Act 1989" citation from `parental responsibility` got applied to every term (face covering, food and drink business, etc.). The bleed bug doesn't just corrupt definition text — it corrupts the citation for ALL subsequent definitions.

**Coronavirus family is mostly parent_unparsed (23/53)**: 558 laws but only 34 parsed (6%). Not a parser bug — these SIs were never run through the parser.
