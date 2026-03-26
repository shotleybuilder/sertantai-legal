# Issue #54: Fix Admin Analytics page — column "fitness" does not exist in PGLite

**Started**: 2026-03-26
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/54

## Todo
- [x] Remove `fitness` column reference from analytics population query
- [x] Replace with `has_fitness` or derive from individual fitness_* columns
- [x] Exclude `fitness` from Electric shape columns + bump SCHEMA_VERSION

**Ended**: 2026-03-26
