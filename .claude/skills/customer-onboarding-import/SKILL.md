---
name: Customer Onboarding - Legacy Register Import
description: Import a customer's legacy legal register CSV (Enhesa, Nimonik, etc.), transform and match against LRT, group results into matched/scrapeable/not-handled, and create a scrape session for missing laws. First phase of customer onboarding.
---

# Customer Onboarding: Legacy Register Import

## Overview

When a new customer joins SertantAI, they typically arrive with a legacy legal register from a previous vendor (Enhesa, Nimonik, Wolters Kluwer, etc.). This skill covers importing that register, matching it against the existing LRT database, and setting up the data pipeline for any missing laws.

**This is Phase 1 of customer onboarding.** Later phases cover org/user creation, entitlement setup, sync profile configuration, and Baserow sync.

## Prerequisites

- Dev database running with current LRT data (`docker-compose -f docker-compose.dev.yml up -d postgres`)
- Customer's legacy register as CSV
- Customer slug and site slug agreed

## Workflow

```
1. RECEIVE CSV       Customer provides legacy register export
       ↓
2. EXTRACT + INFER   mix legal.import_register --dry-run
       ↓
3. REVIEW EXTRACTION Check type code inference, fix any unknowns
       ↓
4. MATCH + GROUP     mix legal.import_register (full run)
       ↓
5. REVIEW RESULTS    Inspect matched.json — families, scrapeable breakdown
       ↓
6. QA: TITLE CHECK   mix legal.import_register --qa
       ↓
7. STATUS REPORT     mix legal.import_register --status-report
       ↓
8. SCRAPE SESSION    mix legal.import_register --create-scrape-session
       ↓
9. SCRAPE + QA       Human scrapes via admin UI, then --qa to verify
       ↓
10. ARCHIVE TO NAS   Copy outputs to /mnt/nas/sertantai-data/data/imports/
```

## Step 1: Receive and Place CSV

Place the customer's CSV in `backend/data/` (this directory is gitignored).

```bash
# Example: Enhesa export for customer QQ, site BSC
cp ~/Downloads/en_UKD_-_B_Regulation_Questions.csv backend/data/
```

## Step 2: Extract + Dry Run

Run the import task in dry-run mode first to verify extraction and type code inference:

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug> --dry-run
```

Example:
```bash
mix legal.import_register backend/data/en_UKD_-_B_Regulation_Questions.csv \
  --customer qq --site bsc --dry-run
```

### What the Extraction Does

1. **Parses CSV** using vendor-specific column mapping (currently: Enhesa)
2. **Infers type_code** from each law's title — this is CRITICAL because:
   - A UK law is uniquely identified by **type_code + year + number**
   - Year + number alone is NOT unique (e.g. 2019/1 exists as 6 different laws)
   - The `uk_lrt.name` field encodes this: `UK_{type_code}_{year}_{number}`
3. **Writes `extracted.json`** to `data/imports/{customer}/{site}/  (relative to backend/)`

### Type Code Inference Rules

| Title Pattern | Inferred Type | Notes |
|---|---|---|
| "...Regulations YYYY (S.I. NNN)" | uksi | SI with number |
| "...Order/Rules YYYY (S.I. NNN)" | uksi | SI with number |
| "...Regulations/Order/Rules YYYY" | uksi | SI without number (title match fallback) |
| "...Act YYYY" | ukpga | English context — no asp/nia |
| "...Act YYYY (c. NN)" | ukpga | With chapter number |
| "Regulation EC/NNN/YYYY" | eur | EU Regulation |
| "Regulation (EU) YYYY/NNN" | eur | EU Regulation |
| "Directive YYYY/NNN/EC" | eudr | EU Directive |
| "Council Directive NN/NNN/EEC" | eudr | Older EU Directive |
| "Decision YYYY/NNN/EC" | eudn | EU Decision |
| "Approved Code of Practice (LNNN)" | acop | Not legislation, not scrapeable |
| "ADR/RID/ICAO/IMDG" | intl | International, not scrapeable |

### Dry Run Output

Review the output for:
- **Type code distribution** — aim for 0 unknowns
- **"With full LRT name" count** — rows where type_code + year + number all parsed
- **Answer distribution** — site-level applicability (Yes/No/blank)

If unknowns remain, investigate the titles and consider adding inference rules to `infer_identity/1` in the mix task.

## Step 3: Full Run (Match + Group)

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug>
```

This adds Step 2 (DB matching) and Step 3 (grouping) to the extraction:

### Matching Strategy

1. **Primary**: Exact match on `uk_lrt.name = UK_{type_code}_{year}_{number}`
2. **Fallback (Acts)**: type_code + year + title ILIKE (for laws without number, e.g. Acts where vendor-supplied chapter numbers are unreliable)
3. **Last resort**: `uk_lrt.name LIKE UK_{type_code}_{year}_%` (ambiguous, may return wrong law)
4. **Never** match on year + number alone

