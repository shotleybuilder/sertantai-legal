---
session: Root Definitions
status: suspended
opened: 2026-08-15
---

# Session: Root Definitions (SUSPENDED)

## Problem

The applicability sidebar shows definitions as a flat list — click "owner" and get 282 entries. Most are near-identical cross-references to a parent law ("has the meaning given in..."). The user needs 2-3 contextually relevant definitions, not a wall of text. Root definitions collapse the list by linking derivative definitions to their originating source (e.g., 30 "scotland" definitions → Scotland Act 1998 s.126(1)).

## Todo

- ✅ Migration: add `root_definition_id` (self-FK) + `referenced_law_citation` (text) to `legislative_definitions`
- ✅ Root resolution logic: `SertantaiLegal.Scraper.RootResolver` — extracts citation, resolves to root row via in-memory indexes
- ✅ Populate: `RootResolver.resolve_all()` — 700 linked, 4,193 citations extracted (awaiting parent parse)
- ✅ Coverage report: see results below
- ✅ Parser Strategy 3: extract `<Term>` definitions from section-level provisions (not just Interpretation sections)
- ⬜ Targeted backfill: fetch specific sections/parts from legislation.gov.uk using `referenced_law_citation`
- ⬜ API: update definitions endpoint to expose root linkage for sidebar collapse

## Dependencies

- ✅ Definition Schema & Storage (34K rows imported)
- ✅ Definition Parser (66K total definitions after backfill)
- ✅ Definition API (REST + Zenoh endpoints)
- ⬜ Definition Backfill & QA (suspended — 1,086 empty-def bugs outstanding, not blocking this work)

## Design Decision

**Self-referential FK** over a separate `definition_roots` table. The root definition already exists as a row in the parent law (e.g., Scotland Act 1998's definition of "scotland"). Pointing to it avoids duplicating data and a curation burden. Domain context comes from `legal_register.family`/`family_ii` via join — no need for a `domain` column on definitions.

Multi-root terms (like "owner") naturally emerge: each self-contained definition with `root_definition_id IS NULL` is a root in its own right, contextualised by the family of its source law.

## Resolution Results (2026-08-15)

| Metric | Count |
|--------|-------|
| Total definitions | 66,496 |
| Root-linked (`root_definition_id` set) | 700 |
| Citation extracted (awaiting parent parse) | 4,193 |
| Distinct root targets | 344 |
| Self-contained roots (not a xref) | 56,241 |
| Internal refs (same-law, e.g. "given by reg. 3") | 1,799 |
| Unresolved (couldn't extract citation) | 521 |

**Sidebar impact example — "owner" (282 definitions)**:
- Before: 282 flat entries
- After: 2 root definitions (Acquisition of Land Act with 117 derivations, Quarries NI Order with 1), plus remaining self-contained defs grouped by family

**Next step**: Parse top parent Acts (Highways Act 1980, Scotland Act 1998, Companies Act 2006, Electronic Communications Act 2000, Interpretation Act 1978) in a LAT session. Re-running `RootResolver.resolve_all(force: true)` after parsing will link the 4,193 citation-only definitions.

## Resume Notes

**Status (2026-08-15)**: Schema, resolver, and parser Strategy 3 are in place. 908 definitions linked to roots, 4,893 citations extracted. Working approach going forward is **child → parent for individual laws**: pick a specific unresolved cross-ref, use its `referenced_law_citation` to fetch the exact section/part from legislation.gov.uk, examine the XML structure, add parser support for any new definition patterns (TDD — fixture first, failing test, then fix), and re-resolve.

**Approach**:
1. Pick an unresolved term (e.g. "street authority" → NRSWA 1991 s.49)
2. Fetch the specific section/part XML from legislation.gov.uk API (`/ukpga/1991/22/section/49/data.xml`)
3. Save as test fixture, write failing test for the new definition pattern
4. Update parser until test passes
5. Run targeted backfill + re-resolve

**Not to do**: Bulk backfill of 665 parent laws — 311 were already parsed (the term just isn't in their Interpretation section). The right approach is targeted fetching of specific sections referenced in the citations, not whole-body re-parses.

**Key files**:
- `backend/lib/sertantai_legal/scraper/root_resolver.ex` — resolution logic, writes missing parents file
- `backend/lib/sertantai_legal/scraper/definition_parser.ex` — Strategy 3 added for section-level `<Term>` definitions
- `backend/priv/repo/migrations/20260815185849_add_root_definition_fields.exs` — `root_definition_id` + `referenced_law_citation`
- `backend/test/sertantai_legal/scraper/definition_parser_test.exs` — new section-level test
