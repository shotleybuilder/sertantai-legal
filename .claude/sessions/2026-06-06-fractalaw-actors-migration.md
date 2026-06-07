# Title: Fractalaw Actors Struct Migration

**Started**: 2026-06-06 22:00
**Briefing**: backend/data/fractalaw-actors-struct-migration.md
**Ended**: 2026-06-07 00:30
**Commits**: `c07785c`

## Todo
- [ ] Document actor tag usage map → **carry forward**
- [x] Fix (inferred) bug — stripped at TaxaSubscriber ingest, cleaned 370 laws in DB, removed 34 dupes from @holder_options
- [x] Add `actors` column to LegalArticle schema ({:array, :map} for structured actors)
- [x] Add `extraction_method` column to LegalArticle (regex|inherited|agentic|agentic_unvalidated)
- [x] Update ProvisionSubscriber to parse new `actors` struct + extraction_method alongside flat columns
- [x] Add actors + extraction_method to update_taxa action accept list
- [ ] Clarify actor tag semantics in a reference doc → **carry forward**

## Notes
- 4,800 provisions populated with actors struct after fractalaw OH&S republish
- Struct finds 37% more actors than flat columns (1.49 vs 1.09 per provision)
- 1,684 extra holders the flat columns were silently dropping
- New: 90 recipients, 59 beneficiaries, 112 mentioned — invisible before
- 100% canonical labels in this corpus
- Fractalaw no longer dual-writes flat columns — migration of consumers needed (next session)
- #107 raised: screening page null rows after enrichment flow
