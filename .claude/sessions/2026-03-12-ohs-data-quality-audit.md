# Title: OH&S Data Quality Audit

**Started**: 2026-03-12

## Todo

### Phase 1: Live Status Classification Stress Test
- [x] Random sample 20 OH&S laws >20 years old
- [x] Check reconciliation columns (`live_source`, `live_from_changes`, `live_from_metadata`)
- [x] Check changelog coverage across OH&S
- [x] Re-examine after OH&S reparse (84% coverage)
- [x] Fix `determine_live_status` bug — missing "revoke" check (commit `10fbf50`)
- [x] SQL data fix — reclassify 322 records using `rescinded_by_stats_per_law` JSONB (0 remaining misclassified)

### Phase 1b: Admin LRT UI for Targeted Reparsing
- [x] Add "Analytics" view group with "Live" view showing live-* columns (both LRT + LAT queue pages)
- [x] Add Reparse View button to LRT page — uses current table records, confirmation dialog, creates session
- [x] Backend: `ReparseManager.create_from_names/1` + `POST /api/sessions/reparse/from-view`
- [x] Keep existing Reparse Family dialog as secondary option

### Phase 4: Abbreviated & Empty-Target Revocation Patterns
- [x] Fix parser: `separate_revocations` captures abbreviated "Rev"/"Rep" affects
- [x] Fix parser: empty target treated as whole-instrument in `is_whole_instrument_target?`
- [x] Fix parser: `determine_live_status` handles abbreviated "Rev"/"Rep" + empty target
- [x] Data fix: 6 records corrected (empty target + "rev" in `affected_by_stats_per_law`)
- [x] Data fix: 1 record corrected (`UK_eudn_2010_347`, empty target + "revoked" in `rescinded_by`)
- [x] Analytics: misclassified canary SQL checks both JSONB fields
- [x] Analytics: `GET /api/analytics/live-status/misclassified` endpoint returns names
- [x] Analytics: "Reparse N records" button on misclassified alarm card → creates session
- [x] Tests: fixture rows 24-25 (empty target + "revoked", empty target + "Rev"), 3 new tests
- [x] Verified: reparse of misclassified records → 0 misclassified, all consistent

**Ended**: 2026-03-12

## Phase 1 Interim Results

**Finding: Coverage gap, not a data deletion bug.**

Only 31% (173/556) of OH&S laws have been through the reconciliation pipeline. The other 383 carry original Airtable-imported `live` values — never verified by the scraper.

| Sub-family | Total | Reconciled | Coverage |
|---|---|---|---|
| Occupational / Personal Safety | 436 | 113 | 26% |
| Offshore Safety | 58 | 31 | 53% |
| Gas & Electrical Safety | 32 | 26 | 81% |
| Mines & Quarries | 30 | 3 | 10% |

### Reconciliation model works correctly where applied
- 4/20 sampled records had reconciliation data — `live_source`, `live_conflict`, `live_from_changes/metadata` all populated
- Conflicts flagged properly (e.g. `UK_nisr_1995_340`: changes=Part Revocation, metadata=In force, winner=changes)
- Records without reconciliation have NULL `live_source` + empty changelog (or only old `airtable_sync` entries)

### After OH&S reparse (2026-03-12)

Coverage jumped from 31% → 77% (426/556 reconciled).

| Sub-family | Total | Reconciled | Coverage | Was |
|---|---|---|---|---|
| Occupational / Personal Safety | 436 | 366 | **84%** | 26% |
| Offshore Safety | 58 | 31 | 53% | 53% |
| Gas & Electrical Safety | 32 | 26 | 81% | 81% |
| Mines & Quarries | 30 | 3 | 10% | 10% |

**Stress test (20 random OH&S laws >20 yrs old)**: 17/20 now reconciled. 3 unreconciled all have NULL `title_en` — scraper can't fetch metadata without title.

**Conflict detection working correctly**: Records with `live_conflict=true` show sensible disagreements (e.g. changes="Part Revocation" vs metadata="In force", winner=changes per "most severe wins").

### Remaining gap: 71 OH&S records with NULL title_en

- 0/71 scraped after the 2026-03-11 fallback chain fix (Priority 4 from session 2026-03-10)
- 16/71 have changelogs from earlier scrapes (pre-fallback — title returned nil)
- 55/71 never scraped at all
- The Live view query filters `title_en IS NOT NULL`, so these are excluded from "Reparse View"
- **Fix**: Need a separate reparse targeting `title_en IS NULL` records specifically
- All tested endpoints (introduction, contents, RDF) return 200 with titles for these records