### Result Groups

| Group | Meaning | Next Action |
|---|---|---|
| **matched** | Found in LRT | Ready for sync profile. Includes lrt_id, lrt_name, family |
| **scrapeable** | Not in LRT, but type is scrapeable from legislation.gov.uk (uksi, ukpga, eur, eudr, eudn) | Create scrape session |
| **not_handled** | ACOPs, international conventions, unidentifiable | Report only — manual decision |

### Output Files

```
data/imports/{customer}/{site}/  (relative to backend/)
├── source.csv           # Original vendor CSV (audit trail)
├── extracted.json       # Parsed rows with inferred type codes
├── matched.json         # Grouped results with LRT matches
└── status-report.json   # Live/revoked breakdown for customer (--status-report)
```

### Review Checklist

After the full run, check:

- [ ] **Match rate** — typically 50-70% for a first import (depends on LRT coverage)
- [ ] **"No family" matched laws** — these exist in LRT but haven't been classified. May need family QA.
- [ ] **Scrapeable breakdown by type** — EU laws (eudr/eur) are the largest scrapeable group
- [ ] **Not handled count** — should be small (ACOPs, international conventions)
- [ ] **Answer=Yes laws in scrapeable** — high-priority missing laws that the site actively uses

## Step 4: Post-Scrape QA — Title Comparison

After the initial match (or after scraping missing laws), run title QA to verify matched laws are correct:

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug> --qa
```

This compares the vendor title against the LRT `title_en` for every matched law. Titles are cleaned (stripped of "The", SI refs, years, normalised unicode) before comparison.

### Expected Output

- **Titles agree**: ~85-90% — most should match
- **Mismatches**: Usually cosmetic (formatting, abbreviations, unicode dashes/apostrophes)
- **WRONG LAW mismatches**: Should be 0. If vendor title is completely different from LRT title, the type_code inference has a bug.

### Common Cosmetic Mismatches (safe to ignore)

- Missing spaces: `(England)Regulations` vs `(England) Regulations`
- COSHH abbreviation in vendor, absent in LRT
- Unicode apostrophes: `´` vs `'`
- EU citation format: `EC/166/2006` vs `(EC) No 166/2006`
- Typos in LRT: "Totalisting" vs "Totalising"

### If Wrong Laws Are Found

The scrape session will have persisted wrong laws into `uk_lrt`. You MUST:

1. Identify the wrong law names from the QA output
2. Delete them from `legal_register` (the underlying table for `uk_lrt` view)
3. Delete the corresponding scrape session records
4. Fix the inference bug in `infer_identity/1`
5. Re-run extraction and recreate session records

## Step 5: Status Report

Generate a status report showing which matched laws are in force vs revoked:

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug> --status-report
```

### Output: `status-report.json`

```json
{
  "summary": {
    "total_matched": 481,
    "in_force": 270,
    "part_revoked": 132,
    "revoked": 54,
    "unknown_status": 25,
    "revoked_but_applicable": 6
  },
  "revoked_but_applicable": [ ... ],
  "revoked": [ ... ],
  "in_force": [ ... ],
  ...
}
```

### Key Section: `revoked_but_applicable`

Laws where `live_status` = revoked/repealed AND `answer` = "Yes" (site says applicable). These are **dead laws the customer is actively tracking** — flag to the customer.

### Sync Policy

- **In force** → sync to Baserow
- **Part revoked** → sync (still partially active)
- **Revoked/Repealed** → do NOT sync (dead law)
- **Unknown status** → review manually before syncing

## Step 6: Create Scrape Session

Create a scrape session for laws not yet in the LRT:

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug> --create-scrape-session
```

This creates session `import-{customer}-{site}` with:
- **Group 1** (UK domestic: uksi, ukpga) — scrapeable from legislation.gov.uk
- **Group 2** (EU retained: eur, eudr, eudn) — scrapeable from legislation.gov.uk/eu

Duplicates are collapsed via upsert on `(session_id, law_name)`.

### Post-Scrape Workflow

After the human scrapes group 1 via the admin UI at `/admin/scrape/sessions`:

1. Re-run `--qa` to verify scraped titles match vendor expectations
2. If mismatches found → clean up wrong laws (see Step 4)
3. Re-run `--status-report` with updated matches
4. Proceed to group 2 (EU retained)

### Combined Run

All flags can be combined in a single invocation:

```bash
mix legal.import_register backend/data/<filename>.csv \
  --customer <slug> --site <slug> \
  --qa --status-report --create-scrape-session
```

## Step 7: Archive to NAS

```bash
# Ensure NAS is mounted
ls /mnt/nas/sertantai-data/data/

# Create customer directory and copy (run from backend/)
mkdir -p /mnt/nas/sertantai-data/data/imports/{customer}/{site}
cp -r data/imports/{customer}/{site}/* \
  /mnt/nas/sertantai-data/data/imports/{customer}/{site}/
```

