---
session: Australian EHS & HR Law Research
status: closed
opened: 2026-05-17
closed: 2026-05-17
---
# Title: Australian EHS & HR Law Research

**Started**: 2026-05-17
**Goal**: Research what's needed to include Australian EHS and HR laws in sertantai-legal, reusing existing infrastructure

## Research Todo

### 1. Understand Current UK-Specific Assumptions
- [x] Audit backend schema for UK-specific fields/enums (family, domain, jurisdiction columns)
- [x] Audit frontend for hardcoded UK references (labels, filters, routes)
- [x] Identify UK-specific business logic (scraper, parsers, matching)
- [x] Map which resources are jurisdiction-neutral vs UK-locked

### 2. Australian EHS & HR Law Landscape
- [x] Identify key Australian EHS legislation sources (federal + state/territory)
- [x] Identify key Australian HR/employment legislation sources
- [x] Understand Commonwealth vs State jurisdiction split for EHS and HR
- [x] Identify authoritative data sources / APIs (legislation.gov.au, etc.)
- [x] Assess data format and availability (structured XML? PDF only?)

### 3. Data Model Impact
- [x] Determine if uk_lrt table generalises or needs a parallel table
- [x] Assess jurisdiction/country scoping needed on core resources
- [x] Evaluate family/domain taxonomy differences (AU vs UK classification)
- [x] Check if duty_holder/power_holder/rights_holder patterns apply in AU law
- [x] Consider state/territory vs federal hierarchy modelling

### 4. Data Acquisition Strategy
- [x] Research legislation.gov.au scraping/API feasibility
- [x] Identify any existing AU legal datasets (open data, commercial)
- [x] Estimate record volume for AU EHS + HR laws
- [x] Assess whether existing scraper architecture can be adapted

### 5. Frontend Multi-Jurisdiction Support
- [x] Evaluate jurisdiction switcher/filter needs
- [x] Assess impact on ElectricSQL shapes (jurisdiction filtering)
- [x] Review screening/applicability workflow for AU compatibility
- [x] Check if LRT browse/admin views need jurisdiction awareness

### 6. Infrastructure & Deployment
- [x] Assess database sizing impact
- [x] Consider ElectricSQL shape partitioning by jurisdiction
- [x] Evaluate if AU data needs separate sync cadence
- [x] Check production deployment implications

### 7. Compliance & Accuracy
- [x] Understand AU EHS regulatory update frequency
- [x] Identify key AU EHS/HR regulatory bodies
- [x] Assess currency/staleness risks for AU data
- [x] Consider professional/legal review requirements

---

## Research Findings

### 1. Current UK-Specific Assumptions — Backend

#### Schema / Resources (UK-Locked)

| Resource | Table | UK-Specific Fields | File |
|----------|-------|--------------------|------|
| `UkLrt` | `uk_lrt` | `type_code` (ukpga/uksi/etc), `geo_extent` (E+W+S+NI codes), `si_code`, `family`/`family_ii` (UK taxonomy), `popimar`, `live` | `backend/lib/sertantai_legal/legal/uk_lrt.ex` |
| `Lat` | `lat` | `law_name` (always `UK_` prefix), `extent_code` (UK region codes), FK to `uk_lrt` | `backend/lib/sertantai_legal/legal/lat.ex` |
| `AmendmentAnnotation` | `amendment_annotations` | `id`/`law_name` (always `UK_` prefix), `code_type` enum (F/C/I/E from legislation.gov.uk footnotes) | `backend/lib/sertantai_legal/legal/amendment_annotation.ex` |

#### Hardcoded UK Taxonomies

- **Family Rules** (`family_rules.ex`): 35+ families with emoji-prefixed categories (💙 H&S, 💚 Environment, 💜 HR) — all UK-centric keyword mappings
- **SI Code → Family Mappings** (`scraper/models.ex`): Maps UK Statutory Instrument classification codes to families
- **Type Codes** (`scraper/type_class.ex`): 12 UK legislation type codes (ukpga, uksi, asp, ssi, nia, nisr, wca, anaw, asc, wsi, eur, eudr)
- **Geographic Extents** (`lat/transforms.ex`): E+W+S+NI regional code system with normalisation logic

#### UK-Locked Business Logic

