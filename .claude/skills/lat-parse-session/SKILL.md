---
name: LAT Parse Session
description: Human-AI partnered workflow for LAT (Legal Article Text) parsing sessions. Guides making-classification review, monitors parse progress, runs post-parse QA (LAT shape, hierarchy integrity, annotation sanity), triggers taxa enrichment via Zenoh, then promotes data through NAS sync and production sync with QA gates at each stage.
---

# LAT Parse Session

## Overview

A human-AI partnered workflow for parsing UK legislation body text into structured LAT (Legal Article Text) records. The human drives the parse via the admin UI; the AI provides QA, sense-checking, and data promotion through NAS and production sync stages.

**Prerequisite**: An LRT scrape session should be completed first (laws must exist in uk_lrt before they can be LAT-parsed). Use the `lrt-scrape-session` skill for that.

**Typical cadence**: After each LRT scrape session, or ad-hoc for stale/missing LAT.

## Workflow Stages

```
 1. SCOPE & CLASSIFY    Human selects LRT session or family; AI reviews making_classification
        ↓
 2. SESSION CREATION    AI creates LAT parse session from confirmed scope
        ↓
 3. PARSE               Human runs parsing via admin UI (SSE streaming)
        ↓
 4. QA: LAT SHAPE       AI validates LAT record structure ← STAGE GATE
        ↓
 5. TAXA ENRICHMENT     AI triggers Zenoh taxa service, verifies results
        ↓
 6. QA: TAXA RESULTS    AI validates taxa/fitness data ← STAGE GATE
        ↓
 7. NAS SYNC            AI exports snapshot to NAS
        ↓
 8. QA: POST-NAS        AI verifies NAS snapshot integrity ← STAGE GATE
        ↓
 9. PROD SYNC           AI exports delta and applies to production
        ↓
10. QA: POST-PROD       AI verifies production data ← STAGE GATE
        ↓
11. COMPLETE            Session finished, all stages passed
```

---

## Stage 1: SCOPE & CLASSIFY

The human provides context — typically "parse the laws from the April 2026 scrape session" or "parse missing LAT for OH&S family."

### 1a. Identify Target Laws

**If filtering by LRT session** (most common after a scrape):

Direct the human to the LAT Queue (`/admin/lat/queue`) and select the LRT session from the dropdown. This filters to only laws persisted in that session.

```bash
# Check which sessions are available and their persisted counts
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT session_id, year, month, day_from, day_to, status, persisted_count
FROM scrape_sessions
WHERE session_type IS NULL OR session_type != 'lat_parse'
ORDER BY inserted_at DESC LIMIT 10;
"
```

**If filtering by family or queue view**: Use the LAT Queue sidebar views.

### 1b. Review Making Classification

This is the critical pre-parse QA step. The LAT parser only produces meaningful results for "making" laws (those that create duties/responsibilities). Before parsing, review the auto-detected `making_classification` and set `making_review` for all target laws.

**Three-stage making lifecycle:**
1. `making_classification` — auto-detected by MakingDetector during scrape (immutable)
2. `making_review` — human-AI review set during this stage (overrides auto for queue/Function)
3. `is_making` — definitive, set by taxa after full-text parsing

```bash
# Show auto-classification distribution for a session's laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.making_classification AS auto, u.making_review AS review, COUNT(*) as count
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lrt_session_id}' AND ssr.status = 'confirmed'
GROUP BY u.making_classification, u.making_review
ORDER BY u.making_classification, u.making_review;
"
```

```bash
# List laws needing review (uncertain, NULL auto-classification, or no review yet)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.making_classification AS auto, u.making_review AS review, u.type_code
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lrt_session_id}' AND ssr.status = 'confirmed'
  AND u.making_review IS NULL
  AND (u.making_classification IS NULL OR u.making_classification != 'not_making')
ORDER BY u.making_classification, u.name;
"
```

**AI reviews each uncertain/NULL law and recommends**:
- **MAKING** — title or type indicates duties/responsibilities (regulations, safety orders, standards)
- **NOT_MAKING** — procedural, fees, commencement, geographical orders
- **UNCERTAIN** — genuinely ambiguous, parse anyway and let LAT results decide

**Common patterns**:
- SIs amending making Acts → likely "making" (they modify duties)
- "Commencement Order" → not_making (just sets effective dates)
- "Fees Regulations" → not_making (financial, not duty-setting)
- "Amendment Regulations" with safety/environment parent → making
- Acts with "Safety", "Health", "Environment", "Protection" in title → making

