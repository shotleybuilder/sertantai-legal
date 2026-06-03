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
 2. SESSION CREATION    Human creates LAT parse session via UI
        ↓
 3. PARSE               Human runs parsing via admin UI (SSE streaming)
        ↓
 4. QA: LAT SHAPE       AI validates LAT record structure ← STAGE GATE
        ↓
 5. TAXA ENRICHMENT     Human triggers fractalaw enrichment; AI monitors
        ↓
 6. QA: ENRICHMENT      AI validates function labels, DRRP, fitness, LAT pruning ← STAGE GATE
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
3. `is_making` — definitive, set by taxa after full-text enrichment

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
- **Revoked laws** → exclude from review entirely (dead law, no customer value)

Present recommendations to the human. They can update reviews inline in the LAT Queue grid (double-click the "Review" column) or AI can apply via SQL.

### 1c. Confirm Scope and Apply Reviews

Once the human confirms which laws to parse:

1. **Set `making_review = 'making'`** for laws selected for parsing
2. **Infer `making_review = 'not_making'`** for all unselected session laws — by choosing not to parse them, the human implicitly reviewed them as not_making

**IMPORTANT**: Always exclude revoked laws from bulk making_review updates. A revoked law
showing up in the parse queue wastes enrichment time and produces misleading results (e.g.
Housekeeping classification for dead law). Filter with `AND u.live NOT LIKE '%evok%'`.

```bash
# Apply reviews: selected laws → making (exclude revoked)
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
UPDATE uk_lrt SET making_review = 'making', making_review_at = NOW()
WHERE name IN ({selected_law_names_comma_separated})
  AND live NOT LIKE '%evok%'
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

**Confirm with the human**: "{N} laws reviewed as making from session {lrt_session_id}. {M} reviewed as not_making (inferred from non-selection). Proceed to session creation?"

---

## Stage 2: SESSION CREATION

The human creates the LAT session via the UI:
- **From session filter**: Click "Reparse View ({N})" button in the LAT Queue — the count and session only include parseable laws (effective_classification != not_making)
- **From family**: Click "Parse Family" and select family/filters — backend query respects making_review
- **Individual laws**: Select records and use "LAT" button per-row (does not create a session)

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
# LAT rows per parsed law — uses trigger-maintained lat_count on uk_lrt
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.type_code, u.lat_count,
       COUNT(aa.id) as annotation_count
FROM scrape_session_records ssr
JOIN uk_lrt u ON u.name = ssr.law_name
LEFT JOIN amendment_annotations aa ON aa.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
GROUP BY u.name, u.title_en, u.type_code, u.lat_count
ORDER BY u.lat_count;
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
- `article` / `sub_article` — the bulk of rows (actual legal provisions for SIs)
- `section` — for primary Acts
- `part`, `chapter`, `heading` — structural grouping (fewer)
- `schedule` — appendices (some laws have many)
- `paragraph`, `sub_paragraph` — fine-grained subdivisions
- `signed` — signature blocks (a few per law)

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
# Check sort_key ordering is consistent (no duplicates per law)
# Note: position duplicates are a known edge case with nested regulation structures
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, COUNT(*) as total,
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

**Flag**: Rows returned indicate sort_key or position collisions. Minor sort_key duplicates (1-2 per law) with unique positions are a known parser edge case. Large numbers indicate a bug.

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

**Expected code_types**: F (textual amendments), C (modifications), I (commencement), E (extent), Editorial notes. New 2026 SIs may have 0 annotations — this is normal.

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
| Sort key integrity | PASS/WARN ({n} laws with duplicates) |
| Annotations | {total} across {laws_with_ann} laws |

**Recommendation**: PROCEED to enrichment / HOLD (fix issues first)
```

The human decides whether to proceed to taxa enrichment.

---

## Stage 5: TAXA ENRICHMENT

After LAT parsing, the fractalaw DRRP pipeline analyses the parsed text to extract duties, rights, responsibilities, powers, fitness classifications, and other structured metadata. Results are published back via Zenoh.

**Important**: The Zenoh TaxaSubscriber is a GenServer — it does NOT hot-reload. If code changes were made to the subscriber, the Phoenix server must be restarted before triggering enrichment.

### 5a. Verify Zenoh Connectivity

Check the admin Zenoh dashboard at `/admin/zenoh`:
- **DataServer (Queryables)**: Should show `ready` with LAT queryable registered
- **TaxaSubscriber**: Should show `ready` with `fractalaw/@dev/taxa/enrichment/*` subscription

### 5b. Trigger Enrichment

The human triggers enrichment from fractalaw. Two approaches:

1. **Automatic** (`fractalaw sync watch`): Already running, triggers on LAT persist events
2. **Manual** (`fractalaw sync publish --laws ...`): For re-enrichment after code changes

The AI should ask: "Is fractalaw watching for events, or do you need to trigger enrichment manually?"

### 5c. Monitor Enrichment

Watch the TaxaSubscriber section on `/admin/zenoh`:
- **Received**: Number of enrichment payloads received
- **Updated**: Successfully processed (should equal Received)
- **Failed**: Processing errors (should be 0)

If Received > Updated + Failed, some laws were silently dropped — check server logs for errors.

### 5d. Three Enrichment Outcomes

Fractalaw produces one of three results per law. All three publish an Arrow IPC payload:

| Outcome | is_making | function label | duty_type | LAT |
|---------|-----------|----------------|-----------|-----|
| **Making** | `true` | `Making` | Has Duty/Responsibility | Retained |
| **Empowering** | `false` | `Empowering` | Has Power/Right only | **Pruned** |
| **Housekeeping** | NULL | `Housekeeping` | NULL (nothing found) | **Pruned** |

See `FUNCTION_VALUES.md` for full documentation of enrichment function labels.

---

## Stage 6: QA — Enrichment Results

### 6a. Function Label Validation

The primary check — every enriched law should have exactly one enrichment label (Making, Empowering, or Housekeeping) in its function JSONB.

```bash
# Check enrichment labels and is_making for all session laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.title_en, u.is_making,
       u.function,
       CASE
         WHEN u.function ? 'Making' THEN 'Making'
         WHEN u.function ? 'Empowering' THEN 'Empowering'
         WHEN u.function ? 'Housekeeping' THEN 'Housekeeping'
         ELSE '** NOT ENRICHED **'
       END as enrichment_label
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
ORDER BY enrichment_label, u.name;
"
```

**Flag**:
- `** NOT ENRICHED **` — enrichment didn't reach this law (check Zenoh logs)
- `Making` but `is_making` is NULL or false → mismatch, investigate
- `Empowering` or `Housekeeping` but `is_making = true` → conflicting state

### 6b. DRRP JSONB Validation (Making laws)

For Making laws, validate that the DRRP columns are populated with structured data.

```bash
# Check DRRP column population for Making laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name,
       u.duty_type,
       CASE WHEN u.duties IS NOT NULL THEN jsonb_array_length(u.duties->'entries') END as duty_entries,
       CASE WHEN u.rights IS NOT NULL THEN jsonb_array_length(u.rights->'entries') END as right_entries,
       CASE WHEN u.responsibilities IS NOT NULL THEN jsonb_array_length(u.responsibilities->'entries') END as resp_entries,
       CASE WHEN u.powers IS NOT NULL THEN jsonb_array_length(u.powers->'entries') END as power_entries
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND u.function ? 'Making'
ORDER BY u.name;
"
```

**Flag**:
- Making law with 0 duty_entries and 0 resp_entries → is_making may be wrong
- Very high entry counts (> 100) → spot-check for parser noise

```bash
# Check holder columns are populated for Making laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name,
       CASE WHEN u.duty_holder IS NOT NULL THEN 'yes' ELSE 'no' END as has_duty_holder,
       CASE WHEN u.rights_holder IS NOT NULL THEN 'yes' ELSE 'no' END as has_rights_holder,
       CASE WHEN u.responsibility_holder IS NOT NULL THEN 'yes' ELSE 'no' END as has_resp_holder,
       CASE WHEN u.power_holder IS NOT NULL THEN 'yes' ELSE 'no' END as has_power_holder
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND u.function ? 'Making'
ORDER BY u.name;
"
```

### 6c. DRRP JSONB Validation (Empowering laws)

Empowering laws should have powers/rights data but no duties/responsibilities.

```bash
# Check Empowering laws have powers/rights but not duties
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.duty_type,
       CASE WHEN u.powers IS NOT NULL THEN jsonb_array_length(u.powers->'entries') END as power_entries,
       CASE WHEN u.rights IS NOT NULL THEN jsonb_array_length(u.rights->'entries') END as right_entries,
       CASE WHEN u.duties IS NOT NULL THEN 'UNEXPECTED' ELSE 'ok' END as duties_check
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND u.function ? 'Empowering'
ORDER BY u.name;
"
```

### 6d. Fitness Validation

```bash
# Check fitness field population for Making laws
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.has_fitness,
       array_length(u.fitness_person, 1) as person,
       array_length(u.fitness_process, 1) as process,
       array_length(u.fitness_place, 1) as place,
       array_length(u.fitness_plant, 1) as plant,
       array_length(u.fitness_sector, 1) as sector,
       CASE WHEN u.fitness IS NOT NULL THEN array_length(u.fitness, 1) END as fitness_rules
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
  AND u.function ? 'Making'
ORDER BY u.name;
"
```

