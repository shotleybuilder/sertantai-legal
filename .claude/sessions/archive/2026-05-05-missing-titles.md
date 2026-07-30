---
session: Fetch missing title_en from legislation.gov.uk
status: closed
opened: 2026-05-05
closed: 2026-05-05
---
# Title: Fetch missing title_en from legislation.gov.uk

**Started**: 2026-05-05T17:05:00+01:00
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/83 (related)

## Todo
- [x] WILDLIFE & COUNTRYSIDE (175/175)
- [x] ENERGY (168/168)
- [x] PLANT HEALTH (134/134)
- [x] FISHERIES & FISHING (129/129)
- [x] WASTE (126/129 auto + 3 manual)
- [x] HEALTH: Coronavirus (109/109)
- [x] WATER & WASTEWATER (106/106)
- [x] TRANSPORT: Harbours & Shipping (79/79)
- [x] PLANNING & INFRASTRUCTURE (78/78)
- [x] FOOD (75/75)
- [x] POLLUTION (72/72)
- [x] MARINE & RIVERINE (58/58)
- [x] Remaining families (233/236 auto + 3 manual)
- [x] Manual fixes for 4 EU instruments with no h1

## Notes
- Total: 1,546 titles populated (0 remaining)
- 1,542 fetched via curl from legislation.gov.uk
- 4 set manually from tags (3 EU Decisions/Directives, 1 REACH regulation with no URL)
- Method: `curl -sL "$url" | grep -oP '<h1[^>]*>\K[^<]+' | head -1 | sed strip`
- 2s sleep between requests — no rate limiting issues

**Ended**: 2026-05-05T19:50:00+01:00
**Commits**: `ea4a095`

## Summary
- Completed: 14 of 14 todos
- Files touched: database only (uk_lrt.title_en column)
- Outcome: All 1,546 missing title_en values populated. Zero remaining across all families.
- Next: Issue #83 closed. Family_ii auto-assignment in parser remains a future enhancement.
