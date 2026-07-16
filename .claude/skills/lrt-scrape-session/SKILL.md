---
name: LRT Scrape Session
description: Human-AI partnered workflow for monthly LRT scrape sessions. Guides scope definition, monitors scrape progress, runs post-scrape QA (data completeness, family sense-check, relationship integrity), then promotes data through NAS sync and production sync with QA gates at each stage.
---

# LRT Scrape Session

## Overview

A human-AI partnered workflow for ingesting new UK legislation into the LRT database. The human drives the scrape via the admin UI; the AI provides QA, sense-checking, and data promotion through NAS and production sync stages.

**Typical cadence**: Monthly, covering all new laws published in a calendar month.

## Workflow Stages

```
 1. SCOPE          Human describes the scrape scope (e.g. "March 2026")
        ↓
 2. SCRAPE         Human runs the scrape session via admin UI
        ↓
 2b. REVIEW SKIPPED   AI reviews skipped records for errors ← CHECKPOINT
        ↓
 3. QA: POST-SCRAPE   AI validates persisted data ← STAGE GATE
        ↓
 4. NAS SYNC       AI exports snapshot to NAS
        ↓
 5. QA: POST-NAS   AI verifies NAS snapshot integrity ← STAGE GATE
        ↓
 6. PROD SYNC      AI exports delta and applies to production
        ↓
 7. QA: POST-PROD  AI verifies production data ← STAGE GATE
        ↓
 8. COMPLETE       Session finished, all stages passed
```

---

## Stage 1: SCOPE

The human provides the scrape scope. Parse the argument to determine parameters:

| User says | Interpretation |
|-----------|---------------|
| "March 2026" | year=2026, month=3, day_from=1, day_to=31 |
| "2026-04-01 to 2026-04-15" | year=2026, month=4, day_from=1, day_to=15 |
| "January 2026 ukpga only" | year=2026, month=1, day_from=1, day_to=31, type_code=ukpga |

**AI actions at this stage:**
1. Confirm the scope parameters with the human
2. Check if a session already exists for this scope:
   ```bash
   PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
   SELECT session_id, status, total_fetched, persisted_count
   FROM scrape_sessions
   WHERE year = {year} AND month = {month}
   ORDER BY inserted_at DESC LIMIT 5;
   "
   ```
3. Report any existing sessions (to avoid duplicate work)
4. Tell the human to proceed with the scrape in the admin UI

**What the human does**: Creates the session via the admin UI (`/admin/scraper`), reviews groups, parses records, confirms and persists them to uk_lrt.

**When the human is done**: They tell the AI "scrape is done" or "ready for QA".

---

## Stage 2: SCRAPE (Human-Driven)

The AI waits for the human to complete the scrape. The human will:
1. Create the session in the admin UI
2. Review categorized groups (Group 1: SI match, Group 2: terms match, Group 3: excluded)
3. Parse individual records (fetches XML metadata from legislation.gov.uk)
4. Confirm and persist records to uk_lrt

**AI can assist during this stage if asked** (e.g., explain a record, check a family assignment, look up an SI code).

---

## Stage 2b: REVIEW SKIPPED

After the human finishes scraping, AI reviews records marked as `skipped` to catch laws that were dismissed in error. Some laws have titles that look irrelevant but are actually in-scope for EHS compliance.

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT ssr.law_name, ssr.\"group\",
       COALESCE(ssr.parsed_data->>'Title_EN', u.title_en, ssr.law_name) as title
FROM scrape_session_records ssr
LEFT JOIN uk_lrt u ON u.name = ssr.law_name
WHERE ssr.session_id = '{session_id}' AND ssr.status = 'skipped'
  AND ssr.\"group\" IN ('group1', 'group2')
ORDER BY ssr.\"group\", ssr.law_name;
"
```

**Why only Group 1 and Group 2**: Group 3 records were excluded by the categorizer (no SI code or term match) — they're genuinely out of scope. Group 1 (SI match) and Group 2 (term match) were flagged as potentially relevant by the rules, so skipping them deserves a second look.

**AI reviews each skipped title and flags**:
- **RESTORE** — this looks like it should have been confirmed (e.g. an amendment to a key EHS Act, a safety regulation with an unusual title)
- **OK** — skip was correct (e.g. procedural, fees-only, geographical orders not relevant)

Present RESTOREs to the human. If agreed, the human can re-open the record in the UI (parse + confirm), or the AI can unskip it via:
```bash
# Unskip a record back to pending so it can be re-reviewed
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
UPDATE scrape_session_records
SET status = 'pending'
WHERE session_id = '{session_id}' AND law_name = '{law_name}' AND status = 'skipped';
"
```

---

## Stage 3: QA — Post-Scrape

Once the human signals the scrape is complete, run these checks. The session_id(s) for the scope should be identified first:

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT session_id, status, total_fetched, group1_count, group2_count, group3_count,
       persisted_count, title_excluded_count
FROM scrape_sessions
WHERE year = {year} AND month = {month}
  AND status IN ('completed', 'reviewing', 'categorized')
ORDER BY inserted_at DESC;
"
```