| Module | What It Does | UK Dependency | File |
|--------|-------------|---------------|------|
| `FunctionCalculator` | Classifies law function (Making/Amending/Revoking/Commencing/Enacting) | Classification rules assume UK legislative structure | `legal/function_calculator.ex` |
| `MakingDetector` | Detects if a law creates substantive duties | Base rate (17.3%) from UK corpus; UK title patterns like "(Commencement", "(Amendment" | `legal/taxa/making_detector.ex` |
| `DutyType` | Classifies duty type (Duty/Right/Responsibility/Power) | Values are generic but detection rules assume UK structures | `legal/taxa/duty_type.ex` |
| `ActorDefinitions` | Defines government/governed actor patterns | Hardcoded UK-specific actors (HSE, Scottish Parliament, Welsh Parliament, NI Assembly, Crown, etc.) | `legal/taxa/actor_definitions.ex` |
| `PurposeClassifier` | Classifies purpose from title | UK title conventions ("(Commencement", "(Amendment", "(Revocation") | `legal/taxa/purpose_classifier.ex` |
| `FamilyRules` | Maps keywords → family | UK-specific keyword→family mapping | `legal/family_rules.ex` |

#### Scraper Architecture (legislation.gov.uk Only)

- `scraper/metadata.ex` — Fetches XML from `https://legislation.gov.uk/{type_code}/{year}/{number}/introduction/data.xml`
- `scraper/enacted_by.ex` — Follows parent law links on legislation.gov.uk; hardcoded primary types: `~w[ukpga anaw asp nia apni]`
- `scraper/extent.ex` — Fetches extent from legislation.gov.uk `/contents/` XML
- `scraper/id_field.ex` — All identifiers forced to `UK_` prefix pattern

#### API Routes (UK-Named)

All endpoints use `/api/uk-lrt/` prefix: `GET /uk-lrt`, `GET /uk-lrt/filters`, `GET /uk-lrt/search`, `GET /uk-lrt/:id`, `PATCH /uk-lrt/:id`, etc.

#### Jurisdiction-Neutral Components

- POPIMAR framework (management system model, not jurisdiction-specific)
- Duty/Right/Responsibility/Power classification (concept is generic)
- LAT article parsing architecture (section-level parsing)
- Amendment annotation tracking (concept is generic)
- Law graph / edges (enacted_by, amends relationships)
- ElectricSQL sync infrastructure
- Session management (scrape/parse sessions)

### 2. Current UK-Specific Assumptions — Frontend

#### Hardcoded UK in 6+ Areas

| Area | Files | What's UK-Locked |
|------|-------|-----------------|
| **Table/schema naming** | `electric/uk-lrt-schema.ts`, `pglite/uk-lrt-columns.ts`, `pglite/schema.sql.ts` | `UkLrtRecord` type, `UK_LRT_COLUMN_METADATA` constant, `CREATE TABLE uk_lrt` |
| **Type code options** | `components/parse-review/field-config.ts`, `admin/lrt/+page.svelte`, `admin/scrape/+page.svelte` | Duplicated in 3+ places: ukpga, uksi, asp, ssi, nia, nisr, etc. |
| **Geographic extent** | `field-config.ts`, `admin/lrt/+page.svelte` | E+W+S+NI codes hardcoded |
| **Family/domain values** | `admin/lrt/+page.svelte` (lines 125-184) | 35+ families hardcoded with emoji prefixes |
| **API endpoints** | 3+ route files | All reference `/api/uk-lrt/` |
| **UI labels/headings** | `browse/+page.svelte`, `admin/lrt/+page.svelte` | "UK Legal Register", "UK LRT Data", legislation.gov.uk links |
| **Record name format** | `admin/scrape/cascade/+page.svelte` | `UK_uksi_2025_622` → `uksi/2025/622` conversion assumes `UK_` prefix |

### 3. Australian EHS & HR Law Landscape

#### Jurisdiction Structure

Australia has **9 jurisdictions**: 1 Commonwealth (federal) + 6 states (NSW, VIC, QLD, WA, SA, TAS) + 2 territories (ACT, NT).

**EHS**: Primarily state/territory responsibility, harmonised through Model WHS Act developed by Safe Work Australia.

**HR/Employment**: Substantially federalised under Fair Work Act 2009. All states except WA have referred private-sector IR powers to the Commonwealth. State systems still cover public sector employees.

#### Model WHS Act Adoption

