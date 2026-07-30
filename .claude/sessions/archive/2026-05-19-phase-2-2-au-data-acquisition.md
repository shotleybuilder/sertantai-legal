---
session: Phase 2.2 — AU Data Acquisition & Scraper
status: closed
opened: 2026-05-19
closed: 2026-05-19
---
# Title: Phase 2.2 — AU Data Acquisition & Scraper

**Started**: 2026-05-19
**Plan**: `.claude/plans/multi-jurisdiction.md`

## Seed Data
- `backend/data/combined-xdeduped.md` — 1,806 entries (890 unique), 11 EHS/environment categories
- Format: markdown list items, law titles with year and optional jurisdiction hints
- Categories: admin-legal-structure, general-environmental, air-emissions, water-management, waste-management, chemicals-management, hazardous-materials, safety-management, safety-technical, emergency, health-management

## Todo
- [x] Build seed parser (`mix au.import_seed`) with --dry-run support
- [x] Dedup by unique title (890 unique from 1806 total)
- [x] Infer jurisdiction from title patterns (state names, parenthetical codes)
- [x] Infer type_code from title (Act→act, Regulation→reg, Code of Practice→cop, etc.)
- [x] Assign family via `Countries.Au.family_keywords/0` title keyword matching
- [x] Generate `name` field as `AU_` + title slug (max 80 chars)
- [x] Import: 885 created, 5 skipped, 0 errors
- [x] All 1,227 tests pass
- [x] Analysed category distribution: 434/890 entries appear in multiple categories (up to 19)
- [x] Built category→family mapping (11 categories → 8 families, priority-ordered)
- [x] Multi-category logic: keyword match wins → category primary → category secondary for family_ii
- [x] Re-imported: family 49%→98.2%, family_ii 0%→58.5%
- [ ] QA pass: jurisdiction accuracy (837/890 default to cth — needs future enrichment)

## Import Stats (v2 — category-aware)
- Records: 885 AU + 19,492 UK = 20,377 total
- Family coverage: 98.2% (874/890) — only 16 unclassified
- Family_ii coverage: 58.5% (521/890)
- Jurisdiction: 837 cth (many likely misattributed — needs source URL enrichment later)
- Year coverage: 84.6% (753/890)

## Notes
- Section headers (air-emissions, waste-management, etc.) are HINTS only — not used for family
- Family comes from title keyword matching against AU family_keywords
- Some entries have jurisdiction in parentheses: "(S.R. No. 40/2026)" for VIC
- Some are model/national laws (Safe Work Australia, national codes) → jurisdiction = "cth"
- No source_url available from seed data — will be populated in a later scraping pass
- Entries without a year or identifiable jurisdiction may need manual review

**Ended**: 2026-05-19
**Commits**: `c7c56bc`
