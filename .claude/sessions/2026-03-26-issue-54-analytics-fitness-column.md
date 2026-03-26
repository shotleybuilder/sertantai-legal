# Issue #54: Fix Admin Analytics page — column "fitness" does not exist in PGLite

**Started**: 2026-03-26
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/54

## Todo
- [x] Remove `fitness` column reference from analytics population query
- [x] Replace with `has_fitness` or derive from individual fitness_* columns
- [x] Exclude `fitness` from Electric shape columns + bump SCHEMA_VERSION

**Ended**: 2026-03-26

---

**Reopened**: 2026-03-26
**Reason**: API sections (Live Status Assurance, Change Tracking, Session Analytics) showing "Unauthorized" for owner role. PGLite sync broken (0 records).

## Todo (reopened)
- [ ] Fix "Unauthorized" on API-backed analytics sections for owner role
- [ ] Fix PGLite sync (0 records on analytics page)
- [ ] Create tests to prevent regressions on analytics page