Present recommendations to the human. They can update reviews inline in the LAT Queue grid (double-click the "Review" column) or AI can apply via SQL.

### 1c. Confirm Scope and Apply Reviews

Once the human confirms which laws to parse:

1. **Set `making_review = 'making'`** for laws selected for parsing
2. **Infer `making_review = 'not_making'`** for all unselected session laws — by choosing not to parse them, the human implicitly reviewed them as not_making

```bash
# Apply reviews: selected laws → making
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
UPDATE uk_lrt SET making_review = 'making', making_review_at = NOW()
WHERE name IN ({selected_law_names_comma_separated})
RETURNING name, making_classification AS auto, making_review AS review;
"
```

```bash
# Infer reviews: unselected session laws → not_making
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
UPDATE uk_lrt SET making_review = 'not_making', making_review_at = NOW()
WHERE name IN (
  SELECT u.name FROM uk_lrt u
  JOIN scrape_session_records ssr ON ssr.law_name = u.name
  WHERE ssr.session_id = '{lrt_session_id}' AND ssr.status = 'confirmed'
    AND u.making_review IS NULL
)
RETURNING name, making_classification AS auto, making_review AS review;
"
```

This ensures every session law has a `making_review` after scoping — no NULLs left.

```bash
# Final count: laws to parse (making_review = 'making')
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT COUNT(*) as laws_to_parse
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lrt_session_id}' AND ssr.status = 'confirmed'
  AND u.making_review = 'making';
"
```

Check for existing LAT sessions covering the same scope:

```bash
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT session_id, status, group1_count, persisted_count,
       lat_total_inserted, lat_total_annotations
FROM scrape_sessions
WHERE session_type = 'lat_parse'
ORDER BY inserted_at DESC LIMIT 5;
"
```

**Confirm with the human**: "{N} laws reviewed as making from session {lrt_session_id}. {M} reviewed as not_making (inferred from non-selection). Proceed to session creation?"

---

## Stage 2: SESSION CREATION

The human creates the LAT session via the UI:
- **From session filter**: Click "Reparse View" button in the LAT Queue (uses all filtered records)
- **From family**: Click "Parse Family" and select family/filters
- **Individual laws**: Select records and use "LAT" button per-row

The UI navigates to `/admin/lat/sessions/{session_id}` after creation.

```bash
# Verify session was created
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT session_id, session_type, status, group1_count
FROM scrape_sessions
WHERE session_type = 'lat_parse'
ORDER BY inserted_at DESC LIMIT 1;
"
```

---

## Stage 3: PARSE (Human-Driven)

The human drives parsing in the LAT session detail page (`/admin/lat/sessions/{session_id}`):

1. **Select records** — checkbox selection or "Select All"
2. **Parse** — "Auto Parse Selected" streams SSE events per record
3. **Review** — each record shows LAT count, annotation count, parse duration
4. **Confirm** — marks records as confirmed after review

**5-stage SSE pipeline per law**:
1. `fetch_body` — Download XML from legislation.gov.uk
2. `parse_lat` — Parse XML into LAT rows (section_type, hierarchy, text)
3. `persist_lat` — DELETE + INSERT LAT rows (idempotent)
4. `parse_annotations` — Parse Commentaries block (amendment annotations)
5. `persist_annotations` — DELETE + INSERT amendment_annotations

**AI can assist during this stage if asked**:
- Explain parse errors
- Check if a law's XML is available (some very old laws lack machine-readable body text)
- Review individual LAT records for a law

**When the human is done**: They tell the AI "parsing is done" or "ready for QA".

---

## Stage 4: QA — LAT Shape

After the human signals parsing is complete, validate the "shape" of the parsed LAT data. Good LAT parsing produces a coherent hierarchy of structural units.

### 4a. Session Reconciliation

```bash
# All session records should be confirmed or skipped
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT status, COUNT(*)
FROM scrape_session_records
WHERE session_id = '{lat_session_id}'
GROUP BY status;
"
```

**Pass criteria**: No records in `pending` status. `parsed` is acceptable if the human reviewed but didn't explicitly confirm.

### 4b. LAT Row Counts

```bash
# LAT rows per parsed law — flag outliers
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.type_code,
       COUNT(l.id) as lat_rows,
       COUNT(DISTINCT l.section_type) as distinct_types,
       COUNT(aa.id) as annotation_count
FROM scrape_session_records ssr
JOIN uk_lrt u ON u.name = ssr.law_name
LEFT JOIN lat l ON l.law_id = u.id
LEFT JOIN amendment_annotations aa ON aa.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY u.name, u.title_en, u.type_code
ORDER BY lat_rows;
"
```

