# Title: OH&S Data Quality Audit

**Started**: 2026-03-12

## Todo

### Phase 1: Live Status Classification Stress Test
- [x] Random sample 20 OH&S laws >20 years old
- [x] Check reconciliation columns (`live_source`, `live_from_changes`, `live_from_metadata`)
- [x] Check changelog coverage across OH&S
- [ ] Re-examine after user reruns OH&S scrape

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

### Next step
- Reparse the 71 null-title OH&S records with current code (has 4-fallback chain)
- Then re-examine coverage — should reach ~95%+

## Notes
- `record_change_log` is `jsonb[]` column on `uk_lrt`
- 68 records have changelog but no `live_source` — their only entries are `airtable_sync` from 2024-03-26 (CSV import), not scraper runs
