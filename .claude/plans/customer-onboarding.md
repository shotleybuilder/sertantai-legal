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

### 2.3 — EU law family assignment (#86) — mostly done

Graph inference assigned 140/507 EU families. Title keywords now cover 96% of QQ EU corpus.

**Root cause**: EU laws have NO SI codes and NO dc:subject on legislation.gov.uk.
These fields simply don't exist for EU retained law — structural gap, not parser bug.

**Completed**:
1. ✅ Title keyword matching — `title_to_family/1` in Filters, expanded with EU-specific terms
2. ✅ Type-based making classification — Tier 0 in MakingDetector (eur=making 0.95, eudr=not_making 0.9, eudn=not_making 0.5)
3. ✅ QQ EU corpus: 67/70 applicable laws have family (96%). 3 remain (1 empty title, 2 niche)
4. ✅ LAT parsing for EU laws — parser extended for EURetained/EUBody XML, 70 laws parsed (9,090 LAT rows)

**Remaining work**:
- Manual/LLM batch — for ~200+ non-QQ EU laws with no keyword or graph signal
- Fractalaw EU fitness dictionaries — DRRP extraction works (13-49% hit rate), fitness sparse (21%)

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

### 4.5 — Aggregate more QQ site CSVs ✅

- All 24 QQ site CSVs processed (20 new + BSC = 24 total, E+S+W coverage, no NI)
- Applicability seeded with union semantics: 275 yes, 60 no
- ~45 misidentified SSIs fixed (Enhesa S.S.I. refs matched as uksi), 3 Acts corrected (asp/asc/ukpga)
- 118-law scrape session cleaned to 44 valid records, 34 new laws LAT-parsed
- Enrichment: 20 Making, 7 Empowering, 6 Housekeeping, 1 not enriched (no body text)
- NAS snapshot exported
- Tool: `mix legal.fix_misidentified` for analysing/fixing wrong type_code assignments
- Raised: #95 (phantom grid rows on inline edit), #96 (session auto-complete)

### 4.9 — Enhesa data quality report ✅

Full QQ corpus (24 sites, 334 laws) analysed. Report at `data/reports/qq/enhesa-quality-report.md`.

**Headlines**: 76% precision, 90% recall. 208 TP, 66 FP (22 revoked, 20 no duties), 23 FN.
All assessable laws fully parsed and enriched. Skill: `customer-quality-report`.

**Artifacts suitable for customer-facing report page** (not Enhesa-specific):
- Family distribution — law count + duty count by domain
- Duty density — top laws by duty count (where compliance burden sits)
- EU vs UK jurisdiction split
- Making/Empowering/Housekeeping breakdown
- Total duties, total laws, total provisions

These are SertantAI data shape metrics — useful for any customer, not just Enhesa migrations.

### 4.6 — Fix JSONB column formatting for Baserow ✅

Function, Duty Type, Purpose, Holders all converted to Baserow `multiple_select` fields.
Master holder vocabulary (165 options) hardcoded from ActorDefinitions + observed data.
Vocabulary validation stops sync if fractalaw introduces unrecognised actors.

### 4.8 — LRT field type refinements for Baserow ✅

LRT columns converted to proper Baserow select types:

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

### 5.4 — EU LAT parsing + enrichment ✅

- LAT parser extended for EU retained law XML (EURetained/EUBody, EUTitle→Part, EUChapter→Chapter)
- EU laws use `art.` citation prefix (not `reg.`), 24 new tests + 2 XML fixtures
- 70 QQ-applicable EU laws parsed: 9,090 LAT rows, 2,012 annotations
- Enrichment: 61 Making, 2 Empowering, 3 Housekeeping, 4 not enriched
- DRRP hit rate: 13-49% depending on law type (directives better than regulations)
- EU actor model: 13 new actors added (EU: Member State, ECHA, EFSA, SC: Downstream User, etc.)
- Fitness: 13/61 Making laws (21%) — fractalaw EU fitness dictionaries pending
- NAS snapshot exported with EU LAT data

### 5.3 — Open issues from Phase 5