| Jurisdiction | Adopted Model WHS? | Primary Act | Regulator |
|---|---|---|---|
| Commonwealth | Yes (2012) | Work Health and Safety Act 2011 | Comcare |
| NSW | Yes (2012) | Work Health and Safety Act 2011 (NSW) | SafeWork NSW |
| QLD | Yes (2012) | Work Health and Safety Act 2011 (Qld) | WHSQ |
| ACT | Yes (2012) | Work Health and Safety Act 2011 (ACT) | WorkSafe ACT |
| NT | Yes (2012) | WHS (National Uniform Legislation) Act 2011 | NT WorkSafe |
| SA | Yes (2013) | Work Health and Safety Act 2012 (SA) | SafeWork SA |
| TAS | Yes (2013) | Work Health and Safety Act 2012 (Tas) | WorkSafe Tasmania |
| WA | Yes (2022) | Work Health and Safety Act 2020 (WA) | WorkSafe WA |
| **VIC** | **No** | Occupational Health and Safety Act 2004 (Vic) | WorkSafe Victoria |

Victoria is the only non-adopter — operates under its own OHS Act 2004 with similar but distinct obligations.

#### Key Federal HR Legislation

- **Fair Work Act 2009** — core federal employment law
- **National Employment Standards (NES)** — 11 minimum entitlements
- **121 Modern Awards** — industry/occupation-specific minimum conditions (no UK equivalent)
- **Anti-discrimination**: Racial Discrimination Act 1975, Sex Discrimination Act 1984, Disability Discrimination Act 1992, Age Discrimination Act 2004
- Each state/territory has its own anti-discrimination act

#### Key Federal EHS Legislation

- **WHS Act 2011 (Cth)** — covers federal government employees
- **EPBC Act 1999** — environment protection (major reform underway 2025-26)
- **ADG Code 7.9** — dangerous goods transport (national model, state-implemented)
- ~26 model Codes of Practice (hazardous chemicals, asbestos, confined spaces, etc.)

#### State Environment Protection Acts

Each state has its own EPA and primary act (e.g., NSW: Protection of the Environment Operations Act 1997, VIC: Environment Protection Act 2017, QLD: Environmental Protection Act 1994, etc.).

### 4. Data Model Impact Assessment

#### Generalisation vs Parallel Table

**Recommendation**: Generalise `uk_lrt` → a jurisdiction-neutral `legal_register` (or similar) rather than creating parallel tables per country. Key reasoning:
- Core column structure (title, year, number, family, domain, duty_holder, function, etc.) applies to both UK and AU
- Adding `country` and `jurisdiction` columns is cleaner than maintaining separate tables
- LAT and amendment_annotations already have a generic structure — just need FK updates
- Law graph (edges) is jurisdiction-neutral

#### New Fields Needed for AU

| Field | Purpose | Notes |
|-------|---------|-------|
| `country` | `uk` or `au` (ISO alpha-2) | Top-level partition |
| `jurisdiction` | `cth`, `nsw`, `vic`, `qld`, `wa`, `sa`, `tas`, `act`, `nt` (AU) or `uk`, `eng`, `wal`, `sco`, `ni` (UK) | Replaces/supplements `geo_extent` |
| `model_law_reference` | Links state implementations back to national model | AU-specific: WHS model law tracking |
| `sunsetting_date` | Automatic repeal date for AU delegated legislation | AU legislative instruments sunset after 10 years |

#### Duty Holder / Rights Holder / Power Holder Mapping

**Strong overlap** — AU WHS law uses very similar concepts:

| UK Concept | AU Equivalent | Key Difference |
|---|---|---|
| Duty holder (employer) | **PCBU** (Person Conducting a Business or Undertaking) | PCBU is broader: includes sole traders, partnerships, government, not-for-profits |
| Employee duties | Worker duties | Workers must take reasonable care, cooperate with PCBU |
| — | **Officers** (due diligence duty) | Company directors/officers have personal liability — more explicit than UK |
| Power holder | Regulator/Inspector | Same concept |
| Rights holder | Workers, HSRs | Workers have right to cease unsafe work; Health & Safety Representatives elected |

The Duty/Right/Responsibility/Power taxonomy **maps well**. The main addition is PCBU as a broader category than "employer".

#### Family Taxonomy

Existing UK families map well to AU with modest expansion needed:

- **H&S families**: Most map directly (OH&S, Fire, Food, Transport safety, etc.)
- **Environment families**: Most map directly (Air Quality, Waste, Water, Climate Change, etc.)
- **HR families**: Need expansion for AU-specific concepts:
  - `💜 HR: Modern Awards` (121 industry-specific instruments — no UK equivalent)
  - `💜 HR: Superannuation` (mandatory employer contributions — no UK equivalent)
  - `💜 HR: Anti-Discrimination` (currently implicit in UK data)

