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

### Phase 1b: Admin LRT UI for Targeted Reparsing ✅
- [x] Add "Analytics" view group with "Live" view showing live-* columns (both LRT + LAT queue pages)
- [x] Add Reparse View button to LRT page — uses current table records, confirmation dialog, creates session
- [x] Backend: `ReparseManager.create_from_names/1` + `POST /api/sessions/reparse/from-view`
- [x] Keep existing Reparse Family dialog as secondary option

### Phase 2: Full Text Parsing Failures
- [ ] Identify recent OH&S laws with zero LAT content
- [ ] Investigate root causes for parsing failures
- [ ] Categorize failure types

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

## Notes
- `record_change_log` is `jsonb[]` column on `uk_lrt`
- 68 records have changelog but no `live_source` — their only entries are `airtable_sync` from 2024-03-26 (CSV import), not scraper runs
