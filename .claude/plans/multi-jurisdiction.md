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

### 2.1 — AU Country Module (done 2026-05-18)

- Countries.Au module: 24 type codes, 9 jurisdictions, 35 families, 48 actor patterns
- AU partitions: legal_register_au + legal_articles_au
- 16 tests

### 2.2 — AU Seed Import (done 2026-05-19)

- `mix au.import_seed` — parsed markdown seed, 891 records imported
- Category-aware family classification (98.2% coverage)
- Family + family_ii from multi-category entries

### 2.3 — AU Jurisdiction & Federal Enrichment (done 2026-05-19)

- `mix au.import_state` — per-state markdown files assign correct jurisdiction
- State files imported: NSW, NT, VIC, QLD, SA, ACT (TAS/WA not available)
- Jurisdiction: cth dropped from 832 → 177 (79% reclassified to states)
- `Scraper.Au.FederalClient` — OData API client for api.prod.legislation.gov.au
- `mix au.enrich_federal` — 143 federal records enriched with canonical IDs (AU_C2011A00137)
- Fuzzy matching with core-phrase fallback for em-dash/space mismatches
- Type codes stripped of jurisdiction prefix (cth_act → act) — jurisdiction in column only

### 2.4 — AU Federal Parse Pipeline (done 2026-05-19)

- Versions endpoint provides amendment relationships (affect="Amend"/"Repeal")
- `extract_relationships/1` in FederalClient: 87/137 have amended_by, 14 have rescinded_by
- `mix au.enrich_relationships`: 2-pass (collect inbound → derive reverse), 2,201 relationships
- Cascade workflow: poll `Versions?$filter=registeredAt gt {date}` for new compilations
- `making_review = 'making'` set for 696 ENHESA-sourced Acts/Regs (LAT parse scoping)
- BUG FIX: FunctionCalculator.add_making was incorrectly driven by making_review/making_classification — now only by is_making=true

### 2.5 — AU State Portal Parsers (done 2026-05-20)

Per-state enrichment using different approaches per portal:

| Jurisdiction | Approach | Records | Enriched | Repealed |
|---|---|---|---|---|
| cth | OData API | 178 | 138 | 14 |
| NSW | Atom feed + manual annotation | 176 | 126 | 12 |
| QLD | In-force legislative tables (browser) + manual | 133 | 110 | 26 |
| ACT | HTML scraping client + manual annotation | 104 | 65 | 43 |
| VIC | Title-slug URL verification | 116 | 56 | — |
| NT | Title-slug URL verification | 75 | 47 | — |
| SA | Blocked (Cloudflare + PDF only) | 104 | 2 | 1 |
| **Total** | | **887** | **544 (61%)** | **99+** |

Key tools built:
- `Scraper.Au.NswFeedClient` — Atom feed bypasses NSW 403 block
- `Scraper.Au.ActClient` — HTML scraping for metadata (status, dates)
- `mix au.enrich_state` — supports slug, feed, and metadata-scraping portals
- `mix au.apply_nsw_annotations` — applies manually annotated NSW data
- Dry-run comparison mode flags DB vs website status conflicts

Type taxonomy expanded: ni (Notifiable Instrument), di (Disallowable Instrument), epi (Environmental Planning Instrument), obj (Objective), nepm (NEPM)

**Major finding: ENHESA seed data staleness**
- ACT: 66% of verified laws are repealed (43/65)
- 99+ laws confirmed repealed across all states
- Many seed laws replaced by newer versions not in the ENHESA export
- Pre-2025 ACT Determinations (21) deleted — remade annually

### 2.6 — AU Taxa & Enrichment

- AU-specific making/function detection rules
- Duty type classification (PCBU model)
- Modern Award handling
- Sunsetting date tracking for legislative instruments
- Victoria OHS Act special handling (non-harmonised)

### 2.7 — Frontend AU Integration & Verification (done 2026-05-21)

**Architecture decision**: Single Electric shape on parent `legal_register` table (all countries).
PGlite constraint: only one shape per local table — rules out shape-per-country to same table.
Evolution: same pattern, add WHERE clause for customer scoping (country + family + profile).

**Done**:
- PGlite table renamed `uk_lrt` → `laws` (schema v16)
- Single shape sync: 20,379 records (19,492 UK + 887 AU) in one subscription
- Country selector in admin nav bar (store-driven, persists across pages)
- LRT page collection recreates on country switch — 887 AU records visible
- All PGlite SQL queries updated with `WHERE country = $selectedCountry`

**Follow-ups** (not blocking):
- Active gridlite view doesn't auto-refresh on country switch (need to click a view)
- Page title still says "UK LRT Data" regardless of country
- Browse page not yet wired for country reactivity
- AU data quality: wrong family allocations and missing type content visible

**Multi-service sync architecture**:
- **-legal** (admin): single unscoped shape, all countries, local filter
- **-hub**: needs `countries` in entitlement + sync profile (not yet built)
- **-compliance**: WHERE-scoped shape from profile (country + family + fitness)

### 2.8 — AU Law Discovery & Monitoring

Three workflows for expanding and maintaining the AU register:

**Harvesting from relationship chains (highest value):**
- Extract unique title_ids from amended_by/rescinded_by across all records
- Filter out laws already in register → candidates for import
- Priority: recent amending laws, especially those that repeal/revoke
- 2,201 amendment relationships collected → ~1,598 candidate laws

**Discovering existing laws not in seed:**
- Query federal OData API `Titles` endpoint with EHS/HR-relevant filters
- Compare against existing records — import new finds

**Monitoring for newly published laws:**
- Query `Versions?$filter=registeredAt gt {last_check}` for recently recompiled laws
- New compilations list the amending law in `reasons` — cascade handled by register
- State monitoring: QLD feed (`feed?id=newinforce`), ACT HTML scraping

---

## Session Sizing Notes

Each numbered stage maps to one development session. Stages within a phase are sequential — each builds on the previous.