**Flag**:
- Making laws with `has_fitness = false` — taxa found duties but no applicability signals. May be correct for narrow/procedural duty-creating laws.
- Fitness tag arrays populated but `fitness` detail array is NULL — partial enrichment.

### 6e. LAT Pruning Verification

Empowering and Housekeeping laws should have their LAT rows pruned.

```bash
# Verify LAT was pruned for non-making enrichment results
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.lat_count,
       (SELECT COUNT(*) FROM lat l WHERE l.law_id = u.id) as actual_lat,
       CASE
         WHEN u.function ? 'Making' THEN 'Making (retain)'
         WHEN u.function ? 'Empowering' THEN 'Empowering (prune)'
         WHEN u.function ? 'Housekeeping' THEN 'Housekeeping (prune)'
       END as expected_action
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
ORDER BY u.name;
"
```

**Flag**:
- Empowering/Housekeeping with `actual_lat > 0` → pruning failed
- Making with `actual_lat = 0` → LAT was incorrectly pruned
- `lat_count` doesn't match `actual_lat` → trigger propagation needed

### 6f. Review Reconciliation

Compare the human's pre-parse making_review against the enrichment outcome.

```bash
# Review vs enrichment — flag disagreements
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
SELECT u.name, u.making_review AS review,
       CASE
         WHEN u.function ? 'Making' THEN 'Making'
         WHEN u.function ? 'Empowering' THEN 'Empowering'
         WHEN u.function ? 'Housekeeping' THEN 'Housekeeping'
       END as enrichment,
       CASE
         WHEN u.making_review = 'making' AND u.function ? 'Making' THEN 'agree'
         WHEN u.making_review = 'making' AND (u.function ? 'Empowering' OR u.function ? 'Housekeeping') THEN 'DISAGREE — review said making'
         WHEN u.making_review = 'not_making' AND u.function ? 'Making' THEN 'DISAGREE — review said not_making'
         ELSE 'ok'
       END as agreement
FROM uk_lrt u
JOIN scrape_session_records ssr ON ssr.law_name = u.name
WHERE ssr.session_id = '{lat_session_id}' AND ssr.status = 'confirmed'
ORDER BY agreement DESC, u.name;
"
```

Disagreements are informative, not errors. They show where the lightweight title-based review diverged from full-text analysis. Common: amendment orders reviewed as "making" that turn out to be Empowering (powers only) or Housekeeping (purely procedural).

### QA Gate Decision

```
## Post-Enrichment QA Summary

**Session**: {lat_session_id}
**Laws enriched**: {enriched_count}/{total_count}

| Check | Result |
|-------|--------|
| Enrichment coverage | {enriched}/{total} have enrichment label |
| Making | {making_count} laws (is_making=true, LAT retained) |
| Empowering | {empowering_count} laws (powers/rights, LAT pruned) |
| Housekeeping | {housekeeping_count} laws (no DRRP, LAT pruned) |
| DRRP population | {with_drrp}/{making_count} Making laws have DRRP entries |
| Fitness coverage | {with_fitness}/{making_count} Making laws have fitness |
| LAT pruning | PASS/FAIL ({unpruned} Empowering/Housekeeping with LAT remaining) |
| Review agreement | {agree_count}/{total} ({disagree_count} disagreements) |

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
# Verify checksums
./scripts/nas/import-snapshot.sh --verify-only
```

```bash
# Compare row counts with dev
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

Export delta and apply to production. See the `prod-data-sync` skill for detailed patterns, pitfalls, and troubleshooting.

### 9a. Pre-flight: Schema Parity

If new columns were added (e.g., migrations), deploy the backend to production first so migrations run before the delta is applied.

```bash
# Build, push, deploy with --migrate
./scripts/deployment/build-backend.sh
# Push requires interactive GHCR auth — human runs: ! ./scripts/deployment/push-backend.sh
./scripts/deployment/deploy-prod.sh --backend --migrate
```

### 9b. Export Delta

```bash
cd /var/home/jason/Desktop/sertantai-legal/backend

# Export changes since last sync (uses watermarks from last_sync.json)
mix data.export_delta
```

### 9c. Review Delta Size

```bash
# Check file size and row counts
ls -lh ../scripts/sync/delta_*.sql
grep -n "^-- .* rows)" ../scripts/sync/delta_{timestamp}.sql
```

### 9d. Apply to Production

**For small deltas (< 50MB)**: Pipe directly through SSH.

```bash
cat ../scripts/sync/delta_{timestamp}.sql | \
  ssh sertantai-hz "docker exec -i shared_postgres psql -U postgres \
  -d sertantai_legal_prod -v ON_ERROR_STOP=1"
