# Customer Onboarding

**Created**: 2026-06-02
**Goal**: Repeatable workflow for onboarding customers from legacy compliance platforms (Enhesa, Nimonik, etc.) into SertantAI with Baserow sync
**First customer**: QQ (Jason's day-job org)
**Research**: `.claude/sessions/2026-06-02-customer-poc-setup.md`

---

## Phase 1: Legacy Register Import ✅

Import customer's CSV, match against LRT, scrape missing laws, QA.

- `mix legal.import_register` — extract → transform → match pipeline
- Skill: `.claude/skills/customer-onboarding-import/`
- Tested with QQ/BSC (Enhesa): 670 matched, 239 scraped, 32 not handled
- NAS sync + archive complete

---

## Phase 2: Data Quality for Matched Laws

Ensure matched laws have the data needed for sync (family, making classification, LAT).

### 2.1 — Fix parser family assignment (#84)

Parser bug: Auto Parse doesn't apply SI code → family mapping. 22 domestic laws had mapped SI codes but got NULL family. Highest-impact fix.

### 2.2 — Add missing SI code → family mappings (#85)

9 SI codes not in Models: ROAD TRAFFIC, WEIGHTS AND MEASURES, FIRE AND RESCUE SERVICES, plus 6 ambiguous codes needing disambiguation rules.

### 2.3 — EU law family assignment (#86)

204 EU retained laws (eur/eudr/eudn) have NULL family. Parser has no family path for EU types (no SI codes). Approaches: transpose from UK transposing SI, EU subject mapping, title keywords, or LLM-assisted batch.

### 2.4 — Confirm making classification

Matched laws need `function.Making = true` for Level 2 filtering. Check coverage and parse LAT where making classification is missing. LAT queue picker now shows import sessions.

### 2.5 — Parse LAT where missing

Use `/admin/lat/queue` with the `import-qq-bsc` session to identify laws needing LAT parsing. LAT drives making classification, purpose, and fitness fields.

---

## Phase 3: Org-Level Applicability (Level 3) ✅

Persist per-law applicability selections and wire into sync engine.

### Applicability model

| Level | Description | QQ/BSC example |
|---|---|---|
| L1 | Family subscription | 38 families, 1,836 laws |
| L2 | Making laws in those families | 1,665 laws |
| L3 | Org-level screened | ~300-400 target |
| Site | Per-site selection within L3 | 126 (BSC Yes) |

- OrgApplicability Ash resource (yes/no/excluded/unreviewed per org+law)
- `mix sync.seed_applicability` pre-populates from Enhesa CSV
- Sync engine INNER JOINs on applicability — only yes laws reach Baserow
- QA skill: `customer-onboarding-applicability-qa` (draft, 8 codified patterns)
- QQ/BSC seeded: 204 yes, 82 no from Enhesa import

---

## Phase 4: Sync to Baserow

Wire up the full auth → entitlement → profile → sync flow.

### 4.1 — Set up org + user in sertantai-auth

Create QQ organisation and Jason's user account. Hub reads from auth DB.

### 4.2 — Push entitlement to sertantai-legal

Call `POST /api/webhooks/entitlement-change` with QQ's subscribed families and tiers. Hub doesn't have outbound webhook yet — call directly for POC.

### 4.3 — Create sync profile + Baserow config

- Sync profile: families from Level 3 screened set
- Baserow config: SaaS URL, API token, LRT + LAT table IDs
- Test connection

### 4.4 — Trigger initial sync

- Verify data lands in Baserow correctly
- Check field mapping, row counts, LAT links
- Sync filters to L3 (yes-applicable laws only)

### 4.5 — Aggregate more QQ site CSVs

- Load additional QQ site CSVs through import pipeline (rinse and repeat Phase 1)
- Seed applicability from each site's Enhesa Answer data
- Union of all site Yes laws = org-level validation set

### 4.9 — Enhesa data quality report (after all sites aggregated)

Deferred until all QQ site CSVs are imported. The report needs the full org-level
applicability picture (union of all sites), not just one site.

- Law-by-law enrichment coverage
- Applicability sense-check (revoked in Yes set, coverage gaps, false positives)
- Compare across sites for consistency
- Use `customer-onboarding-applicability-qa` skill

### 4.6 — Fix JSONB column formatting for Baserow ✅

Function, Duty Type, Purpose, Holders all converted to Baserow `multiple_select` fields.
Master holder vocabulary (165 options) hardcoded from ActorDefinitions + observed data.
Vocabulary validation stops sync if fractalaw introduces unrecognised actors.

### 4.8 — LRT field type refinements for Baserow

Several LRT columns are synced as plain text but should be single/multi-selects for
better Baserow UX (filtering, grouping, colour coding):

| Column | Current | Should be | Notes |
|---|---|---|---|
| Family | text | single_select | ~40 known values |
| Type | text | single_select | ~10 type_desc values |
| Status | text | single_select | 3 live status values |
| Geographic Extent | text | single_select | ~8 extent codes |
| Domain | text | multiple_select | array field |
| Geographic Region | text | multiple_select | array field |
| Making Classification | text | REMOVE | not customer-facing |
| Fitness * (person/process/place/plant/sector) | text | multiple_select | array fields — key for L3 screening |
| _source_id | text | HIDDEN or REMOVE | internal sync mapping, not customer-facing |

### Baserow table design principles

**Legal Register (LRT)** = "Which laws apply to my organisation?"
- Fitness fields belong HERE — they define applicability scope (who/where/what the law covers)
- Function, Family, Holders for overview
- Fitness enables L3 screening: filter by sector, place, person to find relevant laws

**Duties (LAT)** = "What must I do?"
- DRRP fields only — regulated actors, duty type, provision text (Duty Summary deferred)
- NO fitness fields — fitness lives on application provisions (reg.1/s.1), not duty provisions
- Each row is a COMPLETE provision — aggregated from sub_articles via Goldilocks model
- Commercial orgs: Duty only. Government: Responsibility + Power
- 748 rows for QQ (down from 2,386 fragments)

### 4.12 — Drop Duty Summary from LAT table ✅

Removed — clause_refined echoes text verbatim. Re-add when fractalaw produces genuine summaries.

### 4.11 — Provision-level aggregation (Goldilocks model) ✅

`query_lat_aggregated/2` groups all children under parent provision. Each row is a
complete, self-contained obligation with numbered sub-parts and indentation.

Result: 748 aggregated duties vs 1,529 fragments (51% reduction).
PUWER reg.32: 21 fragments → 1 complete regulation.
Total Baserow: 853 rows (105 LRT + 748 LAT).

### DRRP filtering by org type ✅

LAT syncs only DRRP types relevant to the customer:
- **Commercial org** (QQ): Duty only → governed actors
- **Government org**: Responsibility + Power → government actors

Configured via `target_config.lat_drrp_types`. QQ set to `["Duty"]`.

### DRRP ↔ Actor class alignment

Governed actors (Org:, Ind:, SC:, Spc:, etc.) hold Duties and Rights.
Government actors (Gvt:, Crown, HM Forces, EU:) hold Responsibilities and Powers.

| DRRP | Actor class | Baserow column options |
|---|---|---|
| Duty | Governed only | Org: Employer, Ind: Employee, SC: Manufacturer, etc. |
| Responsibility | Government only | Gvt: Authority, Gvt: Minister, Crown, etc. |
| Right | Governed only | Same as Duty actors |
| Power | Government only | Same as Responsibility actors |

The Baserow multi-select for each holder column should use its correct actor subset,
not the full 165-option list. This makes filtering much easier for customers.

### 4.10 — Holder data quality audit + reparse (separate session)

The original Airtable-era data may have governed actors in government holder columns
and vice versa. Fractalaw's enrichment gets this right, but laws that haven't been
re-enriched since the Airtable import may have cross-contaminated data.

Scope: full corpus audit, not just QQ laws. Steps:
1. Query for governed actors (Org:/Ind:/SC:) in responsibility_holder/power_holder → flag
2. Query for government actors (Gvt:/Crown) in duty_holder/rights_holder → flag
3. Quantify: how many laws are affected?
4. Fix: re-enrich via fractalaw (taxa pipeline cleans holder assignment)
5. Update Baserow multi-select options per column (governed vs government subsets)

### 4.7 — Fix Engine.run sync flow (#87)

`Engine.run` creates rows but they don't persist. Direct calls work fine.
Suspected: `with` chain return value issue or `prepare_tables` interference.
Workaround: call sync steps directly outside the engine.

---

## Phase 5: Sync LAT to Baserow ✅ + LAT Taxa Enrichment

### 5.1 — Create LAT table in Baserow ✅

LAT table created (ID 1008280), section_type filter in ProfileQuery, 623 provision-level
rows synced for OH&S with parent law links. 729 total rows within Baserow free tier.

### 5.2 — Wire up LAT Taxa/Fitness enrichment from fractalaw ✅

- 18 taxa/fitness columns added to legal_articles (0290ff0)
- ProvisionSubscriber wired up for `taxa/provisions/{law_name}` (83506e4)
- DataServer LRT queryable fixed — `leg_gov_uk_url` → `source_url` (6b596a1)
- End-to-end tested: fractalaw enrich → publish → sertantai receives law + provision taxa
- 22 laws processed: 10 Making (672 provisions enriched), 12 Empowering, 1 Housekeeping

### 5.3 — Open issues from Phase 5

| # | Issue | Status |
|---|---|---|
| #87 | Engine.run sync flow drops rows | Open — workaround: direct calls |
| #88 | LAT parser 0 rows for 6 laws with valid XML | Open — older SI format? |
| #89 | Skip fully revoked laws in LAT queue + parser | Open |
| #90 | LAT queue: filter by customer L3 applicability | Open — needed for remaining ~170 QQ laws |

Reference: `~/fractalaw/.claude/sessions/06-03-26-lat-taxa-fitness-columns.md`

---

## Phase 6: Production Deployment

### 6.1 — Prod data sync

Run lrt-scrape stages 6-7: delta export, apply to prod via SSH pipe, post-prod QA.

### 6.2 — Deploy sync infrastructure

Ensure sync service, Electric, and Baserow proxy are deployed and configured for prod.

### 6.3 — End-to-end test

Prod backend → ElectricSQL → sync engine → Baserow SaaS. Verify the full pipeline works.

---

## Phase 7: L3 Screening UI

Frontend within sertantai-legal (or sertantai-compliance) for org-level applicability screening.

### 6.1 — API endpoints for applicability CRUD

- `GET /sync/applicabilities` — list, filter by status
- `PUT /sync/applicabilities/:law_name` — set status
- `PATCH /sync/applicabilities/bulk` — bulk update
- `GET /sync/applicabilities/stats` — counts by status
- Org-scoped via JWT, follows existing sync controller patterns

### 6.2 — Screening UI

- Browse L2 laws grouped by family, with applicability status
- Inline accept/reject with Fitness/Taxa signals as guidance
- Bulk actions (accept all in family, reject sector-mismatched)
- Progress dashboard: reviewed vs unreviewed vs total

### 6.3 — Hub integration

- Hub calls Legal's screening API with org profile
- Entitlement webhook triggers applicability refresh when families change

---

## Phase 8: Automated L3 Screening (Taxa + Fitness)

Use Taxa (DRRP roles) and Fitness fields to automate L3 applicability recommendations, replacing manual curation.

### 7.1 — Org profile model

Define what we know about an org: sector, activities, site types, workforce composition. This drives Fitness matching. Lives in Hub (org owns it) but Legal consumes it for screening.

### 7.2 — Fitness-based scoring

For laws with Fitness data, score relevance to org profile:
- fitness_sector matches org sector → strong signal
- fitness_person includes employer/employee → broadly applicable
- fitness_place matches org site types → relevant
- Combine into a recommendation (yes/no/review) with confidence

### 7.3 — Taxa-based signals

Use DRRP role data to identify broadly-applicable vs sector-specific laws:
- "Org: Employer" + "Ind: Employee" → general workplace law
- Specialist roles (Maritime: master, etc.) → sector-specific

### 7.4 — Validation against Enhesa

Compare automated recommendations to Enhesa Yes/No decisions and manual QA findings. Measure precision/recall per family. Iterate rules.

**Prerequisite**: Fitness coverage must expand beyond safety families (currently 7.4% of making laws). Fractalaw parser is iteratively improving this, one family at a time.

---

## Phase 9: Multi-Jurisdiction Sync

QQ operates in UK, AU, DE, CN, and US. SertantAI currently supports UK and AU.

### 9.1 — Baserow architecture for multi-jurisdiction

Decide the table structure:
- **Option A**: One LRT table per jurisdiction (UK Legal Register, AU Legal Register) — cleaner separation, simpler queries
- **Option B**: Single unified table with Country column — easier cross-jurisdiction views, but wider schema
- Consider: each jurisdiction may have different field sets (UK has SI codes, AU has state/territory)

### 9.2 — SyncProfile per jurisdiction

- Extend SyncProfile to support country filtering (already have `country` on legal_register)
- One sync config per jurisdiction table, or one config with multiple table targets

### 9.3 — DE, CN, US jurisdictions

- Not yet supported in sertantai-legal
- Will need separate data acquisition pipelines per jurisdiction
- Baserow sync can accommodate once data exists

---

## Future Work

- **Site-level applicability**: per-site selections within the org register
- **More vendors**: Nimonik, Wolters Kluwer CSV formats (add `extract/2` clauses)