### Bug: `determine_live_status` misses bare "revoked" affects

Traced from `UK_nisr_2003_33` — changes data shows `"affect": "revoked", "target": "Regulations"` (full revocation by nisr/2007/31). But `determine_live_status` in `amending.ex` only checked for `"repeal"`, not `"revoke"`. A bare `"revoked"` fell through to `⭕ Part Revocation / Repeal`.

**Impact**: 480 records misclassified as partial when they have bare "revoked" entries. Of those, only 144 were corrected by metadata reconciliation — **335 still show wrong `live` status**.

**Fix**: Added `String.contains?(affect_lower, "revoke")` to the full-revocation check in `amending.ex:determine_live_status/1`.

**Records need re-scraping** to recalculate `live_from_changes` with the fixed logic.

### Data fix: SQL reclassification using `rescinded_by_stats_per_law` JSONB (2026-03-12)

Instead of re-scraping 480 records, fixed the data in-place using the existing `🔻_rescinded_by_stats_per_law` JSONB column.

**Key insight**: Full revocation signal in the JSONB is `target` = whole instrument type ("Regulations", "Act", "Order", etc.) AND `affect` = "revoked" or "repealed" (not "words revoked", "in part", etc.). Section-specific targets (e.g. "reg. 3", "s. 1") indicate partial revocation.

**JSONB `affect`/`target` field mapping** (different from what scraper HTML columns suggest):
- `target` = what part of the law is affected (whole instrument type or specific section)
- `affect` = what happened ("revoked", "repealed", "words revoked", etc.)

**SQL fix applied** (2 steps):
1. Updated `live_from_changes` from `⭕ Part Revocation / Repeal` → `❌ Revoked / Repealed / Abolished` for 322 records where JSONB shows whole-instrument revocation
2. Re-ran "most severe wins" reconciliation to update `live`, `live_source`, `live_conflict`

**Results**:

| Metric | Before | After |
|---|---|---|
| `live_from_changes` = Full Revocation | 209 | 531 (+322) |
| `live_from_changes` = Partial | 515 | 193 (-322) |
| Overall `live` = Full Revocation | 3,933 | 4,116 (+183) |
| Overall `live` = Partial | 2,416 | 2,239 (-177) |
| Sources agreeing (`live_source=both`) | 724 | 868 (+144) |
| Remaining misclassified | 322 | **0** |

**Breakdown of the 322 fixed records**:
- 178 had `live_from_metadata = ✔ In force` → `live` changed from Partial → Full Revocation (changes wins)
- 144 had `live_from_metadata = ❌ Revoked` → `live` unchanged but `live_source` changed from "metadata" → "both", `live_conflict` → false (now in agreement)

### Additional fix: 69 unprocessed records with whole-instrument revocation

Cross-checked records with NO `live_from_changes` (never through the changes pipeline) but with whole-instrument revocation in `rescinded_by_stats_per_law` JSONB. Found 69 more:
- 67 showed `⭕ Partial` (from original Airtable import, never verified)
- 2 had NULL `live`

All 69 updated to `❌ Revoked / Repealed / Abolished`.

**Also checked**: 1 record (`UK_uksi_1995_614`, Animal By-Products) shows `✔ In force` despite having whole-instrument revocations — but those revocations all have `"applied": "Not yet"`, so In force is correct.

**Final totals after both fixes (322 + 69 = 391 records)**:

| live | Before | After | Change |
|---|---|---|---|
| ❌ Revoked / Repealed / Abolished | 3,933 | 4,185 | +252 |
| ⭕ Part Revocation / Repeal | 2,416 | 2,172 | -244 |
| ✔ In force | 10,744 | 10,739 | -5 |
| Remaining misclassified | 391 | **1** (justified) |

### Next step
- Reparse the 71 null-title OH&S records with current code (has 4-fallback chain)

## Phase 3: Live Status Assurance Metrics (for new session)

### Context

The live status classification pipeline has three trust tiers:
1. **Reconciled** — both changes + metadata engines ran, "most severe wins" applied (`live_source` set)
2. **JSONB-only** — scraper fetched `/changes/affected` data (stored in `🔻_rescinded_by_stats_per_law`) but reconciliation hasn't run
3. **Airtable import** — original CSV value, never verified by any scraper (`live_source` IS NULL)

Current state (2026-03-12):
- 19,330 total records
- 1,509 reconciled (7.8%)
- 5,082 have JSONB revocation data but no `live_from_changes` calculation
- 15,627 Airtable-only (including 2,194 with no `live` at all)
- 571 conflicts (changes vs metadata disagree)

