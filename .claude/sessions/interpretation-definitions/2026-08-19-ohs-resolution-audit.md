---
session: OH&S Resolution Audit
status: active
opened: 2026-08-19
bugs:
  - pattern: "referenced_law_citation populated from amendment annotations, not definition text — 80% wrong corpus-wide"
    category: term_not_found / systemic
    module: RootResolver Persister + Diagnostic
    affected: 4018
    fix: "Either ignore referenced_law_citation and re-extract from definition text, or clear stale values before resolver run"
    status: open
  - pattern: "HSWA 1974 section 53 parsed as giant unsplit blob — each definition contains 3000-6400 chars of the whole section"
    category: term_not_found
    module: DefinitionParser
    affected: 27
    fix: "Parser needs to split HSWA-style interpretation sections where terms are inline ;-separated, not in Definition list XML"
    status: open
  - pattern: "Continental Shelf Act 1964 has only 1 definition extracted but 14 children reference it"
    category: term_not_found
    module: DefinitionParser
    affected: 14
    fix: "Reparse UK_ukpga_1964_29 — likely parser failure on older Act structure"
    status: open
  - pattern: "9 parent laws parsed with 0 definitions — parser silent failure or no interpretation section"
    category: term_not_found
    module: DefinitionParser
    affected: 12
    fix: "Check XML structure for each; may need parser enhancement for pre-1970 Acts or NI Orders"
    status: open
  - pattern: "Diagnostic doesn't check internal_ref? — inflates no_citation by 53 for OH&S alone"
    category: no_citation (misclassified)
    module: Diagnostic
    affected: 53
    fix: "Add internal_ref? check to Diagnostic.classify before reporting :no_citation"
    status: open
  - pattern: "internal_ref? regex misses paragraph/subsection with parenthesized numbers — 'paragraph (5)' not matched"
    category: no_citation
    module: CitationExtractor (internal_ref?)
    affected: 6
    fix: "Extend @internal_ref_re to allow optional parentheses around section numbers: paragraph\\s+\\(?\\d"
    status: open
  - pattern: "SI abbreviation with year prefix not extracted — 'the 2014 Acetylene Regulations' unresolvable"
    category: no_citation
    module: CitationExtractor
    affected: 2
    fix: "Add pattern for 'the YYYY Name Regulations' where year precedes the title"
    status: open
  - pattern: "Semicolon before year in citations breaks extraction — 'Regulations ;2015'"
    category: no_citation
    module: DefinitionParser (text extraction)
    affected: 2
    fix: "Strip stray semicolons from definition text during parsing or normalise in CitationExtractor"
    status: open
  - pattern: "Section-level definitions not parsed — terms defined in substantive sections (not interpretation section) absent from parent"
    category: term_not_found
    module: DefinitionParser
    affected: 72
    fix: "Extend parser to extract definitions referenced by specific section numbers in child definitions, OR accept as resolution ceiling"
    status: open
  - pattern: "Hyphen inconsistency in term normalisation — 'dual-purpose vehicle' vs 'dual purpose vehicle'"
    category: term_normalisation
    module: DefinitionParser (normalise_term)
    affected: 1
    fix: "Strip or normalise hyphens in normalise_term/1"
    status: open
---

# Session: OH&S Resolution Audit (ACTIVE)

## Problem

OH&S family definition resolution sits at 52.8% (248 unlinked out of 525 cross-refs, 3137 total defs). After fixing issues #147-151 and reparsing OH&S laws + parents, the remaining buckets are: term_not_found (158), no_citation (70), parent_not_in_lrt (15), term_normalisation (4), parent_unparsed (1). The goal is to catalogue every remaining resolution failure in OH&S so that subsequent fix sessions can target 90%+ resolution systematically.

This is a **bug-finding session only** — no code changes, no fixes.

## Todo

- ✅ Run OH&S-filtered diagnostic, capture current baseline
- ✅ Analyse term_not_found bucket (158) — categorise failure patterns
- ✅ Analyse no_citation bucket (70) — categorise why extraction fails
- ✅ Analyse parent_not_in_lrt bucket (15) — which laws, scrapeable?
- ✅ Analyse citation_ambiguous (0) + term_normalisation (4) + parent_unparsed (1) buckets
- ✅ Cross-reference against 26 existing open bugs — which apply to OH&S
- ✅ Produce prioritised bug list with affected counts and fix difficulty

## Dependencies

- ✅ Issue #148: Definition List Item Bleed (2026-08-19)
- ✅ Issue #151: Concatenated Terms (2026-08-19)
- ✅ Issue #147: Abbreviation-Style Law References (2026-08-19)
- ✅ Issue #150: Bare 'the Act' References in SIs (2026-08-19)
- ✅ OH&S reparse + parent law parsing (earlier this conversation)

## Baseline

| Metric | Value |
|--------|-------|
| Total OH&S definitions | 3,137 |
| Cross-references | 525 |
| Linked (resolved) | 277 (52.8%) |
| Unlinked | 248 |

| Diagnostic bucket | Count |
|---|---|
| term_not_found | 158 |
| no_citation | 70 |
| parent_not_in_lrt | 15 |
| term_normalisation | 4 |
| parent_unparsed | 1 |
| citation_ambiguous | 0 |

## Analysis: term_not_found (158)