### 3a. Count Reconciliation

Verify the numbers add up:

```bash
# Records persisted in this session vs actual new uk_lrt rows
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT
  ss.session_id,
  ss.persisted_count AS session_persisted,
  COUNT(u.id) AS actual_new_lrt
FROM scrape_sessions ss
LEFT JOIN uk_lrt u ON u.year = ss.year
  AND u.inserted_at >= ss.inserted_at
  AND u.inserted_at <= COALESCE(ss.updated_at, NOW())
WHERE ss.year = {year} AND ss.month = {month}
GROUP BY ss.session_id, ss.persisted_count;
"
```

```bash
# Session record statuses - all should be confirmed or skipped
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT status, COUNT(*)
FROM scrape_session_records
WHERE session_id IN (
  SELECT id FROM scrape_sessions WHERE year = {year} AND month = {month}
)
GROUP BY status;
"
```

**Pass criteria**: No records in `pending` or `parsed` status (all should be `confirmed` or `skipped`).

### 3b. Data Completeness

Check newly persisted records have required fields:

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT name, title_en, type_code, year, number, family, geo_extent,
       function->>'Making' as making,
       function->>'Amending' as amending
FROM uk_lrt
WHERE year = {year}
  AND inserted_at > (SELECT MIN(inserted_at) FROM scrape_sessions WHERE year = {year} AND month = {month})
ORDER BY name;
"
```

**Check for**:
- `title_en` is NOT NULL for all records
- `type_code` is a known value (ukpga, uksi, ssi, wsi, nisr, ukla, asp, asc, anaw, ukcm, etc.)
- `year` and `number` are populated
- `geo_extent` is populated
- `function` has at least one true flag

**Flag** (not fail) records where `family` is NULL — these may be Group 3 records intentionally persisted without family, but should be noted.

### 3c. Family Sense-Check (AI Judgement) — Parser Improvement Loop

**Purpose**: Family is assigned **deterministically by the parser** during scraping, based on SI codes,
title keyword matching, and enacted_by relationships. This QA step uses the LLM to **review those
assignments and identify parser gaps**. Findings feed back into improving the parser — this is an
iterative loop, not a one-off check.

**What this step does**:
1. Review each newly scraped record's family assignment
2. Flag mismatches (parser assigned wrong family) and gaps (parser returned NULL)
3. For mismatches: correct the record AND investigate why the parser got it wrong
4. For gaps: determine the correct family AND identify what parser rule could cover it

**Known parser gaps**:
- **EU retained law** (eur, eudr, eudn) — parser has limited family assignment for EU types because
  they don't have UK SI codes. Many EU laws will have NULL family after scraping. This is a known
  gap, not an error. Family for EU laws needs to be inferred from title/subject or from the UK
  transposing SI's family.
- **Cross-domain laws** — some laws span multiple domains (e.g., energy laws touching both environment
  and OH&S). The parser picks one; the QA step checks if it's the right one.

**For monthly scrapes** (standard session):
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT name, title_en, family, type_code,
       si_code->>'value' as si_code_value
FROM uk_lrt
WHERE year = {year}
  AND inserted_at > (SELECT MIN(inserted_at) FROM scrape_sessions WHERE year = {year} AND month = {month})
ORDER BY name;
"
```