### Recommended Metrics

#### 1. Pipeline Coverage (the most critical metric)

**What**: % of records that have been through the full reconciliation pipeline.

```sql
-- KPIs: total, reconciled, changes-only, metadata-only, unverified
SELECT
  COUNT(*) as total,
  COUNT(live_source) as reconciled,
  ROUND(100.0 * COUNT(live_source) / COUNT(*), 1) as reconciled_pct,
  COUNT(CASE WHEN live_from_changes IS NOT NULL AND live_from_metadata IS NULL THEN 1 END) as changes_only,
  COUNT(CASE WHEN live_from_changes IS NULL AND live_from_metadata IS NOT NULL THEN 1 END) as metadata_only,
  COUNT(CASE WHEN live_source IS NULL AND live IS NOT NULL THEN 1 END) as airtable_only,
  COUNT(CASE WHEN live IS NULL THEN 1 END) as no_status
FROM uk_lrt;
```

**Display**: Stacked progress bar — green (reconciled), amber (single-source), red (airtable/none). Per-family breakdown table.

**Why**: This session proved that unverified Airtable values can be wrong (391 misclassified). Every unreconciled record is a latent risk.

#### 2. Source Agreement Rate

**What**: Among reconciled records, how often do changes and metadata agree?

```sql
SELECT
  COUNT(*) as reconciled,
  COUNT(CASE WHEN live_conflict = false THEN 1 END) as agreeing,
  COUNT(CASE WHEN live_conflict = true THEN 1 END) as conflicting,
  ROUND(100.0 * COUNT(CASE WHEN live_conflict = false THEN 1 END) / COUNT(*), 1) as agreement_pct
FROM uk_lrt
WHERE live_source IS NOT NULL;
```

**Display**: Donut chart (agree vs conflict). Table of conflicts grouped by `live_from_changes` vs `live_from_metadata` combination.

**Why**: Conflicts indicate either a classification bug or genuine ambiguity in the law's status. A rising conflict rate after a code change signals a regression.

#### 3. JSONB Cross-Check — Misclassification Detector

**What**: Records where the JSONB revocation data contradicts the current `live` classification. This is the exact query that found the 391 bugs.

```sql
-- Records with whole-instrument revocation in JSONB but NOT classified as fully revoked
SELECT COUNT(DISTINCT uk_lrt.id) as misclassified_count
FROM uk_lrt,
  jsonb_each("🔻_rescinded_by_stats_per_law") as entries(key, val),
  jsonb_array_elements(val->'details') as detail
WHERE live != '❌ Revoked / Repealed / Abolished'
AND lower(detail->>'target') IN ('regulations', 'act', 'order', 'rules', 'scheme',
  'measure', 'charter', 'byelaws', 'instrument')
AND (lower(detail->>'affect') = 'revoked' OR lower(detail->>'affect') = 'repealed'
  OR lower(detail->>'affect') LIKE '%in full%')
AND lower(detail->>'affect') NOT LIKE '%in part%'
AND lower(detail->>'affect') NOT LIKE 'power to%'
AND lower(detail->>'affect') NOT LIKE 'words %'
AND lower(detail->>'affect') NOT LIKE 'word %'
AND lower(detail->>'affect') NOT LIKE 'entry %'
AND lower(detail->>'affect') NOT LIKE 'entries %'
AND lower(detail->>'affect') NOT LIKE 'comma %';
```

**Display**: Single KPI card — **"0"** in green, any non-zero in red with drill-down link. This should be a regression alarm.

**Why**: This is the "canary" metric. If the code or data changes and this goes above 0, something is wrong. The 1 known justified exception (`UK_uksi_1995_614`, "applied: Not yet") should be documented as an allowed exclusion.

#### 4. Revocation Pattern Distribution

**What**: Breakdown of what the scraper is capturing in `rescinded_by_stats_per_law`.

```sql
-- Affect type distribution (top 20)
SELECT lower(detail->>'affect') as affect_type, COUNT(*) as cnt
FROM uk_lrt,
  jsonb_each("🔻_rescinded_by_stats_per_law") as entries(key, val),
  jsonb_array_elements(val->'details') as detail
GROUP BY lower(detail->>'affect')
ORDER BY cnt DESC
LIMIT 20;

-- Target type distribution (whole-instrument vs section-specific)
SELECT
  CASE
    WHEN lower(detail->>'target') IN ('regulations','act','order','rules','scheme',
      'measure','charter','byelaws','instrument') THEN 'whole_instrument'
    WHEN lower(detail->>'target') LIKE 'whole %' THEN 'whole_instrument'
    ELSE 'section_specific'
  END as target_type,
  COUNT(*) as cnt
FROM uk_lrt,
  jsonb_each("🔻_rescinded_by_stats_per_law") as entries(key, val),
  jsonb_array_elements(val->'details') as detail
GROUP BY 1;
```

