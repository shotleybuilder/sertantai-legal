---
session: Fire Domain Definition QA
status: closed
opened: 2026-08-18
closed: 2026-08-18
outcome: success

summary: >
  Ran diagnostic against FIRE domain families (353 laws, 56 parsed). Classified
  145 unlinked cross-reference findings into 5 failure categories. Discovered 8
  new bug patterns (highest-impact: title-stripping regex ~295 affected, definition
  list bleed 155 defs/58 laws). Confirmed 2 prior-session bugs also surface in FIRE.

decisions:
  - what: Investigation-only session — find and log bugs, never fix
    why: Prior sessions proved find+fix is incompatible in one session. Context switching between investigation and implementation degrades both.
    result: 8 bugs logged cleanly in frontmatter, ready for a dedicated fix session

  - what: Diagnostic population is references_other_law=true AND citation=false, not citation=true
    why: citation=true definitions are law alias mappings (short name → full citation) that feed the citation_index. references_other_law=true AND citation=false are the actual cross-references needing root resolution.
    result: 145 FIRE findings (not the 66 from naive SQL), 8,177 corpus-wide — correct population for bug investigation

  - what: Used Tidewave MCP for all DB queries and Elixir evaluation
    why: Direct access to running Phoenix app and Ecto repo, avoids psql encoding issues, can call diagnostic module functions directly
    result: Faster iteration — diagnostic run + filtering + classification in one eval call

metrics:
  fire_diagnostic: { total: 145, no_citation: 53, term_not_found: 44, parent_unparsed: 26, parent_not_in_lrt: 20, term_normalisation: 2 }
  corpus_wide_bugs: { title_regex: 295, def_list_bleed: 155, ni_abbreviation: 16, means_prefix: 14, concat_terms: 6, asp_suffix: 6, silent_parse_fail: 2, frs_abbreviation: 2 }
  coverage_gap: { unparsed_total: 297, australian: 59, revoked: 91, in_force_uk: 62, unknown: 68, partial: 17 }
  bugs_logged: { new: 8, prior_confirmed: 2, total_open: 14 }