#### Type Code Mapping

AU needs its own type code vocabulary:

| AU Type | Description |
|---------|-------------|
| `cth_act` | Commonwealth Act |
| `cth_li` | Commonwealth Legislative Instrument (regulation, rule, etc.) |
| `nsw_act`, `vic_act`, etc. | State/territory Acts |
| `nsw_reg`, `vic_reg`, etc. | State/territory regulations |
| `cop` | Code of Practice (model or state) |
| `award` | Modern Award (Fair Work Commission) |

### 5. Data Acquisition Strategy

#### Data Sources & API Availability

| Source | Coverage | API Quality | Format |
|--------|----------|-------------|--------|
| **legislation.gov.au** (Federal Register) | All Commonwealth Acts + legislative instruments | Limited/undocumented API at `api.prod.legislation.gov.au` | HTML, some XML |
| **Queensland legislation API** | QLD legislation only | **Best-documented** state API (Swagger UI, JSON/XML responses) | JSON, XML, HTML, PDF |
| **AustLII** (austlii.edu.au) | All jurisdictions, 500K+ documents | Legacy SINO CGI API only, no modern REST | HTML |
| **ALRC DataHub** | Federal legislation metadata | Downloadable datasets (CSV) | CSV — 13,200+ Acts, 87,500+ instruments |
| **State legislation databases** | One per state (legislation.nsw.gov.au, etc.) | Varies; mostly scrape-only | HTML/PDF |

**Key finding**: There is **no equivalent of legislation.gov.uk's well-documented REST API** at the federal level. Data acquisition will require a mix of approaches:
1. ALRC DataHub CSV for initial federal law metadata
2. Queensland API for QLD laws (can serve as a template)
3. Scraping for other states (legislation.nsw.gov.au, legislation.vic.gov.au, etc.)
4. Possibly AustLII as a unified but lower-quality source

#### Scraper Architecture Reuse

The existing scraper architecture **cannot be directly reused** — it's tightly coupled to legislation.gov.uk XML endpoints. However, the **session management pattern** (scrape sessions, persist/review workflow) is reusable. A new AU scraper would need:

- Different URL patterns per jurisdiction (9 different legislation portals)
- Different XML/HTML parsing (no Dublin Core metadata standard)
- Different ID format (not `UK_{type}_{year}_{number}`)
- Adapter/strategy pattern to abstract jurisdiction-specific scraping

#### Volume Estimates

| Category | Estimated Records |
|----------|------------------|
| Federal EHS | 100–150 |
| Federal HR | 150–200 (including 121 Modern Awards) |
| State/Territory EHS (×8) | 400–640 |
| State/Territory HR (×8) | 80–160 |
| Codes of Practice (model + state) | 200–250 |
| **Total** | **~1,000–1,500** |

This is significantly smaller than the UK LRT's 19,000+ records. If individual amendments/SIs are tracked, the number would grow but likely remain under 5,000.

### 6. Frontend Multi-Jurisdiction Support

#### Jurisdiction Switcher/Filter

A country/jurisdiction filter is needed at multiple levels:
- **Browse page**: Filter by country (UK/AU), then by jurisdiction within country
- **Admin LRT page**: Same filtering, plus jurisdiction-aware family/type options
- **Admin scrape**: Jurisdiction-aware scrape session creation
- **LAT queue**: Filter by jurisdiction

#### ElectricSQL Shape Impact

Current shapes sync the entire `uk_lrt` table (reference data, no org scoping). For multi-jurisdiction:
- Add `country` to shape `where` clause for selective sync
- Or sync all and filter client-side (feasible at ~20K records total)
- PGlite local schema needs `country`/`jurisdiction` columns added

#### Component Changes

- Type code options, geo extent options, family options → must be driven by jurisdiction context (not hardcoded)
- External links → legislation.gov.uk for UK, jurisdiction-specific portals for AU
- Column metadata → `UK_LRT_COLUMN_METADATA` needs jurisdiction-aware variant

### 7. Infrastructure & Deployment

#### Database Sizing

- Current UK: ~19,000 records in `uk_lrt`, ~X records in `lat`, ~X in `amendment_annotations`
- Adding AU: +1,000–1,500 records to the register table
- Minimal impact on database size — well within existing PostgreSQL capacity
- ElectricSQL sync volume increase is negligible

#### Shape Partitioning