**For import sessions** (customer onboarding):
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.family, u.type_code
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{session_id}' AND ssr.status = 'confirmed'
ORDER BY u.type_code, u.name;
"
```

**The 51 families** fall into 3 domains with emoji prefixes:
- **💙 Blue heart** Health & Safety (OH&S, Fire, Food, Transport Safety, etc.)
- **💚 Green heart** Environment (Waste, Water, Agriculture, Climate, etc.)
- **💜 Purple heart** HR (Employment, Working Time, Insurance/Compensation)

For each record, ask: "Does the title of this law logically fit the assigned family?"

**Common mismatches to watch for**:
- Transport laws assigned to environment families (or vice versa) — e.g., "Road Traffic" could be safety OR environment
- Food safety vs agriculture — processing/hygiene is Food, farming/livestock is Agriculture
- Building safety vs planning — structural safety is Building Safety, land use is Planning
- Energy laws — could be Environment (green energy) or OH&S (gas safety)
- "Regulations" that amend an Act — family should match the parent Act's domain, not the SI's surface topic

**Output format**: List each record with a verdict:
- **OK** — family assignment is sensible
- **QUERY** — family is plausible but worth a second look (explain why)
- **SUSPECT** — family doesn't match the title's domain (suggest correct family)
- **GAP** — family is NULL and parser has no rule for this law type (suggest family + parser improvement)

Present QUERYs, SUSPECTs, and GAPs to the human for decision. The human may:
- Confirm the assignment is correct (override AI judgement)
- Agree and ask AI to update the family
- File a parser improvement (for GAPs that recur across sessions)
- Defer to a later review

### 3d. Relationship Integrity

```bash
# Check amending records have targets
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.function->>'Amending' as amending
FROM uk_lrt u
WHERE u.year = {year}
  AND u.inserted_at > (SELECT MIN(inserted_at) FROM scrape_sessions WHERE year = {year} AND month = {month})
  AND (u.function->>'Amending')::boolean = true
  AND NOT EXISTS (
    SELECT 1 FROM law_edges e WHERE e.source_law = u.name AND e.edge_type = 'amends'
  );
"
```

```bash
# Check enacted_by links resolve to valid parents
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT e.source_law, e.target_law,
       CASE WHEN p.id IS NULL THEN 'ORPHAN' ELSE 'OK' END as status
FROM law_edges e
LEFT JOIN uk_lrt p ON p.name = e.target_law
WHERE e.edge_type = 'enacted_by'
  AND e.source_law IN (
    SELECT name FROM uk_lrt WHERE year = {year}
    AND inserted_at > (SELECT MIN(inserted_at) FROM scrape_sessions WHERE year = {year} AND month = {month})
  );
"
```

**Flag**: Amending records without amend edges, enacted_by links pointing to non-existent parents.

### 3e. Duplicate Check

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT name, COUNT(*) as cnt
FROM uk_lrt
WHERE year = {year}
GROUP BY name
HAVING COUNT(*) > 1;
"
```

**Fail criteria**: Any duplicates found.

### QA Gate Decision

Present a summary to the human:

```
## Post-Scrape QA Summary

**Session**: {session_id} ({month_name} {year})
**Records persisted**: {count}

| Check | Result |
|-------|--------|
| Count reconciliation | PASS/FAIL |
| Data completeness | PASS/FAIL ({n} issues) |
| Family sense-check | {n} OK, {n} QUERY, {n} SUSPECT |
| Relationship integrity | PASS/FAIL ({n} orphans) |
| Duplicate check | PASS/FAIL |

**Recommendation**: PROCEED / HOLD (fix issues first)
```

The human decides whether to proceed to NAS sync.

---

## Stage 4: NAS Sync

Export the dev database snapshot to NAS:

```bash
cd /var/home/jason/Desktop/sertantai-legal

# Archive the previous snapshot first
./scripts/nas/nas-backup.sh --archive
```

**Pre-flight checks**:
1. NAS is mounted: `ls /mnt/nas/sertantai-data/data/snapshots/latest/`
2. If not mounted, access to trigger automount: `ls /mnt/nas/sertantai-data/`

**Monitor the export**: The script outputs per-table progress with row counts and file sizes.

---

## Stage 5: QA — Post-NAS Sync

Verify the snapshot landed correctly:

```bash
# Check manifest exists and is recent
cat /mnt/nas/sertantai-data/data/snapshots/latest/manifest.json | python3 -m json.tool
```

**Verify**:
1. `manifest.json` timestamp is from this session (within last hour)
2. All expected tables are present with non-zero row counts
3. File checksums match (the import script can verify):
   ```bash
   ./scripts/nas/import-snapshot.sh --verify-only
   ```
4. uk_lrt row count in manifest matches dev database:
   ```bash
   PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "SELECT COUNT(*) FROM uk_lrt;"
   ```

### QA Gate Decision

```
## Post-NAS QA Summary

| Check | Result |
|-------|--------|
| Manifest timestamp | {timestamp} — FRESH/STALE |
| Tables present | {n}/{expected} |
| Checksum verification | PASS/FAIL |
| uk_lrt row count | NAS={nas_count}, Dev={dev_count} — MATCH/MISMATCH |

**Recommendation**: PROCEED to prod sync / HOLD
```

---

## Stage 6: Production Sync

Export a delta from dev and apply to production. Use the delta approach for incremental updates.

### 6a. Export Delta

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend

