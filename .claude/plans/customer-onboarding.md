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

## Phase 3: Org-Level Applicability Screener (Level 3)

The key value-add vs just dumping all making laws.

### Applicability model

| Level | Description | QQ/BSC example |
|---|---|---|
| L1 | Family subscription | 38 families, 1,836 laws |
| L2 | Making laws in those families | 1,665 laws |
| L3 | Org-level screened (Fitness-informed) | ~300-400 target |
| Site | Per-site selection within L3 | 126 (BSC Yes) |

SertantAI L2 (1,665) is too broad — 13x the site's actual needs. Enhesa's curated list (345) sits where L3 should land. The Fitness-informed screener replaces Enhesa's manual curation.

### 3.1 — Design the screener

- Decide: lives in sertantai-hub or sertantai-legal?
- Input: org's subscribed families + org profile (industry, activities)
- Filter: making laws where Fitness fields indicate relevance to org's profile
- Output: org-level register (~300-400 laws for a typical EHS org)

### 3.2 — Build the screener

- API endpoint for screening
- UI for org to review and adjust (accept/reject individual laws)
- Persist org-level selections

### 3.3 — Aggregate site CSVs

- Load more QQ site CSVs through the import pipeline
- Union of all site Yes laws = org-level validation set
- Compare screener output vs actual site selections for accuracy

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
- Pre-populate applicability column from Enhesa Answer data

---

## Phase 5: Production Deployment

### 5.1 — Prod data sync

Run lrt-scrape stages 6-7: delta export, apply to prod via SSH pipe, post-prod QA.

### 5.2 — Deploy sync infrastructure

Ensure sync service, Electric, and Baserow proxy are deployed and configured for prod.

### 5.3 — End-to-end test

Prod backend → ElectricSQL → sync engine → Baserow SaaS. Verify the full pipeline works.

---

## Future Work

- **Site-level applicability**: per-site selections within the org register
- **More vendors**: Nimonik, Wolters Kluwer CSV formats (add `extract/2` clauses)
- **AU jurisdiction**: import pipeline works for AU once AU scraper is complete
- **Automated screening**: ML/rules-based Fitness matching to replace manual L3 selection