| Sub-category | Count | Root cause | Fixable? |
|---|---|---|---|
| Section-level defs not parsed | ~72 | Parser only extracts interpretation sections | Hard — structural gap |
| HSWA blob parse failure | 27 | Section 53 extracted as giant unsplit blob | Medium — parser enhancement |
| Wrong referenced_law_citation | 24 | Stale resolver data from amending Act annotations | Easy — clear + re-run |
| Parent underextracted (≤5 defs) | 16 | Continental Shelf Act 1964 = 1 def, 14 children | Medium — reparse |
| Parent has 0 defs | 12 | 9 parent laws parsed with nothing | Medium — check XML |
| Not cross-refs (wrongly flagged) | 5 | references_other_law=true on substantive defs | Easy — reparse |
| True mismatches | ~2 | Genuine term absence | Ceiling |

**Key finding**: `referenced_law_citation` is wrong for 80% of entries corpus-wide (4,018 of 5,000 sampled). This single field poisons both the Diagnostic and the resolver. Clearing it and re-extracting from definition text would fix 24 OH&S entries immediately.

**HSWA blob**: The "employee" definition in HSWA 1974 is 4,833 characters long — it contains the ENTIRE interpretation section from "employee" to the end. All 27 HSWA blob definitions reference "section 53-1" and contain text from multiple definitions, which causes the citation extractor to pick up wrong law references embedded in the blob.

## Analysis: no_citation (70)

| Sub-category | Count | Root cause | Fixable? |
|---|---|---|---|
| Diagnostic misclassification | 53 | Diagnostic.classify doesn't check internal_ref? | Easy — code fix |
| internal_ref? regex too narrow | 6 | paragraph/subsection with (N) not matched | Easy — regex |
| SI abbreviation with year prefix | 2 | "the 2014 Acetylene Regulations" | Easy — new pattern |
| Semicolon before year | 2 | "Regulations ;2015" text artefact | Easy — clean |
| EU regulation pattern | 2 | "Regulation (EC) No 1272/2008" | Medium — EU handling |
| Vague/complex refs | 5 | "same meaning as in the second mentioned Regulations" | Unfixable |

**Key finding**: 53 of 70 are not really "no_citation" — they're internal refs that the Diagnostic doesn't detect. Fixing `Diagnostic.classify` to check `internal_ref?` before reporting `:no_citation` would correctly reclassify them. This doesn't fix linking but gives accurate metrics.

## Analysis: parent_not_in_lrt (15)

| Sub-category | Count | Fixable? |
|---|---|---|
| EU Regulation 2016/424 cross-refs | 9 | No — EU law not in UK LRT |
| Pre-1963 Act (Coal Act 1938) | 2 | No — Regnal year numbering |
| NI secondary legislation | 2 | Yes — scrapeable |
| Short-name "the 1974 Act" → HSWA | 1 | Yes — add to short-name resolver |
| Mangled blob citation | 1 | Fixed by blob parsing fix |

## Analysis: Other Buckets

- **term_normalisation (4)**: 1 genuine (hyphen in "dual-purpose"), 3 false positives from fuzzy matcher
- **parent_unparsed (1)**: Education Act 1993/1944 confusion — title_index resolves to wrong year
- **citation_ambiguous (0)**: None in OH&S

## Prioritised Fix List (Path to 90%+)

Target: 248 unlinked → <53 (90%+ of 525 cross-refs resolved). Need to fix ≥195.

| Priority | Fix | OH&S impact | Corpus impact | Difficulty |
|---|---|---|---|---|
| P0 | Clear stale referenced_law_citation, re-extract | 24 fixed | ~4,000 reclassified | Easy (SQL + re-run) |
| P1 | Fix Diagnostic internal_ref? check | 53 reclassified | ~1,000 reclassified | Easy (code) |
| P2 | Split HSWA-style blob interpretation sections | 27 fixed | ~100 corpus-wide | Medium (parser) |
| P3 | Reparse underextracted parent laws | 16 fixed | ~50 corpus-wide | Easy (data) |
| P4 | Reparse zero-def parent laws | 12 fixed | ~50 corpus-wide | Easy (data) |
| P5 | Extend internal_ref? regex (parenthesized nums) | 6 reclassified | ~100 corpus-wide | Easy (regex) |
| P6 | Parse section-level definitions | ~72 fixed | ~2,000 corpus-wide | Hard (architecture) |
| P7 | Minor citation fixes (semicolons, SI abbrevs) | 6 fixed | ~50 corpus-wide | Easy (regex) |

**P0-P5 combined**: ~85 definitions fixed + 59 correctly reclassified = 144 actionable
**With P6**: additional ~72 = 216 total → 32 remaining unlinked (93.9% resolution)

Without P6 (section-level parsing), best achievable: 248 - 85 = 163 unlinked → 68.9% resolved. **P6 is required for 90%+.**

## Cross-reference with Existing Open Bugs

The following existing bugs from the session index are confirmed relevant to OH&S:

| Existing bug | OH&S overlap |
|---|---|
| "internal_ref? not catching many genuine internal refs" (1,000 affected) | Confirmed: 53 OH&S defs |
| "internal_ref? misses 'has the meaning given/assigned in regulation/section N'" (743) | Confirmed: overlaps with 53 above |
| "Definition text starts with ')'" (2,006) | Not significant in OH&S |
| "Concatenated terms" (72) | Confirmed: parent law "contraventioncontravene" in Mines Act |
| "Laws parsed with 0 definitions" (2) | Confirmed: expanded to 9 parent laws in OH&S |
| "resolve_law_name regex strips words in law TITLES" (295) | Not confirmed in OH&S |
| "(NI) abbreviation doesn't match (Northern Ireland)" (16) | Confirmed: 2 NI parent laws |
