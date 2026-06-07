# Title: Fractalaw Actors Struct Migration

**Started**: 2026-06-06 22:00
**Briefing**: backend/data/fractalaw-actors-struct-migration.md

## Todo
- [ ] Document actor tag usage map (where governed/government_actors are used across codebase)
- [x] Fix (inferred) bug — stripped at TaxaSubscriber ingest, cleaned 370 laws in DB, removed 34 dupes from @holder_options
- [x] Add `actors` column to LegalArticle schema ({:array, :map} for structured actors)
- [x] Add `extraction_method` column to LegalArticle (regex|inherited|agentic|agentic_unvalidated)
- [x] Update ProvisionSubscriber to parse new `actors` struct + extraction_method alongside flat columns
- [x] Add actors + extraction_method to update_taxa action accept list
- [ ] Clarify actor tag semantics in a reference doc (holder vs recipient vs beneficiary vs mentioned)

## Notes
- Briefing: fractalaw now publishes structured `actors` per provision (role, label_source, recipient_type)
- Flat governed_actors/government_actors still dual-written for backward compat
- Phase 1: read actors struct alongside flat columns, fix (inferred) bug
- Phase 2 (future): drop flat columns after migration confirmed
- Law-level JSONB holders (duty_holder etc.) are separate from provision-level actors — don't conflate
- Profile matching uses law-level holders, NOT provision-level actors
- ~190 entries in @holder_options, many with (inferred) suffix = duplicates to remove