| # | Issue | Status |
|---|---|---|
| #87 | Engine.run sync flow drops rows | Open — workaround: direct calls |
| #88 | LAT parser 0 rows for 6 laws with valid XML | Open — older SI format? |
| #89 | Skip fully revoked laws in LAT queue + parser | Open |
| #90 | LAT queue: filter by customer L3 applicability | Done — org applicability dropdown in queue |
| #95 | Phantom null rows after inline edit on grid | Open — TanStack DB mutation reconciliation |
| #96 | LAT session doesn't auto-complete when all parsed | Open — manual SQL workaround |

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

## Phase 7: L3 Screening UI ✅ (MVP)

Customer-facing applicability screening at `/app/screening` + `/app/stats`.

### 7.1 — Backend API ✅

ScreeningController with 5 endpoints in `api_authenticated` scope:
- `GET /api/screening/applicabilities` — list org's decisions
- `PUT /api/screening/applicabilities/:law_name` — upsert (single-click persist)
- `POST /api/screening/applicabilities/bulk` — batch add/remove
- `GET /api/screening/stats` — aggregate counts by status, family
- `POST /api/screening/sync` — trigger Baserow sync
- 8 controller tests

### 7.2 — Local-first infrastructure ✅

- PGLite schema v17: `org_applicabilities` table + indexes
- Electric shape subscription (org-scoped via JWT, Gatekeeper auth)
- Migration: REPLICA IDENTITY FULL for ElectricSQL

### 7.3 — Screening UI ✅

Two-panel split view (Available pool ↔ My Register):
- Left panel: available Making laws + explicitly excluded
- Right panel: organisation's legal register (Yes laws)
- Single-click [+] / [×] / [exclude] / [restore] — instant persist, no save buttons
- Batch operations via checkbox selection
- Both panels are full GridLite instances with search, filter, sort, group
- Inline editable notes on register laws

### 7.4 — Stats Dashboard ✅

`/app/stats` — all computed locally from PGLite:
- Overview cards (total making, register, excluded, unreviewed)
- Screening progress bar with segmented legend
- Family distribution with per-family progress bars
- EU vs UK jurisdiction split
- Fitness coverage percentage

### 7.5 — Open issues + future enhancements

| # | Issue | Status |
|---|---|---|
| #97 | Zenoh dashboard: ProvisionSubscriber + persist activity | Open |
| #98 | Column visibility, inline row actions, hide law code | Open |
| #99 | Audit trail and change reversal | Open |
| #100 | Download My Register as .md/.csv | Open |
| #101 | Row detail card (Airtable pattern) | Open |
| #102 | AI-seeded register from org profile + questionnaire | Open |
| #103 | Saved views using svelte-gridlite-views | Open |
| #104 | URL state persistence (blocked on gridlite-kit#34) | Blocked |

### 7.6 — Remaining

- Phase 6: Baserow sync trigger button in UI (backend endpoint exists)
- Hub integration: entitlement webhook triggers applicability refresh

---

## Phase 8: Automated L3 Screening (Taxa + Fitness)

Use Taxa (DRRP roles) and Fitness fields to automate L3 applicability recommendations, replacing manual curation. Tracked in #102.

### 8.1 — Org profile model

Define what we know about an org: sector, activities, site types, workforce composition. This drives Fitness matching. Lives in Hub (org owns it) but Legal consumes it for screening.

### 8.2 — Fitness-based scoring

For laws with Fitness data, score relevance to org profile:
- fitness_sector matches org sector → strong signal
- fitness_person includes employer/employee → broadly applicable
- fitness_place matches org site types → relevant
- Combine into a recommendation (yes/no/review) with confidence

### 8.3 — Seeding workflow (additive only)

- Customer presses "Seed" → laws matching fitness profile added to register
- Seeded laws use `source: 'screener'` (distinguished from manual)
- Visual badge until confirmed by user
- Repeatable: re-seeding finds the delta

### 8.4 — Validation against Enhesa

Compare automated recommendations to Enhesa Yes/No decisions. Measure precision/recall per family.

**Prerequisite**: Fitness coverage improving — currently 44% for EU laws (up from 21%), ~50% for UK domestic. Fractalaw iteratively expanding.

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