- Could partition shapes by `country` to reduce sync volume per client
- Or serve all jurisdictions in one shape — total record count (~20K) is still manageable
- Decision depends on whether clients need single-country or multi-country views

#### Sync Cadence

- AU data would need its own scrape/update cadence separate from UK
- AU has a 10-year sunsetting cycle for delegated legislation — need to track sunset dates
- Major WHS reform cycles every 3–5 years; Fair Work amendments more frequent
- Modern Award 4-yearly reviews + annual wage reviews (June/July)

#### Production Deployment

- No additional infrastructure needed — same PostgreSQL, same ElectricSQL instance
- May want to add a jurisdiction dimension to health/metrics endpoints
- NAS snapshot scripts would need to handle larger dataset (minimal impact)

### 8. Compliance & Accuracy

#### Regulatory Bodies

**EHS**:
- **Safe Work Australia** — national policy body (develops model laws, does NOT enforce)
- **Comcare** — federal WHS regulator
- 8 state/territory regulators: SafeWork NSW, WorkSafe Victoria, WHSQ, SafeWork SA, WorkSafe WA, WorkSafe Tasmania, WorkSafe ACT, NT WorkSafe
- State EPAs for environment

**HR**:
- **Fair Work Commission** — national workplace relations tribunal
- **Fair Work Ombudsman** — compliance and enforcement
- **Australian Human Rights Commission** — federal discrimination
- State anti-discrimination/equal opportunity commissions

#### Update Frequency & Staleness Risk

- Commonwealth legislative instruments **automatically sunset after 10 years** (1 April or 1 October following 10th anniversary)
- Model WHS amendments released Dec 2025; state implementation takes 1–2 years
- Fair Work Act amended regularly; major reforms every 2–4 years
- Modern Awards: 4-yearly review cycle + annual wage review (June/July)
- **Risk**: 9 jurisdictions × independent amendment schedules = higher monitoring burden than UK

#### Professional Review Considerations

- AU law interpretation requires AU-qualified legal review
- PCBU concept is broader than UK employer — duty assignment logic needs AU-specific validation
- Victoria's non-harmonised OHS Act requires separate treatment
- Modern Awards have complex coverage rules (industry + occupation tests)

---

## Key Findings Summary

### Feasibility: HIGH

The AU EHS/HR legal structure is architecturally similar to the UK system. The duty holder taxonomy maps well, POPIMAR is jurisdiction-agnostic, and the family classification needs only modest expansion.

### Reuse Assessment

| Component | Reuse Level | Notes |
|-----------|-------------|-------|
| Database schema (generalised) | 🟡 Moderate | Rename + add country/jurisdiction columns |
| Family taxonomy | 🟡 Moderate | Most families apply; need AU-specific additions |
| Duty/Rights/Power classification | 🟢 High | Concepts map well; add PCBU |
| POPIMAR framework | 🟢 High | Jurisdiction-neutral |
| Function classification | 🟡 Moderate | Concepts apply but detection rules are UK-specific |
| Scraper | 🔴 Low | New scrapers needed for AU data sources |
| Actor definitions | 🔴 Low | Entirely different government structures |
| LAT parsing architecture | 🟡 Moderate | Pattern reusable, rules need AU adaptation |
| Session management UI | 🟢 High | Generic workflow, reusable |
| Browse/admin UI structure | 🟢 High | Add jurisdiction filter layer |
| ElectricSQL sync | 🟢 High | Add country column to shapes |
| Law graph / edges | 🟢 High | Jurisdiction-neutral concept |

### Top 5 Challenges

1. **No single AU API** — data acquisition requires multiple sources and scrapers
2. **9 jurisdictions** — vs UK's 4 regions; higher ongoing monitoring burden
3. **Victoria's divergence** — non-harmonised OHS Act needs special handling
4. **Modern Awards** — 121 instruments with no UK equivalent; new data type
5. **Actor definitions** — entirely different government structures need new mappings

### Estimated Record Count

~1,000–1,500 primary AU EHS+HR instruments (vs 19,000+ UK records).

---

## Architectural Decisions

### ADR-1: PostgreSQL Table Partitioning by Country

**Status**: Accepted (2026-05-17)

**Context**: The legal register will extend beyond UK and AU to additional countries over time. We need a schema strategy that scales to 5+ countries without accumulating sparse columns, losing query performance, or fragmenting the codebase.