**Flag**:
- Laws with 0 LAT rows (parse may have failed silently)
- Laws with only 1-2 LAT rows (likely only got the title, body wasn't parsed)
- Laws with unusually high counts (> 500 rows) — worth a spot-check
- Laws with 0 annotations — may be correct (new laws have no amendments) but note it

### 4c. Section Type Distribution

```bash
# Section type breakdown for this session's laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT l.section_type, COUNT(*) as count
FROM lat l
JOIN uk_lrt u ON u.id = l.law_id
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY l.section_type
ORDER BY count DESC;
"
```

**Expected distribution** for a well-parsed law:
- `section` or `article` — the bulk of rows (actual legal provisions)
- `part`, `chapter`, `heading` — structural grouping (fewer)
- `schedule` — appendices (some laws have many)
- `paragraph`, `sub_paragraph` — fine-grained subdivisions

**Flag**:
- Only `title` type present → body parsing failed
- No `section`/`article`/`paragraph` types → structural parsing issue
- All rows same type → parser didn't distinguish hierarchy levels

### 4d. Hierarchy Integrity

```bash
# Check for NULL section_type (should never happen)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, COUNT(*) as null_type_count
FROM lat l
JOIN uk_lrt u ON u.id = l.law_id
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND l.section_type IS NULL
GROUP BY u.name;
"
```

```bash
# Check for empty text on provision-level rows (section, article, paragraph)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, l.section_type, l.section_id, l.depth
FROM lat l
JOIN uk_lrt u ON u.id = l.law_id
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND l.section_type IN ('section', 'article', 'paragraph', 'sub_paragraph')
  AND (l.text IS NULL OR l.text = '')
LIMIT 20;
"
```

```bash
# Check sort_key ordering is consistent (no gaps or duplicates per law)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name,
       COUNT(*) as total,
       COUNT(DISTINCT l.sort_key) as distinct_sort_keys,
       COUNT(DISTINCT l.position) as distinct_positions
FROM lat l
JOIN uk_lrt u ON u.id = l.law_id
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY u.name
HAVING COUNT(*) != COUNT(DISTINCT l.sort_key)
    OR COUNT(*) != COUNT(DISTINCT l.position);
"
```

**Flag**: Any rows returned indicate sort_key or position collisions — a parser bug.

### 4e. Annotation Sanity Check

```bash
# Annotation code_type distribution
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT aa.code_type, COUNT(*) as count
FROM amendment_annotations aa
JOIN uk_lrt u ON u.name = aa.law_name
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY aa.code_type
ORDER BY count DESC;
"
```

**Expected code_types**: F (textual amendments), C (modifications), I (commencement), E (extent), Editorial notes.

### QA Gate Decision

Present a summary to the human:

```
## Post-Parse QA Summary

**Session**: {lat_session_id}
**Laws parsed**: {confirmed_count}

| Check | Result |
|-------|--------|
| Session reconciliation | PASS/FAIL ({pending} pending) |
| LAT row counts | {n} laws, {total} rows ({min}-{max} range) |
| Zero-row laws | {count} (PASS if 0) |
| Section type distribution | {types_found} types across {laws} laws |
| NULL section_type | {count} (PASS if 0) |
| Empty text on provisions | {count} (PASS if 0) |
| Sort key integrity | PASS/FAIL |
| Annotations | {total} across {laws_with_ann} laws |

**Recommendation**: PROCEED to taxa / HOLD (fix issues first)
```

The human decides whether to proceed to taxa enrichment.

---

## Stage 5: TAXA ENRICHMENT

After LAT parsing, the taxa service (fractalaw) analyses the parsed text to extract duty holders, responsibilities, fitness classifications, and other structured metadata. This is triggered via Zenoh P2P mesh.

### 5a. Trigger Taxa Parsing

The taxa service runs in fractalaw and subscribes to Zenoh topics. Triggering it depends on the fractalaw deployment:

```bash
# Check Zenoh subscriptions are active
curl -s http://localhost:4003/api/zenoh/subscriptions | python3 -m json.tool
```

```bash
# Check Zenoh queryables are registered
curl -s http://localhost:4003/api/zenoh/queryables | python3 -m json.tool
```

If the taxa service needs to be invoked manually, the human will do this in their fractalaw environment. The AI should ask: "Are the taxa services running? Shall I wait for enrichment results?"

### 5b. Monitor Enrichment

```bash
# Check which session laws have taxa data populated
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en,
       CASE WHEN u.duty_type IS NOT NULL THEN 'yes' ELSE 'no' END as has_duty_type,
       CASE WHEN u.has_fitness THEN 'yes' ELSE 'no' END as has_fitness,
       u.is_making
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
ORDER BY u.name;
"
```

**Wait until** all (or most) session laws show `has_duty_type = yes`. The Zenoh subscriber processes asynchronously — it may take a few minutes for all laws to be enriched.

---

## Stage 6: QA — Taxa Results

### 6a. Duty Type Validation

```bash
# Check duty_type distribution — confirms is_making derivation
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en,
       u.making_classification,
       u.is_making,
       u.duty_type,
       CASE WHEN u.function ? 'Making' THEN 'yes' ELSE 'no' END as function_making
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
ORDER BY u.is_making DESC, u.name;
"
```

**Check for**:
- `making_classification = 'making'` but `is_making = false` → taxa didn't find duties (review the law's text)
- `making_classification = 'not_making'` but `is_making = true` → classification was wrong (good catch by taxa!)
- `duty_type` is NULL for confirmed making laws → taxa service may not have processed yet

