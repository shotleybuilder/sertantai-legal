# Title: Phase 1.4 — Scraper Abstraction

**Started**: 2026-05-18
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Todo
- [x] Audit scraper modules to identify what's UK-specific vs generic

## Audit Findings

**~35 files in `lib/sertantai_legal/scraper/`**

### Generic infrastructure (reusable, stay in place)
- `persister.ex` — creates LegalRegister records
- `storage.ex` — JSON file storage for session data
- `session_manager.ex` — session lifecycle
- `change_logger.ex` — field change tracking
- `categorizer.ex` — group 1/2/3 logic
- `filters.ex` — title exclusion filtering
- `resources/` — ScrapeSession, ScrapeSessionRecord, CascadeAffectedLaw Ash resources
- `enacted_by/matcher.ex`, `enacted_by/metrics.ex` — generic matching engine

### UK-specific (30 files) — everything else
- `legislation_gov_uk/` — HTTP client, XML parser, helpers (already namespaced)
- `metadata.ex`, `extent.ex`, `amending.ex`, `enacted_by.ex` — legislation.gov.uk XML fetching
- `staged_parser.ex`, `law_parser.ex` — orchestrate UK scraping stages
- `lat_parser.ex`, `lat_staged_parser.ex`, `commentary_parser.ex` — UK XML parsing
- `type_class.ex`, `id_field.ex`, `new_laws.ex` — UK law identification
- `models.ex`, `terms/`, `tags.ex` — UK legal vocabulary/SI codes
- `parsed_law.ex` — UK field mapping

### Recommendation: DON'T mass-move files

Moving 30 files into `Scraper.Uk/` would touch every import, alias, and test
across the codebase — high risk, low value. Instead:
1. UK scraper code stays in `Scraper/` (it works, it's the default)
2. `legislation_gov_uk/` is already correctly namespaced
3. When AU scraper is added (Phase 2.2), create `Scraper.Au/` alongside
4. Both use shared generic infrastructure (persister, storage, sessions)
5. No behaviour needed — UK and AU scrapers are too different to share an interface

## Notes
- Phase 1.4 is effectively complete by audit — the architecture is already sound
- The existing `legislation_gov_uk/` subdirectory proves the namespace pattern works
- AU will get `legislation_gov_au/` or similar when Phase 2 begins
- Generic infra (persister, storage, sessions) confirmed ready for multi-country use

**Ended**: 2026-05-18
**Commits**: None (audit-only session, plan updated)
