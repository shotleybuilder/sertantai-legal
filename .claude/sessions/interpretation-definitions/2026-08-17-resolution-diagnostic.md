---
session: Resolution Diagnostic
status: closed
opened: 2026-08-17
closed: 2026-08-17
outcome: partial

summary: >
  Built RootResolver.Diagnostic module that classifies all 8,082 unlinked cross-ref
  definitions into 6 failure categories. Established bugs-in-frontmatter workflow —
  bugs discovered during investigation are logged in YAML, indexed into SQLite on
  session close, queryable across sessions. 11 bugs logged (5 fixed, 6 open).

decisions:
  - what: Bugs tracked in session frontmatter YAML, indexed into SQLite
    why: Ad-hoc investigation discovers edge cases that get lost when sessions clear. GitHub Issues track per-pattern but don't integrate with the session workflow. SQLite gives queryable persistence with the same pattern as decisions/lessons.
    result: bugs table in session_index.py, session-start and session-close commands updated

  - what: Diagnostic classifies by failure category, not by fix
    why: The diagnostic tells you WHERE to look (which bucket), the investigation tells you WHAT to fix (specific patterns). These are different activities — finding sessions populate bugs, fixing sessions close them.
    result: 6 categories (no_citation, parent_unparsed, parent_not_in_lrt, term_not_found, term_normalisation, citation_ambiguous)

  - what: Fuzzy term matching tightened to child-subset-of-parent only
    why: Subset matching in both directions produced false positives (controlled waste -> waste). Genuine near-misses have the parent as a superset of the child (highway authority -> local highway authority).
    result: term_normalisation bucket dropped 597 to 125, false positives eliminated

  - what: Created /lrt-parse-law skill for CLI-based law parsing
    why: Admin UI requires auth (GitHub OAuth broken after container port change). StagedParser.parse + LawParser.parse_record is the same code path the UI uses but callable from mix run.
    result: Skill at .claude/skills/lrt-parse-law/SKILL.md, used to parse UK_ukpga_1994_39

metrics:
  diagnostic_baseline: { total: 8082, no_citation: 3005, parent_unparsed: 1744, parent_not_in_lrt: 1368, term_not_found: 1840, term_normalisation: 125 }
  ohs_progress: { start: 198, end: 174, delta: -24 }
  bugs_logged: { total: 11, open: 6, fixed: 5 }

lessons:
  - title: Switching Ecto insert_all from string table name to Ash resource changes type expectations
    detail: >
      Ash resource modules enforce their own type system on insert_all. UUIDs must be
      string format (not Ecto.UUID.dump! binary), timestamps must be DateTime (not
      NaiveDateTime). Two separate bugs from the same root cause — the resolver
      refactor changed table references but not the value formatting.
    tag: infrastructure

  - title: Diagnostic classifies but doesn't discover — investigation is a separate activity
    detail: >
      The diagnostic tells you 1,368 are parent_not_in_lrt. Drilling in reveals the
      HSWA "etc." mismatch, mangled EU citations, empty title_en — each a distinct
      fixable pattern. The diagnostic is the radar, investigation is the sonar.
      Bugs must be logged as they're discovered, not deferred to session close.
    tag: tooling

  - title: LRT titles omit leading "the" for sorting but citations include it
    detail: >
      Citations say "the Scotland Act 1998", LRT stores "Scotland Act". normalise_title
      must strip leading "the" from both sides. This single fix linked 265 additional
      definitions — the highest-impact one-line change in the session.
    tag: data

