---
session: Transport Safety Definition QA
status: closed
opened: 2026-08-18
closed: 2026-08-18
outcome: success

summary: >
  Ran diagnostic against 4 transport safety families (736 laws, 5,668 defs). Classified
  499 unlinked cross-reference findings. Discovered 4 new bug patterns, revised the
  concatenated-terms count from 6 to 72 corpus-wide, and identified the Interpretation
  Act 1978 as the biggest missing-law data gap (97 refs across 67 laws).

decisions:
  - what: Concatenated terms bug scope revised from 6 to 72 pairs / 51 laws
    why: FIRE session searched by specific known patterns. Transport session used definition-text signature ('and "" have the meaning') which catches all instances systematically.
    result: 12x larger than originally estimated — now a high-priority parser fix

  - what: Bare Act references resolvable via enacted_by relationship
    why: SIs reference their parent Act as just "the Act". The enacted_by column already records which Act an SI was made under. 44 of 70 have enacted_by populated.
    result: Potential auto-resolution of 44 cross-refs without any parser changes — just a Matcher enhancement

metrics:
  transport_diagnostic: { total: 499, term_not_found: 137, parent_unparsed: 126, no_citation: 116, parent_not_in_lrt: 112, term_normalisation: 8 }
  parent_not_in_lrt_causes: { regex_strips_title: 23, interpretation_act_missing: 31, genuinely_missing: 88 }
  no_citation_causes: { internal_ref: 62, intl_convention: 12, external_defined_in: 9, concatenated: 4, other: 29 }
  concatenated_terms_revised: { fire_estimate: 6, corpus_actual: 72, affected_laws: 51 }
  interpretation_act: { total_refs: 97, from_laws: 67 }
  bare_act_refs: { total: 70, with_enacted_by: 44 }
  bugs_logged: { new: 4, refined: 1, total_open_cumulative: 19 }

lessons:
  - title: Corpus-wide searches find order-of-magnitude more bugs than family-scoped samples
    detail: >
      FIRE session found 6 concatenated terms by searching for specific known patterns.
      Transport session used the definition-text signature 'and "" have the meaning' to
      find 72 across 51 laws. Always follow up a family-scoped finding with a corpus-wide
      signature search to get the true count.
    tag: tooling

  - title: The Interpretation Act 1978 is the most cross-referenced law not in LRT
    detail: >
      97 definitions across 67 laws reference it. It defines foundational terms used
      across all UK legislation. Its absence silently causes 31 parent_not_in_lrt
      failures in transport safety alone. Adding it to LRT and parsing its definitions
      would resolve cross-refs across every family.
    tag: data

  - title: Title-stripping regex is broader than initially diagnosed
    detail: >
      FIRE session found the regex matches singular "Regulation" in titles when followed
      by a section ref. Transport revealed it ALSO matches bare citations like "Road
      Traffic Regulation Act 1984" — "Regulation Act 1984" matches as keyword + trailing
      content. The regex doesn't need a trailing section/article ref to trigger, just any
      text after the keyword.
    tag: data

  - title: Maritime law exercises international instrument citation patterns no other family does
    detail: >
      SOLAS, UNCLOS, MLC, ICAO Annex 13, Radio Regulations — these are international
      conventions that will never be in the UK legal_register. The diagnostic should
      classify these as a distinct category rather than lumping them into no_citation.
      12 found in transport, likely more in other maritime-adjacent families.
    tag: data

  - title: Road Safety parent_not_in_lrt is 54% explained by two known bugs
    detail: >
      76 parent_not_in_lrt findings in Road Safety. 23 are regex-strips-title (Road
      Traffic Regulation Act), 18 are Interpretation Act 1978 missing. That's 41/76 (54%)
      from just two fixable causes. Fix those two and Road Safety's parent_not_in_lrt
      drops by half.
    tag: data

bugs:
  - pattern: "Concatenated terms bug is 72 pairs / 51 laws corpus-wide, not 6 as estimated in FIRE session"
    category: parser
    module: DefinitionParser
    affected: 72
    fix: "Same fix as FIRE bug — split 'X' and 'Y' patterns. Definition text starts with 'and \"\" have the meaning' is the signature"
    status: open

  - pattern: "Interpretation Act 1978 not in LRT — most cross-referenced UK law missing entirely"
    category: data_gap
    module: LegalRegister
    affected: 97
    fix: "Add Interpretation Act 1978 (UK_ukpga_1978_30) to legal_register and parse definitions. Referenced by 67 laws across all families"
    status: open

  - pattern: "International convention refs (SOLAS, UNCLOS, MLC, ICAO Annex 13, Radio Regulations) can't resolve — not UK legislation"
    category: no_citation
    module: CitationExtractor
    affected: 12
    fix: "Mark as 'international_convention' category in diagnostic. Optionally add international instruments to a separate index"
    status: open

  - pattern: "Bare 'the Act' references in SIs — 'given by section N of the Act' without naming which Act"
    category: no_citation
    module: CitationExtractor / Matcher
    affected: 70
    fix: "Resolve using enacted_by relationship — 44 of 70 have enacted_by populated. SI's 'the Act' = its parent Act"
    status: open

  - pattern: "Title-stripping regex triggers on bare citations too — 'Road Traffic Regulation Act 1984' → 'Road Traffic' even without trailing section ref"
    category: parent_not_in_lrt
    module: resolve_law_name
    affected: 18
    fix: "Same regex fix as FIRE bug — note: the regex matches 'Regulation Act YYYY' as keyword+trailing content, not just 'Regulation section N'. Broader than initially estimated"
    status: open