### 6b. Fitness Field Validation

```bash
# Check fitness field population
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name,
       u.has_fitness,
       array_length(u.fitness_person, 1) as person_tags,
       array_length(u.fitness_process, 1) as process_tags,
       array_length(u.fitness_place, 1) as place_tags,
       array_length(u.fitness_plant, 1) as plant_tags,
       array_length(u.fitness_sector, 1) as sector_tags
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND u.is_making = true
ORDER BY u.name;
"
```

**Flag**:
- Making laws with `has_fitness = false` — taxa service may have failed for this law
- Laws with very few fitness tags (< 3 across all categories) — may be correctly sparse, but worth a spot-check

### 6c. Making Classification Reconciliation

```bash
# Compare pre-parse classification with post-taxa is_making
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT
  u.making_classification as pre_parse,
  u.is_making as post_taxa,
  COUNT(*) as count
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY u.making_classification, u.is_making
ORDER BY u.making_classification;
"
```

**Expected**: Most `making` → `is_making=true`, most `not_making` → `is_making=false`. Mismatches are interesting — they show where the lightweight title-based classification diverged from the full-text analysis.

### QA Gate Decision

```
## Post-Taxa QA Summary

**Session**: {lat_session_id}
**Laws enriched**: {enriched_count}/{total_count}

| Check | Result |
|-------|--------|
| Taxa coverage | {enriched}/{total} laws have duty_type |
| Fitness coverage | {with_fitness}/{making_count} making laws have fitness |
| Classification agreement | {agree}% making_classification matches is_making |
| Mismatches | {mismatch_count} (review list above) |

**Recommendation**: PROCEED to NAS sync / HOLD
```

---

## Stage 7: NAS Sync

Export the dev database snapshot to NAS. This captures uk_lrt (with taxa fields), lat, and amendment_annotations.

```bash
cd /var/home/jason/Desktop/sertantai-legal

# Pre-flight: NAS is mounted
ls /mnt/nas/sertantai-data/data/snapshots/latest/

# Archive previous and export
./scripts/nas/export-snapshot.sh --archive
```

**Tables exported** (FK dependency order): uk_lrt → lat → amendment_annotations → scrape_sessions → scrape_session_records → cascade_affected_laws.

---

## Stage 8: QA — Post-NAS Sync

```bash
cat /mnt/nas/sertantai-data/data/snapshots/latest/manifest.json | python3 -m json.tool
```

**Verify**:
1. Manifest timestamp is fresh (within last hour)
2. All tables present with non-zero row counts
3. Checksums match:
   ```bash
   ./scripts/nas/import-snapshot.sh --verify-only
   ```
4. LAT row count matches dev:
   ```bash
   PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
   SELECT
     (SELECT COUNT(*) FROM uk_lrt) as uk_lrt,
     (SELECT COUNT(*) FROM lat) as lat,
     (SELECT COUNT(*) FROM amendment_annotations) as annotations;
   "
   ```

### QA Gate Decision

```
## Post-NAS QA Summary

| Check | Result |
|-------|--------|
| Manifest timestamp | {timestamp} — FRESH/STALE |
| Tables present | {n}/{expected} |
| Checksum verification | PASS/FAIL |
| Row counts (dev vs NAS) | uk_lrt: {match}, lat: {match}, annotations: {match} |

**Recommendation**: PROCEED to prod sync / HOLD
```

