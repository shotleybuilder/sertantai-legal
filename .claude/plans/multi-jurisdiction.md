# Multi-Jurisdiction Legal Register

**Created**: 2026-05-17
**Goal**: Extend sertantai-legal from UK-only to multi-country, starting with Australia EHS & HR
**Research**: `.claude/sessions/2026-05-17-australian-ehs-hr-research.md`

---

## Phase 1: Generic Multi-Jurisdiction Architecture

Generalise the platform so that any second country can be added. No AU-specific work yet — just remove UK assumptions and introduce the country/jurisdiction abstraction.

### 1.1 — Schema Migration: `uk_lrt` → `legal_register` (partitioned)

- Create partitioned `legal_register` table with `country` + `jurisdiction` columns
- Migrate all UK data from `uk_lrt` into `legal_register_uk` partition
- Replace `leg_gov_uk_url` generated column with `source_url` (populated per-country)
- Update `lat` → `legal_articles` with same partition pattern
- Update `amendment_annotations` similarly
- Update `law_edges` foreign keys
- Keep old tables as views temporarily for backwards compatibility during transition

### 1.2 — Backend Resource Generalisation

- New Ash resource: `SertantaiLegal.Legal.LegalRegister` (replaces `UkLrt`)
- Update all actions/queries to include `country` context
- Generalise API routes: `/api/uk-lrt/*` → `/api/laws/*` (with country filter param)
- Update LAT resource and amendment annotation resources
- Ensure all existing UK functionality works unchanged through new resource

### 1.3 — Country Module Pattern

- Introduce `SertantaiLegal.Countries.Uk` module (extracts existing UK-specific logic)
  - Type codes + descriptions
  - Geographic extent codes + labels
  - Family taxonomy (move from `family_rules.ex`)
  - Actor definitions (move from `actor_definitions.ex`)
  - Source URL builder (legislation.gov.uk)
- Define country behaviour/protocol that new countries must implement
- Existing taxa modules (`making_detector`, `purpose_classifier`, `function_calculator`) become UK-namespaced
- **Deferred from 1.2**: Update internal `UkLrt` references in scraper/taxa/zenoh modules to use `LegalRegister`:
  - `scraper/persister.ex` — creates/updates records via Ash (6 refs)
  - `scraper/staged_parser.ex` — looks up existing record (1 ref)
  - `scraper/law_parser.ex` — looks up existing record (2 refs)
  - `scraper/lat_session_manager.ex` — queries for making classification (2 refs)
  - `scraper/reparse_manager.ex` — looks up/updates records (2 refs)
  - `legal/function_calculator.ex` — persists function results (6 refs)
  - `zenoh/data_server.ex` — Ecto queries for P2P publishing (4 refs)
  - `zenoh/taxa_subscriber.ex` — upserts taxa fields (1 ref)
  - `legal/lat.ex` — belongs_to relationship (1 ref, update to LegalRegister)

### 1.4 — Scraper Abstraction (SKIPPED — audit found no work needed)

Audit (2026-05-18) concluded: 30 of 35 scraper files are UK-specific. Mass-moving into
`Scraper.Uk/` would touch every alias and test for no architectural gain. Instead:
- UK scraper code stays in `Scraper/` as the default (it works)
- `legislation_gov_uk/` subdirectory is already correctly namespaced
- Generic infrastructure (persister, storage, sessions) confirmed country-agnostic
- When AU scraper is added (Phase 2.2), create `Scraper.Au/` alongside
- No shared behaviour — UK and AU scrapers are architecturally too different

### 1.5 — Frontend Generalisation

- Rename `UkLrtRecord` → `LegalRecord` type
- Replace hardcoded type codes, geo extents, family options with API-driven values (fetched per country)
- Add country selector/filter to browse and admin views
- Generalise API calls: `/api/uk-lrt/` → `/api/laws/?country=uk`
- Update PGlite schema and ElectricSQL shape definitions
- Move `country` column injection from Electric proxy into frontend properly:
  - Add `country` to `UK_LRT_ALL_COLUMNS` / `UK_LRT_ADMIN_COLUMNS` in `sync.ts`
  - Update PGlite `syncShapeToTable` to request `table: 'legal_register_uk'` directly (remove proxy rewrite dependency)
  - Remove `@table_rewrites` and `@extra_pk_columns` from `ElectricProxyController` once frontend handles it natively