```

**For large deltas (> 50MB)**: Split by table to avoid single-transaction memory issues. See `prod-data-sync` skill Pattern 3.

```bash
# Split into per-table files
grep -n "^-- .* rows)" ../scripts/sync/delta_{timestamp}.sql
# Use awk to extract sections, add BEGIN/COMMIT wrappers
# Upload compressed, apply individually in FK order:
# 1. uk_lrt → 2. lat → 3. amendment_annotations → 4. sessions → 5. session_records → 6. cascade
```

---

## Stage 10: QA — Post-Production Sync

```bash
# Compare all 6 tables
ssh sertantai-hz "docker exec shared_postgres psql -U postgres -d sertantai_legal_prod -c \"
  SELECT 'uk_lrt' AS t, COUNT(*) FROM uk_lrt
  UNION ALL SELECT 'lat', COUNT(*) FROM lat
  UNION ALL SELECT 'amendments', COUNT(*) FROM amendment_annotations
  UNION ALL SELECT 'scrape_sessions', COUNT(*) FROM scrape_sessions
  UNION ALL SELECT 'scrape_session_records', COUNT(*) FROM scrape_session_records
  UNION ALL SELECT 'cascade_affected_laws', COUNT(*) FROM cascade_affected_laws;
\""

# Compare with dev
PGPASSWORD=postgres psql -h localhost -p 5436 -U postgres -d sertantai_legal_dev -c "
  SELECT 'uk_lrt' AS t, COUNT(*) FROM uk_lrt
  UNION ALL SELECT 'lat', COUNT(*) FROM lat
  UNION ALL SELECT 'amendments', COUNT(*) FROM amendment_annotations
  UNION ALL SELECT 'scrape_sessions', COUNT(*) FROM scrape_sessions
  UNION ALL SELECT 'scrape_session_records', COUNT(*) FROM scrape_session_records
  UNION ALL SELECT 'cascade_affected_laws', COUNT(*) FROM cascade_affected_laws;
"
```

### QA Gate Decision

```
## Post-Production QA Summary

| Table | Dev | Prod | Match |
|-------|-----|------|-------|
| uk_lrt | {dev} | {prod} | Yes/No |
| lat | {dev} | {prod} | Yes/No |
| amendment_annotations | {dev} | {prod} | Yes/No |
| scrape_sessions | {dev} | {prod} | Yes/No |
| scrape_session_records | {dev} | {prod} | Yes/No |
| cascade_affected_laws | {dev} | {prod} | Yes/No |

**Recommendation**: COMPLETE / INVESTIGATE (counts diverge)
```

Note: Delta sync does not propagate deletes. If prod has MORE rows than dev, see `prod-data-sync` skill Pattern 4 for orphan cleanup.

---

## Stage 11: COMPLETE

All stage gates passed. Summarise the session:

```
## LAT Parse Session Complete

**LRT Session**: {lrt_session_id}
**LAT Session**: {lat_session_id}
**Laws reviewed**: {total_reviewed} ({making_count} making, {not_making_count} not_making)
**Laws parsed**: {confirmed_count}
**Enrichment results**:
  - {making_count} Making — LAT retained
  - {empowering_count} Empowering — LAT pruned, DRRP retained
  - {housekeeping_count} Housekeeping — LAT pruned, no DRRP
**Review accuracy**: {agree_count}/{total} ({disagree_count} disagreements)
**NAS snapshot**: Updated ({timestamp})
**Production sync**: Applied ({delta_summary})
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
| Function Calculator | `backend/lib/sertantai_legal/legal/function_calculator.ex` |
| UK LRT Resource | `backend/lib/sertantai_legal/legal/uk_lrt.ex` |
| NAS Export Script | `scripts/nas/export-snapshot.sh` |
| Delta Export Task | `backend/lib/mix/tasks/data.export_delta.ex` |

## Related Skills

- [LRT Scrape Session](../lrt-scrape-session/) — Prerequisite: ingest laws into uk_lrt before LAT parsing
- [NAS Data Sync](../nas-data-sync/) — NAS mount config, export/import details
- [Production Data Sync](../prod-data-sync/) — Delta export/apply, SSH pipeline, split-by-table, trigger management
- [Production Deployment](../production-deployment/) — Build, push, deploy Docker images, run migrations
- [Zenoh P2P Publishing](../zenoh-p2p-publishing/) — Zenoh mesh architecture and taxa queryables
- [Enacted By QA](../enacted-by-qa/) — Complementary QA of enacted_by parser results
