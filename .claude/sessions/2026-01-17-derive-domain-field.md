# Title: derive-domain-field

**Started**: 2026-01-17
**Issue**: None

## Context
Update parser to derive and persist `domain` field from `family` / `family_ii` columns.

## Todo
- [x] Understand current family/family_ii values and domain mapping
- [x] Add domain derivation logic to parser
- [x] Persist domain field to database
- [x] Test with sample laws

## Notes
- Domain should be derived from family hierarchy

**Ended**: 2026-01-17

## Summary
- Completed: 4 of 4 todos
- Files touched: `parsed_law.ex`, `derive_domain_from_family.exs` (new)
- Outcome: Domain now auto-derived from family emoji prefixes in to_db_attrs pipeline. Migrated 3,888 existing records.
- Next: None - feature complete