**Decision**: Use a single logical table (`legal_register`) with PostgreSQL `PARTITION BY LIST (country)`. One physical partition per country. Same pattern for `legal_articles` (replacing `lat`) and `amendment_annotations`.

**Rationale** (vs alternatives):

| Approach | Rejected Because |
|----------|-----------------|
| Single flat table (no partitioning) | Indexes lose selectivity; all queries need `WHERE country = ?`; country-specific columns accumulate nulls; no physical isolation for backup/restore |
| Separate tables per country (`uk_lrt`, `au_lrt`, ...) | Every cross-country query needs UNION; duplicate Ash resources, API routes, frontend types per country; adding a country means new resources/routes/shapes everywhere |
| **Partitioned table** (chosen) | Logical unity (one Ash resource, one API, one type) with physical isolation (partition pruning, per-country indexes, independent backup/restore) |

**Schema outline**:

```sql
CREATE TABLE legal_register (
    id UUID NOT NULL,
    country TEXT NOT NULL,           -- 'uk', 'au', 'nz', 'us', etc.
    jurisdiction TEXT NOT NULL,      -- country-specific: 'eng', 'wal', 'sco', 'ni' (UK)
                                     --                   'cth', 'nsw', 'vic', 'qld', 'wa', 'sa', 'tas', 'act', 'nt' (AU)
    
    -- Universal columns (all countries)
    name TEXT,
    title_en TEXT,
    year INTEGER,
    number TEXT,
    family TEXT,
    domain TEXT[],
    type_code TEXT,                  -- jurisdiction-qualified (ukpga, uksi, cth_act, nsw_reg, etc.)
    type_desc TEXT,
    live TEXT,
    function JSONB,
    duty_holder JSONB,
    power_holder JSONB,
    rights_holder JSONB,
    responsibility_holder JSONB,
    popimar JSONB,
    fitness JSONB[],
    source_url TEXT,                 -- replaces leg_gov_uk_url (per-country portal URL)
    -- ... other universal fields ...
    
    PRIMARY KEY (id, country)        -- partition key must be in PK
) PARTITION BY LIST (country);

CREATE TABLE legal_register_uk PARTITION OF legal_register FOR VALUES IN ('uk');
CREATE TABLE legal_register_au PARTITION OF legal_register FOR VALUES IN ('au');
-- Future: CREATE TABLE legal_register_nz PARTITION OF legal_register FOR VALUES IN ('nz');

-- Same pattern for articles
CREATE TABLE legal_articles (
    id UUID NOT NULL,
    country TEXT NOT NULL,
    law_id UUID NOT NULL,
    law_name TEXT NOT NULL,
    section_id TEXT,
    -- ... article content fields ...
    PRIMARY KEY (id, country)
) PARTITION BY LIST (country);

CREATE TABLE legal_articles_uk PARTITION OF legal_articles FOR VALUES IN ('uk');
CREATE TABLE legal_articles_au PARTITION OF legal_articles FOR VALUES IN ('au');
```

**Ash layer**: Single resource `SertantaiLegal.Legal.LegalRegister` backed by the partitioned table. Partitioning is transparent — Ash/Ecto queries work unchanged; PostgreSQL handles partition routing automatically.

**ElectricSQL shapes**: Filter by `country` in shape `where` clause. Each client syncs only the countries it needs. Partition pruning makes shape queries efficient.

**Consequences**:
- Migration from `uk_lrt` → `legal_register_uk` partition (data migration required)
- `name` field format changes from `UK_ukpga_1974_37` to include country context (or keep as-is since country is a separate column)
- All API routes generalise: `/api/uk-lrt/:id` → `/api/laws/:id` (with country filter)
- Frontend type `UkLrtRecord` → `LegalRecord` (jurisdiction-neutral)
- Country-specific logic (type codes, geo extents, actor definitions, scrapers) lives in per-country modules, not in the schema
- Adding a new country = new partition + new country module + data import — no schema migration needed

---

**Ended**: 2026-05-18

## Summary
- Completed: 28 of 28 research todos
- Files: `.claude/sessions/2026-05-17-australian-ehs-hr-research.md`, `.claude/plans/multi-jurisdiction.md`
- Outcome: Full codebase audit (backend + frontend UK assumptions), AU EHS/HR law landscape research, and architectural decision on PostgreSQL table partitioning by country. High-level implementation plan created with 6 Phase 1 sessions (generic architecture) and 5 Phase 2 sessions (AU-specific).
- Next: Begin Phase 1.1 — schema migration from `uk_lrt` to partitioned `legal_register`