---

## Stage 9: Production Sync

Export delta and apply to production. LAT sync must include uk_lrt (taxa fields), lat, and amendment_annotations.

### 9a. Export Delta

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend

# Export changes since last sync
mix run ../scripts/sync/export_delta.exs --since "{last_sync_timestamp}" --output-dir ../scripts/sync/
```

### 9b. Review Delta

```bash
cat ../scripts/sync/delta_*_manifest.json | python3 -m json.tool
```

Check: Row counts per table, no unexpected tables, file size reasonable.

### 9c. Apply to Production

```bash
# Apply via SSH pipeline
cat ../scripts/sync/{delta_file}.sql | ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres -d sertantai_legal_prod"
```

**Important**: If the delta includes bulk LAT inserts, consider disabling the `propagate_lat_stats` trigger during import:
```bash
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c '
ALTER TABLE lat DISABLE TRIGGER propagate_lat_stats;
'"
# ... apply delta ...
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c '
ALTER TABLE lat ENABLE TRIGGER propagate_lat_stats;
'"
```

---

## Stage 10: QA — Post-Production Sync

```bash
# Production counts
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c '
SELECT
  (SELECT COUNT(*) FROM uk_lrt) as uk_lrt,
  (SELECT COUNT(*) FROM lat) as lat,
  (SELECT COUNT(*) FROM amendment_annotations) as annotations;
'"

# Compare with dev
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT
  (SELECT COUNT(*) FROM uk_lrt) as uk_lrt,
  (SELECT COUNT(*) FROM lat) as lat,
  (SELECT COUNT(*) FROM amendment_annotations) as annotations;
"
```

### QA Gate Decision

```
## Post-Production QA Summary

| Table | Dev | Prod | Delta |
|-------|-----|------|-------|
| uk_lrt | {dev} | {prod} | {diff} |
| lat | {dev} | {prod} | {diff} |
| amendment_annotations | {dev} | {prod} | {diff} |

**Recommendation**: COMPLETE / INVESTIGATE (counts diverge)
```

---

## Stage 11: COMPLETE

All stage gates passed. Summarise the session:

```
## LAT Parse Session Complete

**LRT Session**: {lrt_session_id}
**LAT Session**: {lat_session_id}
**Laws parsed**: {confirmed_count}
**LAT rows created**: {total_lat_rows}
**Annotations created**: {total_annotations}
**Taxa enriched**: {enriched_count} laws ({making_count} confirmed making)
**Classification accuracy**: {agree}% (pre-parse classification vs post-taxa)
**NAS snapshot**: Updated ({timestamp})
**Production sync**: Applied ({delta_file})
**All QA gates**: PASSED
```

---

## Key Files

| Purpose | Path |
|---------|------|
| LAT Resource | `backend/lib/sertantai_legal/legal/lat.ex` |
| LAT Parser | `backend/lib/sertantai_legal/scraper/lat_parser.ex` |
| LAT Staged Parser (SSE) | `backend/lib/sertantai_legal/scraper/lat_staged_parser.ex` |
| LAT Persister | `backend/lib/sertantai_legal/scraper/lat_persister.ex` |
| LAT Admin Controller | `backend/lib/sertantai_legal_web/controllers/lat_admin_controller.ex` |
| LAT Session Detail UI | `frontend/src/routes/admin/lat/sessions/[id]/+page.svelte` |
| LAT Queue UI | `frontend/src/routes/admin/lat/queue/+page.svelte` |
| Zenoh Taxa Subscriber | `backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex` |
| UK LRT Resource | `backend/lib/sertantai_legal/legal/uk_lrt.ex` |
| NAS Export Script | `scripts/nas/export-snapshot.sh` |
| Delta Export | `scripts/sync/export_delta.exs` |
| Delta Apply | `scripts/sync/apply_delta.exs` |

## Related Skills

- [LRT Scrape Session](../lrt-scrape-session/) — Prerequisite: ingest laws into uk_lrt before LAT parsing
- [NAS Data Sync](../nas-data-sync/) — NAS mount config, export/import details
- [Production Data Sync](../prod-data-sync/) — Delta export/apply, SSH pipeline, trigger management
- [Zenoh P2P Publishing](../zenoh-p2p-publishing/) — Zenoh mesh architecture and taxa queryables
- [Enacted By QA](../enacted-by-qa/) — Complementary QA of enacted_by parser results
