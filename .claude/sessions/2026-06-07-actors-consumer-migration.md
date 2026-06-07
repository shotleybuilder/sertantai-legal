# Title: Migrate Consumers from Flat Actor Columns to Actors Struct

**Started**: 2026-06-07 00:30
**Briefing**: backend/data/fractalaw-actors-struct-migration.md

## Todo
- [x] Baserow LAT sync: switch "Regulated Actors" → actors where position=active (extract_active_actors/1)
- [x] Profile query aggregation: switch governed_actors unnest → actors struct jsonb query
- [x] Document actor tag usage map → backend/data/actor-tag-usage-map.md
- [x] Remove governed_actors/government_actors from ProvisionSubscriber @field_atoms
- [ ] Clarify actor tag semantics in reference doc (carried forward)

## Notes
- Fractalaw briefing updated: role→position, holder→active, recipient→counterparty (Hohfeldian)
- New fields: relates_to (pairwise actor relations), reason (LLM reasoning)
- position=active gives duty/responsibility/power holders — the "Regulated Actors"
- Label prefix (Org:/Gvt:) available for display grouping but position is primary axis
- Current OH&S data has old schema (holder/recipient/etc.) — republish with new schema imminent
- Falls back to deprecated governed_actors flat column if actors is nil