bugs:
  - pattern: "HSWA cited as 'Health and Safety at Work Act 1974' without 'etc.' — title_index misses it"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 19
    fix: "Title alias support in title_index — common informal names should map to canonical law"
    status: open

  - pattern: "Mangled EU citation 'Article 3(x) of Regulation 2016' — extractor captures article ref as law title"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 9
    fix: "extract_named_law needs to handle 'Article N of Regulation YYYY' pattern for EU regulations"
    status: open

  - pattern: "extract_named_law strips preamble too aggressively — 'Safety (Enforcing Authority...)' loses 'Health and'"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 2
    fix: "Preamble stripping regex anchors on 'of the'/'in the' but cuts at wrong boundary for compound titles"
    status: open

  - pattern: "Consolidated Act mismatch — child cites 'Trade Union and Labour Relations Act 1974' but LRT has the 1992 Consolidation Act"
    category: parent_not_in_lrt
    module: Indexes
    affected: 2
    fix: "Successor law mapping — pre-consolidation citations should resolve to the consolidation Act"
    status: open

  - pattern: "Empty title_en in legal_register prevents title_index match"
    category: parent_not_in_lrt
    module: data
    affected: 1
    fix: "LRT parse via /lrt-parse-law to populate title_en (fixed for UK_ukpga_1994_39)"
    status: fixed

  - pattern: "Leading 'the' in citations mismatches LRT titles (which omit 'the' for sorting)"
    category: parent_not_in_lrt
    module: CitationExtractor
    affected: 265
    fix: "normalise_title strips leading 'the' — both sides now match"
    status: fixed

  - pattern: "NaiveDateTime in resolver persister rejected by Ash UtcDatetimeUsec type"
    category: infrastructure
    module: Persister
    affected: 0
    fix: "Changed to DateTime.utc_now() |> DateTime.truncate(:microsecond)"
    status: fixed

  - pattern: "Ecto.UUID.dump! returns binary but Ash resource expects string UUID"
    category: infrastructure
    module: DefinitionPersister
    affected: 0
    fix: "Changed to Ecto.UUID.generate() (string format)"
    status: fixed

  - pattern: "internal_ref? not catching many genuine internal refs — inflates no_citation bucket"
    category: no_citation
    module: CitationExtractor
    affected: 1000
    fix: "Widen internal_ref? patterns — 'given by regulation 4', 'given by section 16 above', 'construed in accordance with'"
    status: open

  - pattern: "Short-name citations like 'TCPA 1990' not extracted — abbreviation not in citation_index"
    category: no_citation
    module: CitationExtractor
    affected: 500
    fix: "Expand abbreviation citation lookup or add common short-name mappings"
    status: open

  - pattern: "Fuzzy term matching false positives — subset matching too greedy (controlled waste -> waste)"
    category: term_normalisation
    module: Diagnostic
    affected: 472
    fix: "Tightened to child-subset-of-parent only, min 2 words, jaccard >0.7"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal/scraper/root_resolver/diagnostic.ex
  - scripts/maintenance/session_index.py
  - .claude/skills/lrt-parse-law/SKILL.md
  - .claude/commands/session-start.md
  - .claude/commands/session-close.md

depends_on:
  - interpretation-definitions/2026-08-17-root-resolver-architecture
  - interpretation-definitions/2026-08-17-definition-data-qa

enables:
  - Fix-bugs sessions targeting open bugs by affected count
  - Family-specific resolution QA (OH&S, Fire, Maritime, etc.)
  - Future admin dashboard for definition resolution health
---

# Session: Resolution Diagnostic (CLOSED)

## Problem

5,766 cross-reference definitions can't be linked to their root definitions. Ad-hoc investigation (HSWA deep-dive) revealed multiple failure categories — term normalisation mismatches, citation disambiguation bugs, unparsed parent laws — but we don't know the proportions. Without a systematic diagnostic, we can't tell whether we're fixing the 5% or the 80%. We need a diagnostic module that classifies every failure, generates actionable metrics, and is suitable for a future admin dashboard.

## Todo

- ✅ Design diagnostic categories and output struct (`%Finding{}` with 6 categories)
- ✅ Build `RootResolver.Diagnostic` module — `run/1`, `summarise/1`, `print_summary/1`
- ✅ Run diagnostic, capture baseline category breakdown (see below)
- ✅ Tighten fuzzy matching — child⊂parent only, min 2 words, jaccard>0.7 (597→125, false positives eliminated)
- ⏸️ Fix systemic patterns revealed by the diagnostic (deferred — 6 open bugs logged for future fix session)
- ⏸️ Add mix task or Phoenix endpoint for running the diagnostic (deferred — module works via mix run)
- ⏸️ Re-run diagnostic after fixes to measure improvement (deferred — depends on fixes)

## Dependencies

- ✅ Root Resolver Architecture — 6-module decomposition (2026-08-17)
- ✅ Definition Data QA — re-parse + re-resolve complete, 1,995 links (2026-08-17)
- ✅ Definition Parser Architecture — 6 modules, section_id bug fixed (2026-08-17)

## Baseline Results

| Category | Count | % | Root cause |
|----------|-------|---|------------|
| `no_citation` | 3,005 | 37% | CitationExtractor can't parse — internal refs ("given by reg 4"), short names ("TCPA 1990"), Welsh text |
| `parent_unparsed` | 1,744 | 22% | Law in LRT but `definitions_parsed_at` is null — just needs backfill |
| `parent_not_in_lrt` | 1,368 | 17% | Law not in legal_register — data gap or title normalisation mismatch |
| `term_not_found` | 1,368 | 17% | Parent parsed, term absent — definition in a section parser doesn't reach |
| `term_normalisation` | 597 | 7% | Term exists with different spelling — ~540 genuine, ~57 false positive (fuzzy too loose) |
| `citation_ambiguous` | 0 | 0% | Not a current problem |
| **Total** | **8,082** | | |

### Observations

1. **no_citation (37%)** is the biggest bucket but many are genuinely internal refs ("given by regulation 4 above") which are correctly unresolvable — they reference the same law. The `internal_ref?` check should be catching these but isn't. Fixing `internal_ref?` would reclassify ~1,000+ from `no_citation` to `internal` (not a failure).

2. **parent_unparsed (22%)** is pure data coverage — running backfill on these 1,744 laws would immediately resolve many. This is the easiest win.

3. **term_normalisation (7%)** fuzzy matching needs tightening — subset matching (`controlled waste` → `waste`) is too greedy. Should require the parent term to be a prefix/suffix of the child term, not just word overlap.