lessons:
  - title: resolve_law_name regex matches title words, not just trailing section refs
    detail: >
      The regex \s+(section|regulation|article|...)\s+.+$ strips everything from the
      first matching word to end-of-string. Singular "Regulation" in law titles like
      "Road Traffic Regulation (NI) Order 1997 article 2(2)" gets matched, truncating
      to "Road Traffic". Plural "Regulations" is safe because the regex matches
      "regulation" (no trailing s). 493 laws have singular "Regulation" in title_en.
    tag: data

  - title: Definition list bleed is a parser structural bug, not an edge case
    detail: >
      155 definitions across 58 laws have downstream list items (;b", ;c", ;d")
      appended to the previous definition's text. Each bleeding definition means both
      the current and subsequent definitions have corrupted text. Worst case is
      UK_uksi_2014_1638 (Explosives Regulations) with 11 affected definitions from
      one law.
    tag: data

  - title: Family-by-family investigation is the right cadence for surfacing bugs
    detail: >
      OH&S investigation found 6 bugs, FIRE found 8 new ones. Each family exercises
      different citation patterns (NI Orders, Scottish Acts, EU Directives). Bugs that
      are invisible in one family's data become obvious in another's. Running the
      diagnostic module filtered by family gives a manageable scope for drill-down.
    tag: tooling

  - title: Tidewave MCP avoids UUID encoding pain
    detail: >
      Postgrex requires raw 16-byte binary UUIDs for parameterised queries but
      Diagnostic.Finding stores them as binary. Using mcp__tidewave__execute_sql_query
      with id::text casts avoids the encoding dance. For Elixir-side work,
      mcp__tidewave__project_eval lets you call module functions directly.
    tag: infrastructure

bugs:
  - pattern: "resolve_law_name regex strips words in law TITLES — singular 'Regulation' matched as section ref"
    category: parent_not_in_lrt
    module: Diagnostic + Matcher (resolve_law_name)
    affected: 295
    fix: "Anchor regex to only match trailing section/article refs, not title words. E.g. require the keyword to be preceded by a year or closing paren"
    status: open

  - pattern: "'(NI)' abbreviation in citations doesn't match '(Northern Ireland)' in title_index"
    category: parent_not_in_lrt
    module: Indexes / normalise_title
    affected: 16
    fix: "normalise_title should expand '(NI)' → '(Northern Ireland)', or add alias entries in title_index"
    status: open

  - pattern: "Parser concatenates adjacent '\"X\" and \"Y\"' terms into single term (e.g. 'workat work', 'chief constableconstable')"
    category: parser
    module: DefinitionParser (definition_list_strategy or inline_text_strategy)
    affected: 6
    fix: "Split compound term patterns — detect '\"X\" and \"Y\" shall be construed...' and emit two definitions"
    status: open

  - pattern: "Definition list items bleed into each other — lettered sub-items (;b\", ;c\") not split"
    category: parser
    module: DefinitionParser (definition_list_strategy)
    affected: 155
    fix: "Parser must split on lettered sub-item markers within definition lists. Each ;N\"term\" means... is a new definition"
    status: open

  - pattern: "Citation 'means' prefix captured — 'means the Fire and Rescue Services...' instead of 'the Fire and Rescue Services...'"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 14
    fix: "Strip leading 'means' from extracted citations before title_index lookup"
    status: open

  - pattern: "Scottish '(asp N)' suffix in citations pollutes title_index lookup key"
    category: parent_not_in_lrt
    module: CitationExtractor / resolve_law_name
    affected: 6
    fix: "normalise_title should strip '(asp N)' patterns (Scottish Parliament Act numbering)"
    status: open

  - pattern: "Laws parsed with 0 definitions — silent parser failure (Companies Act 2006, Product Safety Metrology Regs 2020)"
    category: parser
    module: DefinitionParser
    affected: 2
    fix: "Log warning when parsing completes with 0 definitions for a non-trivial law. Investigate why these large Acts yield nothing"
    status: open

  - pattern: "'FRS' and other common abbreviations not in title_index — 'FRS Act 2004' can't resolve to Fire and Rescue Services Act"
    category: parent_not_in_lrt
    module: Indexes (title_index)
    affected: 2
    fix: "Add common abbreviation mappings to title_index or expand abbreviations in CitationExtractor"
    status: open

artifacts:
  - .claude/sessions/interpretation-definitions/2026-08-18-fire-domain-definition-qa.md

depends_on:
  - interpretation-definitions/2026-08-17-resolution-diagnostic
  - interpretation-definitions/2026-08-17-root-resolver-architecture
  - interpretation-definitions/2026-08-17-definition-parser-architecture

enables:
  - Fix-bugs session targeting the 8 new open bugs (priority by affected count)
  - FIRE family definition backfill (62 in-force UK laws)
  - Next family investigation (Maritime, Construction, Environmental, etc.)
---

# Session: Fire Domain Definition QA (CLOSED)

## Problem

Definition parser and resolver bugs are being surfaced family-by-family. OH&S was investigated in the Resolution Diagnostic session (6 open bugs logged). Now shifting to the FIRE domain — two families with 353 laws but only 56 parsed (16%). Of 1,467 definitions found, 66 cross-references are all unlinked. **This session is investigation-only** — find bugs, classify them, log in frontmatter. Fixing is a separate session; prior sessions proved find+fix in the same session is incompatible.

Families in scope:
- **FIRE** — 94 laws, 23 parsed, 405 definitions
- **FIRE: Dangerous and Explosive Substances** — 259 laws, 33 parsed, 1,062 definitions

## Todo

- ✅ Run diagnostic against FIRE families — 145 findings across 5 categories (not 66 — diagnostic targets `references_other_law=true, citation=false`)
- ✅ Drill into each diagnostic category — sampled all, identified 8 new bug patterns
- ✅ Investigate citation extractor patterns specific to FIRE domain
- ✅ Investigate parser coverage gaps — 297 unparsed: 59 Australian (not parseable), 91 revoked, 62 in-force UK (backfill candidates), 85 other
- ✅ Log all discovered bugs in frontmatter (8 new bugs logged)

## Dependencies

- ✅ Resolution Diagnostic — diagnostic module built, bugs-in-frontmatter workflow established (2026-08-17)
- ✅ Root Resolver Architecture — 6-module decomposition (2026-08-17)
- ✅ Definition Parser Architecture — 6 modules, section_id bug fixed (2026-08-17)
- ✅ Definition Data QA — re-parse + re-resolve complete, persister bugs fixed (2026-08-17, suspended)

## Baseline

| Family | Laws | Parsed | Defs | Cross-refs | Unlinked |
|--------|------|--------|------|------------|----------|
| FIRE | 94 | 23 (24%) | 405 | 22 | 22 (100%) |
| FIRE: Dangerous and Explosive Substances | 259 | 33 (13%) | 1,062 | 44 | 44 (100%) |
| **Total** | **353** | **56 (16%)** | **1,467** | **66** | **66 (100%)** |

## Open bugs from prior sessions

6 open bugs (from Resolution Diagnostic) — confirmed surfacing in FIRE families:
- `internal_ref?` not catching genuine internal refs (est. 1,000 affected) — **confirmed: ~35 of FIRE's 53 no_citation items are internal refs**
- Short-name citations (TCPA 1990) not extracted (est. 500 affected)
- HSWA cited without "etc." — title_index miss (19 affected) — **confirmed: 1 FIRE item (Health and Safety at Work Act 1974 without "etc.")**
- Mangled EU citation — article ref captured as law title (9 affected)
- `extract_named_law` strips preamble too aggressively (2 affected)
- Consolidated Act mismatch (2 affected)

## Diagnostic Results

Diagnostic run against FIRE families: **145 findings** (not 66 — diagnostic targets `references_other_law=true, citation=false`, a broader population than `citation=true` unlinked xrefs).

| Category | Count | Key patterns |
|----------|-------|-------------|
| `no_citation` | 53 | ~35 internal refs (known), ~6 def-list bleed, ~6 non-standard citations, ~6 concatenated/truncated |
| `term_not_found` | 44 | Parent parsed but term absent — parser coverage gaps (e.g. "public road" not in Highways Act, "fire and rescue authority" not in FRS Act), 2 parents with 0 defs |
| `parent_unparsed` | 26 | Coverage gap — law in LRT but not parsed. Not a bug, just backfill needed |
| `parent_not_in_lrt` | 20 | 3 regex-strips-title, 2 NI-abbreviation, 1 HSWA-etc, 1 means-prefix, 1 asp-suffix, 2 FRS-abbreviation, 10 genuinely not in LRT |
| `term_normalisation` | 2 | "at work" → "article for use at work" — false near-miss |

### Highest-impact bugs by affected count (corpus-wide)

| Bug | Affected | Module |
|-----|----------|--------|
| Title-stripping regex matches words in law titles | ~295 | resolve_law_name |
| Definition list items bleed together | 155 defs / 58 laws | DefinitionParser |
| "(NI)" abbreviation not matched | 16 | normalise_title |
| Citation "means" prefix captured | 14 | CitationExtractor |
| Concatenated terms ("workat work") | 6 | DefinitionParser |
| "(asp N)" suffix pollutes lookup | 6 | CitationExtractor |
| Silent parser failure (0 defs) | 2+ laws | DefinitionParser |
| "FRS" abbreviation not in title_index | 2 | Indexes |

## Parse Coverage Gap

297 FIRE laws are unparsed. Breakdown:

| Category | Count | Notes |
|----------|-------|-------|
| Australian (act/reg/cop/li) | 59 | Not parseable from legislation.gov.uk |
| Revoked/Repealed | 91 | Low priority |
| In-force UK (uksi/ssi/nisr/wsi/ukpga/uksro/eur/rule) | 62 | Backfill candidates |
| Unknown/NULL status | 68 | Need status classification |
| Partially revoked | 17 | Medium priority |

The 62 in-force UK laws are parseable but just haven't been run through the parser. This is a backfill task, not a bug. Priority order: uksi (26), ssi (12), nisr (10), uksro (5), wsi (3), rule (3), ukpga (2), eur (1).
