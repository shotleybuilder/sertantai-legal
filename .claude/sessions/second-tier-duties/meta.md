# Meta Session: Second-Tier Duties

**Started**: 2026-07-15
**Plan**: `.claude/plans/second-tier-duties.md`

Meta session — stays open while daughter sessions implement each phase.
Another Claude instance is concurrently working on Baserow sync (no conflict).

## Phases (from plan)
- [x] Phase 1: Data Model & Manual Registration (4221961, 2026-07-15)
- [x] Phase 2: Provision Parsing (422d45c..0002f05, 2026-07-15)
- [x] Phase 3: Enrichment & Controls (queryables only — subscription later)
- [ ] Phase 4: Sync & Templates
- [ ] Phase 5: Applicability Automation

## Daughter Sessions
- [x] [phase-1-data-model.md](phase-1-data-model.md) — 3 resources, 4 migrations, 29 ACoPs seeded
- [x] [phase-2-provision-parsing.md](phase-2-provision-parsing.md) — profile-based PDF parser, 5 documents, 887 provisions
- [x] [phase-2b-hsg-and-jsp-corpus.md](phase-2b-hsg-and-jsp-corpus.md) — full JSP corpus, 167 PDFs, 13,143 provisions, actor model analysis
- [x] [issue-123-section-id-collision.md](issue-123-section-id-collision.md) — per-chapter source registration fix, 13,854 provisions restored
- [x] [parse-acops.md](parse-acops.md) — 21 ACoPs parsed, 12,321 provisions, 100% current coverage
- [x] [parse-hsgs.md](parse-hsgs.md) — 29 HSGs parsed, 19,454 provisions, OGL confirmed
- [x] [parse-environmental-guidance.md](parse-environmental-guidance.md) — DEFERRED: research captured, landscape too fragmented
- [x] [phase-3-zenoh-queryables.md](phase-3-zenoh-queryables.md) — 3 queryables for secondary sources/provisions, spec published

### Ad-hoc additions
- HSR25 (Electricity at Work Regs guidance) — 747 provisions, linked to UK_uksi_1989_635
- HSR29 (Dangerous Substances Notification/Marking) — 305 provisions, linked to UK_uksi_1990_304

## Snagging List
- [ ] Update chapter source titles from parsed headings (e.g. "Chapter 23" → "Chapter 23: Electrical Safety")
- [ ] `mix secondary.list --tree` provision count queries are N+1 — optimise for large corpus
- [ ] L44 (Electrical Testing ACoP) not downloadable — no provisions parsed
- [ ] JSP-319 parked (ODT-only) — needs LibreOffice or text-based classifier
- [ ] JSP-520 volumes marked withdrawn — may be replaced, monitor
- [ ] `mix secondary.qa` tooling not built
- [ ] Withdrawn ACoP seed records (L1, L21, L44, L127, L134-137) still in DB with 0 provisions — clean up or mark withdrawn
- [ ] Scan for more HSR series publications (regulation guidance — stronger than HSG)

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
