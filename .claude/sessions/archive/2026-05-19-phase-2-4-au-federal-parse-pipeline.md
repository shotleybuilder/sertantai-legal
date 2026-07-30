---
session: Phase 2.4 — AU Federal Parse Pipeline
status: closed
opened: 2026-05-19
closed: 2026-05-19
---
# Title: Phase 2.4 — AU Federal Parse Pipeline

**Started**: 2026-05-19
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Context
143 federal AU records have canonical IDs and source_urls from Phase 2.3.
Now deepen enrichment with relationships and status history.

## API Findings
- `Titles` endpoint: metadata + status transitions (already harvested in 2.3)
- `Versions` endpoint: **has amendment relationships** in `reasons[]` array
  - Each version = a point-in-time compilation
  - `reasons[].affect` = "Amend" 
  - `reasons[].affectedByTitle.titleId` = amending law ID
  - `reasons[].affectedByTitle.name` = amending law title
  - `reasons[].affectedByTitle.provisions` = specific provisions
- `Affect` endpoint: 404 (restricted/internal only)

## Todo
- [x] Research Versions endpoint structure
- [x] Add `get_versions/1`, `get_recent_versions/1`, `extract_relationships/1` to FederalClient
- [x] Build `mix au.enrich_relationships` — 2-pass: collect inbound, derive reverse
- [x] Run against 137 enriched federal records:
  - 87/137 have amended_by (2,201 unique amendment relationships)
  - 14/137 have rescinded_by (repeal data)
  - 1,598 distinct amending laws identified (reverse)
  - 104 records updated, 0 errors
- [x] All 1,227 tests pass
- [x] Set `making_review = 'making'` for 696 ENHESA-sourced Acts/Regs (scopes for future LAT parsing)
- [x] BUG FIX: FunctionCalculator.add_making was setting function.Making from making_review/making_classification — Making ONLY from is_making=true now. Fixed 20 UK + 4 AU records.
- [x] Updated plan: Phase 2.8 now includes relationship chain harvesting

**Ended**: 2026-05-19
**Commits**: (pending)

## Pipeline Status vs UK Parity

| Field | UK | AU Federal | AU State | Notes |
|-------|-----|-----------|----------|-------|
| title, year, number | ✅ | ✅ (143) | partial | |
| source_url | ✅ | ✅ | ❌ (Phase 2.5) | |
| family, family_ii | ✅ | ✅ (98%) | ✅ (98%) | from seed categories |
| live status | ✅ | ✅ | ❌ | |
| amended_by | ✅ | ✅ (87 records) | ❌ | |
| amending | ✅ | partial (4) | ❌ | most amending laws not in register yet |
| rescinded_by | ✅ | ✅ (14) | ❌ | |
| making_review | ✅ | ✅ (696) | ✅ | ENHESA source = curated making |
| is_making | ✅ | ❌ | ❌ | needs LAT parsing |
| function | ✅ | ❌ | ❌ | needs is_making from LAT |
| LAT articles | ✅ | ❌ | ❌ | Phase 2.6+ |
| duty_holder etc | ✅ | ❌ | ❌ | Phase 2.6 |

## API Data Available

| Field | Source | Direction |
|-------|--------|-----------|
| `amended_by` | Versions.reasons where affect="Amend" | inbound (who changed me) |
| `amending` | **derived** — reverse of amended_by across all records | outbound (what I change) |
| `rescinded_by` | statusHistory.reasons where affect="Repeal" | inbound (who repealed me) |
| `rescinding` | **derived** — reverse of rescinded_by | outbound (what I repeal) |
| `is_amending` | derived — true if law appears in anyone's amended_by | boolean flag |
| `is_rescinding` | derived — true if law appears in anyone's rescinded_by | boolean flag |

The API only gives inbound relationships (on the target law). Outbound relationships
are derived by reversing: if A's version says "amended by B", then B.amending includes A.

## Cascade / New Law Workflow (for Phase 2.8)
- API does NOT expose "what does this law affect" directly
- BUT: `Versions?$filter=registeredAt gt {date}` finds recently recompiled laws
- When a new amending law is published, affected laws get new Versions within days
- Those new Versions list the amending law in `reasons[]`
- So the cascade is: poll recent Versions → find new compilations → extract relationships
- Tested: works (found today's amendments via registeredAt query)

## Notes
- Versions endpoint gives compilationNumber, date ranges, provisions
- Each version can have multiple reasons (multiple amending Acts in one compilation)
- Affect types confirmed: "Amend" (on Versions), "Repeal" (on Titles.statusHistory)
- Build both directions in a single pass: collect all relationships, then write both sides
- `Affect` endpoint and `_AffectsSearch` both return 404 (restricted/internal)
- `isPrincipal: false` on Titles marks amending legislation (not principal Acts)
