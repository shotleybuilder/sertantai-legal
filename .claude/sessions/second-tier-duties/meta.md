# Meta Session: Second-Tier Duties

**Started**: 2026-07-15
**Plan**: `.claude/plans/second-tier-duties.md`

Meta session — stays open while daughter sessions implement each phase.
Another Claude instance is concurrently working on Baserow sync (no conflict).

## Phases (from plan)
- [x] Phase 1: Data Model & Manual Registration (4221961, 2026-07-15)
- [x] Phase 2: Provision Parsing (422d45c..0002f05, 2026-07-15)
- [ ] Phase 3: Enrichment & Controls
- [ ] Phase 4: Sync & Templates
- [ ] Phase 5: Applicability Automation

## Daughter Sessions
- [x] [phase-1-data-model.md](phase-1-data-model.md) — 3 resources, 4 migrations, 29 ACoPs seeded
- [x] [phase-2-provision-parsing.md](phase-2-provision-parsing.md) — profile-based PDF parser, 5 documents, 887 provisions
- [x] [phase-2b-hsg-and-jsp-corpus.md](phase-2b-hsg-and-jsp-corpus.md) — full JSP corpus, 167 PDFs, 13,143 provisions, actor model analysis
- [x] [issue-123-section-id-collision.md](issue-123-section-id-collision.md) — per-chapter source registration fix, 13,854 provisions restored

## Decisions Log
- `legal_weight` enum added to SecondarySource schema (reverse_burden | regard_had_to | contractual | state_of_art | best_practice)
- `text_source` enum added to SecondarySourceProvision (full_text | summary | heading_only)
- `secondary_section_id` added to SourceLink for provision-to-provision traceability
- Section_id convention: `{TYPE}_{issuer}_{year}_{id}:{locator}` (4 segments before colon)
- PDF toolchain: `extractous_ex` (try first) + `ex_pdfium` (fallback) — stays in sertantai-legal
- PARKED: DRRP on non-legislative text, cross-tier reporting, change detection for secondary sources

## Notes
- ACoPs/JSPs feed into controls that anchor to statutory duties — no parallel obligation hierarchy
- ~30 current HSE ACoPs — manual seed is a one-afternoon job
