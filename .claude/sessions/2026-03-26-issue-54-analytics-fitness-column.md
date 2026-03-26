# Issue #54: Fix Admin Analytics page — column "fitness" does not exist in PGLite

**Started**: 2026-03-26
**Issue**: https://github.com/shotleybuilder/sertantai-legal/issues/54

## Todo
- [ ] Remove `fitness` column reference from analytics population query
- [ ] Replace with `has_fitness` or derive from individual fitness_* columns
- [ ] Test analytics page loads without errors

## Notes
- PGLite schema has fitness_person/process/place/plant/property/sector + has_fitness (TEXT)
- No `fitness` (JSONB[]) column — excluded from Electric sync as heavy data
