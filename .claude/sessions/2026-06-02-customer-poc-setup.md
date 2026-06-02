# Title: New Customer POC Setup Workflow

**Started**: 2026-06-02 08:45

## Todo
- [x] Confirm what exists: sync tables, entitlements, Baserow provider — all complete
- [x] Audit hub org/user creation — hub is read-only, creation via sertantai-auth
- [x] Analyse Enhesa CSV structure and matching potential
- [x] Build generic legacy register import/matching mix task
- [x] Test import tool with Enhesa CSV on dev
- [x] Create scrape session for scrapeable unmatched laws
- [ ] Set up org + user in sertantai-auth (for Jason's day-job org)
- [ ] Push entitlement to sertantai-legal via webhook
- [ ] Create sync profile + Baserow config, trigger sync
- [ ] Deploy to prod
- [x] Codify Phase 1 into skill: .claude/skills/customer-onboarding-import/
- [ ] Codify remaining phases into skills (hub setup, scrape session, sync)

## Import/Matching Tool Design

### Goal
Generic `mix legal.import_register` task that takes any vendor CSV, transforms → matches → groups results.

### Input
- CSV file path
- Column mapping config (which columns hold title, year, SI number, applicability, site name)
- Enhesa is first vendor; design for future vendors (Nimonik, Wolters Kluwer, etc.)

### CRITICAL: UK Law Identity
- A UK law is uniquely identified by **type_code + year + number** (e.g. uksi/1998/2306)
- Year + number alone is NOT unique — e.g. 2019/1 exists as 6 different laws (ukcm, ukmo, asp, anaw, ssi, ukpga)
- Type code inference is therefore REQUIRED before matching, not optional
- The uk_lrt `name` field encodes this: `UK_{type_code}_{year}_{number}`

### Pipeline

**Step 1: Extract + Infer Type Code** — Parse CSV, apply column mapping, infer type_code from title
- Output: list of `%{vendor_id, title, year, number, type_code, answer, site_name}`
- Type code inference rules (English law context — no Scottish/NI Acts):
  - "...Regulations YYYY (S.I. NNN)" → uksi
  - "...Order YYYY (S.I. NNN)" → uksi
  - "...Rules YYYY (S.I. NNN)" → uksi
  - "...Act YYYY" → ukpga (English context, no asp/nia)
  - "Regulation EC/..." or "Regulation EU/..." → eur
  - "Commission Regulation EC/..." or "Commission Implementing Regulation EU/..." → eur
  - "Directive .../...EC" or "Directive .../...EU" → eudr
  - "Council Directive ..." → eudr
  - "Decision .../...EC" → eudn
  - ACOPs / Approved Code of Practice / guidance (L-series, EH40) → acop (not scrapeable)
  - International conventions (ADR, RID, ICAO) → intl (not scrapeable)
- Laws where type_code cannot be inferred → unknown (needs manual review)

**Step 2: Match** — Query uk_lrt using type_code + year + number (the unique key)
- Primary: type_code + year + number (exact match on `name` field = `UK_{type_code}_{year}_{number}`)
- Fallback: type_code + year + title_en ILIKE (for laws where number wasn't parsed)
- NEVER match on year + number alone — guaranteed ambiguity
- Output: each row gets `{match_status, lrt_id, lrt_name, family}`

**Step 3: Group** — Classify results into 3 buckets
1. **matched** — found in LRT → ready for sync profile
2. **scrapeable** — not in LRT but type_code is scrapeable (uksi, ukpga, eur, eudr, etc.) → create scrape session
3. **not_handled** — ACOPs, international conventions, unidentifiable → report only

**Step 4: Output**
- Auto-create scrape session (group 2) with ScrapeSessionRecord entries
- Family summary of matched laws (drives sync profile creation)

### File Storage
- JSON output NOT git tracked (backend/data/ is gitignored)
- Local working dir: `backend/data/imports/{customer-slug}/`
- NAS archive: `/mnt/nas/sertantai-data/data/imports/{customer-slug}/`
- Files per import:
  - `source.csv` — original vendor CSV (audit trail)
  - `extracted.json` — step 1 output: parsed rows with inferred type_codes
  - `matched.json` — step 2-3 output: grouped results (matched/scrapeable/not_handled)
- Mix task writes locally, then copy to NAS for persistence

### Key Data Points
- Enhesa CSV: 715 laws, 226 Yes, 92 No, 397 blank
- ~100 EU Regulations/Directives (eur/eudr) — scrapeable from legislation.gov.uk retained EU law
- ~15 ACOPs — not legislation, not scrapeable
- ~5 international conventions — not scrapeable

### Site-Level Applicability
- Answer column = site-level applicability (Yes/No/blank)
- Org aggregate = union of all site CSVs
- Per-site subset stored separately (future: per-site sync profiles)
- Current sync profiles filter by family, not individual law — acceptable for POC

## Progress
**09:45** Phase 1 complete. mix legal.import_register built and tested.
**10:15** Scrape session created: import-qq-bsc (232 records, 50 UK domestic, 182 EU retained).
- 715 laws → 0 unknowns (type_code inference), 428 matched, 255 scrapeable, 32 not handled
- Outputs: backend/data/imports/qq/bsc/{source.csv, extracted.json, matched.json}
- Skill created: .claude/skills/customer-onboarding-import/
- Key file: backend/lib/mix/tasks/legal.import_register.ex
- Next: scrape session for 255 scrapeable laws, then org/user/entitlement setup
**10:30** Fixed major type_code inference bugs (Act year vs SI year, Acts with S.I. chapter refs).
- Added --qa flag for post-scrape title comparison. 479 matched, 416 titles agree, 63 mismatches.
- Mismatches are all formatting/cosmetic — no wrong-law matches after fix.
- Scrape session import-qq-bsc: 232 records (50 UK domestic, 182 EU retained). User scraped 50 group1.
**11:15** Post-scrape QA found 19+2 wrong laws in uk_lrt from buggy inference. Cleaned up.
- Fixed S.I. YYYY No. NNNN transposition bug (Pyrotechnic Articles 2010/1554 → 1554/2010)
- Fixed Acts with (S.I.NN) — now discards vendor number, matches by title instead
- Added title-based fallback matching for Acts without chapter number
- Equality Act 2010 (S.I.51) now correctly matches UK_ukpga_2010_15 (chapter 15)
- Final: 481 matched, 202 scrapeable, 32 not handled. Session: 31 confirmed + 182 pending.
**11:30** Added --status-report flag. Generates status-report.json for customer.
- 270 in force, 132 part revoked, 54 revoked, 25 unknown
- 6 revoked laws marked Yes (customer tracking dead law) — flagged for customer
- Revoked law will NOT be synced. Only in-force + part-revoked go to sync profile.

## Customer Details
- Customer slug: QQ
- Site slug for Enhesa CSV: BSC
- Local: backend/data/imports/qq/bsc/
- NAS: /mnt/nas/sertantai-data/data/imports/qq/bsc/

## Notes
- sertantai-hub is read-only for orgs/users — creation via sertantai-auth
- Hub → legal entitlement push doesn't exist yet — call legal webhook directly
- Baserow is SaaS (not self-hosted) for this customer
- Scrape sessions: backend/lib/sertantai_legal/scraper/resources/scrape_session.ex
- Scrape records: backend/lib/sertantai_legal/scraper/resources/scrape_session_record.ex
- uk_lrt name format: UK_{type_code}_{year}_{number} e.g. UK_uksi_1998_2306
