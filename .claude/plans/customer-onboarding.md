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
- Compare screener output vs actual site selections for accuracy

---

## Phase 5: Production Deployment

### 5.1 — Prod data sync

Run lrt-scrape stages 6-7: delta export, apply to prod via SSH pipe, post-prod QA.

### 5.2 — Deploy sync infrastructure

Ensure sync service, Electric, and Baserow proxy are deployed and configured for prod.

### 5.3 — End-to-end test

Prod backend → ElectricSQL → sync engine → Baserow SaaS. Verify the full pipeline works.

---

## Phase 6: L3 Screening UI

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

## Phase 7: Automated L3 Screening (Taxa + Fitness)

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

## Future Work

- **Site-level applicability**: per-site selections within the org register
- **More vendors**: Nimonik, Wolters Kluwer CSV formats (add `extract/2` clauses)
- **AU jurisdiction**: import pipeline works for AU once AU scraper is complete