- External links driven by country module (not hardcoded legislation.gov.uk)

### 1.6 — Verification & Cleanup

- Dropped 5 `_old` backup tables
- Removed 9 legacy `/api/uk-lrt/*` route aliases
- Views (`uk_lrt`, `lat`) kept — ~70 raw SQL refs depend on them, zero cost
- Production deployment deferred (separate concern)

---

## Phase 1 Summary (completed 2026-05-18)

| Phase | Session | Key Outcome |
|-------|---------|-------------|
| 1.1 | Schema migration | Partitioned `legal_register`/`legal_articles` tables, backwards-compat views |
| 1.2 | Backend resources | `LegalRegister`/`LegalArticle` Ash resources, `/api/laws/` routes, Electric proxy fixes |
| 1.3 | Country module | `Countries.Country` behaviour + `Countries.Uk` implementation, all `UkLrt` refs migrated |
| 1.4 | Scraper audit | Skipped — architecture already sound, AU gets `Scraper.Au/` in Phase 2 |
| 1.5 | Frontend | Direct partition sync, new API routes, `country`+`source_url` in types |
| 1.6 | Cleanup | Dropped `_old` tables, removed legacy `/api/uk-lrt/` routes |

---

## Phase 2: Australian EHS & HR Laws

With the multi-jurisdiction architecture in place, add Australia as the first additional country.

### 2.1 — AU Country Module

- Implement `SertantaiLegal.Countries.Au` module
  - Type codes (cth_act, cth_li, nsw_act, nsw_reg, vic_act, cop, award, etc.)
  - Jurisdiction definitions (cth, nsw, vic, qld, wa, sa, tas, act, nt)
  - Geographic extent logic (federal vs state/territory)
  - Family taxonomy (reuse existing where applicable, add AU-specific: Modern Awards, Superannuation, Anti-Discrimination)
  - Actor definitions (PCBU, workers, officers, Safe Work Australia, Comcare, Fair Work Commission, state regulators)
  - Source URL builders per jurisdiction (legislation.gov.au, legislation.nsw.gov.au, etc.)

### 2.2 — AU Data Acquisition & Scraper

- Build `SertantaiLegal.Scraper.Au` implementing scraper behaviour
- Start with ALRC DataHub CSV import for federal legislation metadata
- Add Queensland API integration (best-documented state API — proves the pattern)
- Scraper adapters for remaining state legislation portals
- Handle Model WHS Act → state implementation linking (`model_law_reference`)
- Initial target: federal EHS + HR laws (~250-350 records)

### 2.3 — AU Data Population & QA

- Create `legal_register_au` partition
- Import initial AU dataset (federal + one state as proof)
- Run family classification (reuse existing families + AU additions)
- Assign duty types, holders, POPIMAR where applicable
- QA pass: verify duty holder concepts map correctly (esp. PCBU)
- Expand to remaining states/territories

### 2.4 — AU-Specific Taxa & Enrichment

- AU-specific making/function detection rules (if needed — may be simpler than UK)
- AU actor definition patterns (state regulators, PCBU variants)
- Modern Award handling (coverage rules, annual wage review tracking)
- Sunsetting date tracking for AU delegated legislation
- Victoria OHS Act special handling (non-harmonised)

### 2.5 — Frontend AU Integration & Verification

- Verify country filter shows AU records in browse/admin views
- AU-specific type code and jurisdiction labels render correctly
- External links route to correct AU legislation portals
- Scrape session workflow works for AU data sources
- LAT parsing tested against AU legislation structure (if applicable)
- End-to-end: AU law appears in screening/applicability workflow

---

## Session Sizing Notes

Each numbered stage (1.1, 1.2, etc.) is scoped as one development session. Stages within a phase are sequential — each builds on the previous. Phase 2 cannot start until Phase 1.6 is verified.