**Display**: Two horizontal bar charts — affect types and target types. The target type split is a useful sanity check (roughly 60/40 section vs whole-instrument based on current data).

**Why**: New affect patterns appearing in future scrapes (e.g. a new legislation.gov.uk format) would show up here as low-count unknowns, flagging the need for parser updates.

#### 5. Live Status by Family

**What**: Per-family breakdown of live classification with pipeline coverage.

```sql
SELECT
  family,
  COUNT(*) as total,
  COUNT(live_source) as reconciled,
  ROUND(100.0 * COUNT(live_source) / COUNT(*), 1) as coverage_pct,
  COUNT(CASE WHEN live = '✔ In force' THEN 1 END) as in_force,
  COUNT(CASE WHEN live = '❌ Revoked / Repealed / Abolished' THEN 1 END) as revoked,
  COUNT(CASE WHEN live = '⭕ Part Revocation / Repeal' THEN 1 END) as partial,
  COUNT(CASE WHEN live IS NULL THEN 1 END) as unknown
FROM uk_lrt
GROUP BY family
ORDER BY total DESC;
```

**Display**: Table with sparkline-style inline bars per family. Sortable by coverage_pct to prioritise families needing reparse.

**Why**: Drives the reparse queue — families with low coverage are the priority for scraping runs.

#### 6. "Applied" Status Distribution

**What**: How many whole-instrument revocations are "Not yet" applied vs "Yes".

```sql
SELECT detail->>'applied' as applied_status, COUNT(*) as cnt
FROM uk_lrt,
  jsonb_each("🔻_rescinded_by_stats_per_law") as entries(key, val),
  jsonb_array_elements(val->'details') as detail
WHERE lower(detail->>'target') IN ('regulations','act','order','rules','scheme',
  'measure','charter','byelaws','instrument')
AND (lower(detail->>'affect') = 'revoked' OR lower(detail->>'affect') = 'repealed')
GROUP BY detail->>'applied'
ORDER BY cnt DESC;
```

**Display**: Small table or KPI cards.

**Why**: "Not yet" applied revocations are the edge case that tripped up `UK_uksi_1995_614`. Monitoring this count helps anticipate future reclassifications when legislation.gov.uk updates these to "Yes".

### Implementation Notes

**Backend**: New endpoint `GET /api/analytics/live-status` in `AnalyticsController`. Run all 6 queries in a single request. Most queries are fast (< 100ms) but queries 3 and 4 do JSONB unnesting across ~6K records — consider caching or limiting to on-demand refresh.

**Frontend**: New collapsible section "Live Status Assurance" on `/admin/analytics`. Structure:
- **KPI row**: Reconciled %, Agreement %, Misclassified count (the 3 headline numbers)
- **Pipeline Coverage**: Stacked bar + per-family table (metric 1 + 5 combined)
- **Conflicts & Cross-Checks**: Agreement donut + misclassification alarm (metrics 2 + 3)
- **Pattern Distribution**: Affect/target bar charts + applied status (metrics 4 + 6)

**PGLite vs API**: Metrics 1 and 5 could run client-side on PGLite (the columns are synced). Metrics 3, 4, and 6 require JSONB unnesting on the full `rescinded_by_stats_per_law` column which is too large for PGLite — these should be API-backed.

### Session Handoff

This session (2026-03-12 OH&S Data Quality Audit) is complete. Phase 3 implementation should be a **new session** covering:

1. Backend: `GET /api/analytics/live-status` endpoint with all 6 queries
2. Frontend: "Live Status Assurance" section on `/admin/analytics`
3. Consider adding the misclassification detector (metric 3) as a health check endpoint (`/health/data-quality`) for monitoring

**Prerequisite**: None — can start immediately. The SQL queries above are tested and ready.

**Related sessions**: 2026-03-10-fallback-metadata-research.md (title_en gaps), 2026-03-01-lrt-admin-table-views.md (saved views)

**Ended**: 2026-03-12

## Notes
- `record_change_log` is `jsonb[]` column on `uk_lrt`
- 68 records have changelog but no `live_source` — their only entries are `airtable_sync` from 2024-03-26 (CSV import), not scraper runs