# Export changes since last sync (use appropriate timestamp)
# The timestamp should be from the last successful prod sync
mix run ../scripts/sync/export_delta.exs --since "{last_sync_timestamp}" --output-dir ../scripts/sync/
```

If this is the first sync for these tables or you're unsure of the last timestamp, check:
```bash
ls -la ../scripts/sync/delta_*.sql ../scripts/sync/delta_*_manifest.json 2>/dev/null
```

### 6b. Review Delta

Before applying, review the delta manifest:
```bash
cat ../scripts/sync/delta_*_manifest.json | python3 -m json.tool
```

Check:
- Row counts per table are reasonable
- No unexpected tables included
- File size is reasonable (not suspiciously large or empty)

### 6c. Apply to Production

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend

# Apply delta to production (will prompt for confirmation)
TARGET_DATABASE_URL="postgresql://postgres:{prod_password}@localhost/sertantai_legal_prod" \
  mix run ../scripts/sync/apply_delta.exs ../scripts/sync/{delta_file}.sql
```

**Note**: Production PostgreSQL is only reachable via SSH pipe. The actual command uses:
```bash
cat ../scripts/sync/{delta_file}.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod"
```

---

## Stage 7: QA — Post-Production Sync

Verify production data matches expectations:

```bash
# Check production row counts
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c '
SELECT COUNT(*) as total_lrt FROM uk_lrt;
'"

# Check the new records exist on prod
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c \"
SELECT COUNT(*) as new_records
FROM uk_lrt
WHERE year = {year}
  AND name LIKE 'UK_%_{year}_%';
\""

# Compare dev vs prod counts for key tables
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c '
SELECT
  (SELECT COUNT(*) FROM uk_lrt) as uk_lrt_count,
  (SELECT COUNT(*) FROM lat) as lat_count,
  (SELECT COUNT(*) FROM scrape_sessions) as sessions_count;
'"
```

**Compare with dev**:
```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT
  (SELECT COUNT(*) FROM uk_lrt) as uk_lrt_count,
  (SELECT COUNT(*) FROM lat) as lat_count,
  (SELECT COUNT(*) FROM scrape_sessions) as sessions_count;
"
```

### QA Gate Decision

```
## Post-Production QA Summary

| Table | Dev | Prod | Delta |
|-------|-----|------|-------|
| uk_lrt | {dev} | {prod} | {diff} |
| lat | {dev} | {prod} | {diff} |
| scrape_sessions | {dev} | {prod} | {diff} |

**New {year} records on prod**: {count}
**Recommendation**: COMPLETE / INVESTIGATE (counts diverge)
```

---

## Stage 8: COMPLETE

All stage gates passed. Summarise the session:

```
## LRT Scrape Session Complete

**Scope**: {month_name} {year}
**Records scraped**: {total_fetched}
**Records persisted**: {persisted_count}
**Family QA**: {ok_count} OK, {query_count} reviewed, {suspect_count} corrected
**NAS snapshot**: Updated ({timestamp})
**Production sync**: Applied ({delta_file})
**All QA gates**: PASSED
```

---

## Key Files

| Purpose | Path |
|---------|------|
| Session Manager | `backend/lib/sertantai_legal/scraper/session_manager.ex` |
| Scrape Controller | `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex` |
| Session Resource | `backend/lib/sertantai_legal/scraper/resources/scrape_session.ex` |
| Session Record Resource | `backend/lib/sertantai_legal/scraper/resources/scrape_session_record.ex` |
| UK LRT Resource | `backend/lib/sertantai_legal/legal/uk_lrt.ex` |
| Categorizer | `backend/lib/sertantai_legal/scraper/categorizer.ex` |
| Filters | `backend/lib/sertantai_legal/scraper/filters.ex` |
| Family models (SI mapping) | `backend/lib/sertantai_legal/scraper/models.ex` |
| HS search terms | `backend/lib/sertantai_legal/scraper/terms/health_safety.ex` |
| Env search terms | `backend/lib/sertantai_legal/scraper/terms/environment.ex` |
| SI code registry | `backend/lib/sertantai_legal/scraper/terms/si_codes.ex` |
| NAS export script | `scripts/nas/nas-backup.sh` |
| NAS import script | `scripts/nas/import-snapshot.sh` |
| Delta export | `scripts/sync/export_delta.exs` |
| Delta apply | `scripts/sync/apply_delta.exs` |

## Related Skills

- [NAS Data Sync](../nas-data-sync/) — NAS mount config, export/import details
- [Production Data Sync](../prod-data-sync/) — Delta export/apply, SSH pipeline, trigger management
- [Production Deployment](../production-deployment/) — Full deployment pipeline
- [Enacted By QA](../enacted-by-qa/) — QA of enacted_by parser results (complementary)
- [Amends Family QA](../amends-family-qa/) — Family classification QA via amends graph