artifacts:
  - .claude/sessions/interpretation-definitions/2026-08-18-transport-safety-definition-qa.md

depends_on:
  - interpretation-definitions/2026-08-18-fire-domain-definition-qa
  - interpretation-definitions/2026-08-17-resolution-diagnostic
  - interpretation-definitions/2026-08-17-root-resolver-architecture

enables:
  - Fix-bugs session targeting high-impact bugs (concatenated terms 72, Interpretation Act data gap, regex fix)
  - Bare Act resolution via enacted_by — a Matcher enhancement, not a parser fix
  - International convention index for maritime/aviation families
  - Next family investigation (Environmental, Construction, Workplace Safety, etc.)
---

# Session: Transport Safety Definition QA (CLOSED)

## Problem

Continuing family-by-family definition parser/resolver bug surfacing. OH&S found 6 bugs, FIRE found 8 more (14 total open). Now investigating transport safety families — maritime, road, rail, and air. These families have significantly more data than FIRE (736 laws, 5,668 defs, 499 unlinked xrefs) and are likely to exercise different citation patterns (IMO conventions, ICAO standards, EU transport directives, Highway Act references). **Investigation-only** — log bugs, don't fix.

Families in scope:
- **TRANSPORT: Maritime Safety** — 298 laws, 108 parsed, 2,665 defs, 209 unlinked xrefs
- **TRANSPORT: Road Safety** — 248 laws, 78 parsed, 2,081 defs, 217 unlinked xrefs
- **TRANSPORT: Rail Safety** — 53 laws, 17 parsed, 490 defs, 46 unlinked xrefs
- **TRANSPORT: Air Safety** — 137 laws, 31 parsed, 432 defs, 27 unlinked xrefs

## Todo

- ✅ Run diagnostic against transport safety families — 499 findings across 5 categories
- ✅ Drill into each diagnostic category — sampled all, identified 5 new bug patterns + refined 1 existing
- ✅ Investigate domain-specific citation patterns (SOLAS, UNCLOS, MLC, ICAO, "the Act" bare refs)
- ✅ Cross-check against known bugs — regex, concatenated terms, internal_ref? all confirmed; concatenated terms revised to 72 corpus-wide
- ✅ Log all discovered bugs in frontmatter (5 new bugs + 1 refinement logged)

## Dependencies

- ✅ Resolution Diagnostic — diagnostic module built (2026-08-17)
- ✅ Fire Domain Definition QA — 8 bugs logged, bugs-in-frontmatter workflow proven (2026-08-18)
- ✅ Root Resolver Architecture — 6-module decomposition (2026-08-17)
- ✅ Definition Parser Architecture — 6 modules (2026-08-17)

## Baseline

| Family | Laws | Parsed | Defs | Xrefs | Unlinked |
|--------|------|--------|------|-------|----------|
| Maritime Safety | 298 | 108 (36%) | 2,665 | 230 | 209 (91%) |
| Road Safety | 248 | 78 (31%) | 2,081 | 258 | 217 (84%) |
| Rail Safety | 53 | 17 (32%) | 490 | 67 | 46 (69%) |
| Air Safety | 137 | 31 (23%) | 432 | 30 | 27 (90%) |
| **Total** | **736** | **234 (32%)** | **5,668** | **585** | **499 (85%)** |

## Diagnostic Results

499 findings across 4 transport safety families.

| Category | Count | By Family (Maritime/Road/Rail/Air) |
|----------|-------|-----|
| `term_not_found` | 137 | 77 / 31 / 19 / 10 |
| `parent_unparsed` | 126 | 52 / 49 / 18 / 7 |
| `no_citation` | 116 | 44 / 55 / 9 / 8 |
| `parent_not_in_lrt` | 112 | 34 / 76 / 0 / 2 |
| `term_normalisation` | 8 | 2 / 6 / 0 / 0 |

### parent_not_in_lrt breakdown (112)

- **23** — regex-strips-title bug (mostly "Road Traffic Regulation Act 1984" → "Road Traffic")
- **31** — Interpretation Act 1978 not in LRT (4+7+5+3+2+... citations)
- **88** — genuinely not in LRT (scattered across many laws)

### no_citation breakdown (116)

- **62** — internal refs not caught by `internal_ref?` (known bug)
- **12** — international convention refs (SOLAS, UNCLOS, MLC, ICAO)
- **9** — "as defined in" external refs without standard citation
- **4** — concatenated terms
- **29** — other (bare "the Act" refs, truncated definitions, non-standard patterns)

### term_not_found highlights

- Merchant Shipping (Tonnage) Regs: 21 missing terms ("gross tonnage", "gross tons" etc.) — parent has 19 defs but none match the child terms
- Merchant Shipping Act 1995: 22 missing terms — includes 6× "act" (term should be internal ref, not cross-ref), 5× "united kingdom ship" (concatenated with "united kingdom fishing vessel" in parent)
- Highways Act: 11 missing — "public road" etc. not in parent's 293 definitions (different terminology)

### Key finding: concatenated terms revised upward

Systematic corpus-wide search found **72 concatenated term pairs across 51 laws** (previously estimated at 6 in FIRE). Signature: definition starts with `and "" have the meaning`. Merchant Shipping Act 1995 alone has 4 concatenated terms.