## Adding a New Vendor

To support a new CSV format, add a new clause to `extract/2` in `backend/lib/mix/tasks/legal.import_register.ex`:

```elixir
defp extract(csv_path, "nimonik") do
  # Parse CSV with Nimonik-specific column names
  # Map to the standard shape: %{vendor_id, title, type_code, year, number, ...}
end
```

Then call with `--vendor nimonik`.

## Key Files

| File | Purpose |
|---|---|
| `backend/lib/mix/tasks/legal.import_register.ex` | The import/matching mix task |
| `backend/data/imports/` | Local output directory (gitignored) |
| `/mnt/nas/sertantai-data/data/imports/` | NAS archive |

## Critical Rules

1. **Never match by year + number alone** — type_code is part of the unique key
2. **Type code inference must happen before matching** — it's the gating step
3. **Keep source CSV** — audit trail for every import
4. **Archive to NAS** — local data dir is ephemeral

## Troubleshooting

### High Unknown Count
- Check the titles of unknown rows in `extracted.json`
- Add patterns to `infer_identity/1` — the rules are ordered by specificity
- EU law title formats vary wildly between vendors

### Low Match Rate
- Check if LRT has the right type codes: `SELECT type_code, COUNT(*) FROM uk_lrt GROUP BY type_code`
- Vendor may use different title formats — compare `extracted.json` titles against `uk_lrt.title_en`
- Some laws may genuinely not be in the LRT yet → they'll appear in the scrapeable group

### Wrong Laws Scraped (DATA INTEGRITY)
If the post-scrape QA (`--qa`) shows completely wrong titles, the scrape session persisted wrong
laws into `uk_lrt`. This is the most serious issue. To fix:

```sql
-- 1. Delete wrong laws from the master table
DELETE FROM legal_register WHERE name IN ('UK_uksi_YYYY_NNNN', ...);

-- 2. Delete wrong session records
DELETE FROM scrape_session_records WHERE session_id = 'import-xx-yy' AND law_name IN (...);

-- 3. Update session counts
UPDATE scrape_sessions SET group1_count = (SELECT COUNT(*) ...) WHERE session_id = '...';
```

Then fix the inference bug and re-run.

### Known Enhesa Inference Pitfalls (fixed)

1. **Act year vs SI year**: "H&S at Work Act 1974... Regulations 2013 (S.I. 1667)" — the year for
   the SI is 2013, not 1974. The regex must grab the year immediately before `(S.I.` not the first year.

2. **`S.I. YYYY No. NNNN` transposition**: "Regulations 2010 (S.I. 2010 No. 1554)" — the year is
   2010 and the number is 1554. Without an explicit pattern for this format, the number gets read
   as 2010 and the year as 1554 (because `1\d{3}` matches it as a year).

3. **Acts with `(S.I.NN)` — wrong chapter numbers**: Enhesa puts `(S.I.51)` on the Equality Act
   2010, but the real chapter is 15. The fix: discard vendor-supplied numbers for Acts, match by
   title instead. Official `(c.NN)` chapter references are trustworthy; Enhesa's `(S.I.NN)` on Acts
   are not.

### JSON Encoding Errors
- UUID fields from SQL must be cast to text: `SELECT id::text FROM uk_lrt`
- Binary fields (bytea) cannot be JSON-encoded directly

## Data Promotion (NAS + Production)

After import, QA, and scraping are complete, promote the data using the **LRT Scrape Session** skill
stages 4-8. The import-specific QA (title comparison, status report) replaces stages 1-3 of that
skill, but the data promotion pipeline is identical:

1. **NAS Sync** (lrt-scrape Stage 4): `./scripts/nas/export-snapshot.sh --archive`
2. **Post-NAS QA** (lrt-scrape Stage 5): verify manifest, checksums, row counts
3. **Prod Sync** (lrt-scrape Stage 6): export delta, review, apply via SSH pipe
4. **Post-Prod QA** (lrt-scrape Stage 7): compare dev vs prod counts

**Import session differences from monthly scrape**:
- Session type is `import` not `nil` — filter queries by `session_id = 'import-{customer}-{site}'`
- Records span multiple years/type_codes — don't filter by `year` or `month`
- Status report (`--status-report`) replaces the family sense-check stage — revoked laws are already flagged

See the [LRT Scrape Session skill](../lrt-scrape-session/) for the full NAS/prod pipeline details.

## Related Skills

- **[LRT Scrape Session](../lrt-scrape-session/)** — NAS sync, prod sync, and post-sync QA (stages 4-8)
- **[NAS Data Sync](../nas-data-sync/)** — NAS mount config, export/import scripts
- **[Production Data Sync](../prod-data-sync/)** — Delta export/apply, SSH pipeline
- **[Production Deployment](../production-deployment/)** — Full deployment pipeline
