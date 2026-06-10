# Title: Templates v0.2 — Actor Tuple Table for Baserow

**Started**: 2026-06-10 00:30
**Plan**: .claude/plans/baserow-compliance-templates.md
**Ended**: 2026-06-10 03:00
**Commits**: `054928b`, `ec4c278`, `31f4d2d`, `7b0510e`

## Todo
- [x] Build Actor Tuples table — one row per (actor, position, drrp_type) from corpus
- [x] Seed tuples from actual actors struct data (canonical only, governed only for QQ)
- [x] LAT table: Actor Roles link_row field → Actor Tuples (many-to-many)
- [x] Sync engine: create tuples table, link LAT rows to matching tuples
- [x] Verify "Employer Duties" query works in Baserow — confirmed, 38 linked provisions
- [x] Row count check: 127 LRT + 2,162 LAT + 357 tuples = 2,646 (under 3K free tier)

## Notes
- 357 governed-only tuples, 182 LAT provisions linked
- Fixed: SourceType enum, link field creation, UUID mapping, aggregated query dispatch
- Dynamic field options (all select options from DB), aggregation fallback to flat actors
- 8 new profile_query tests, lat view fix for test DB
