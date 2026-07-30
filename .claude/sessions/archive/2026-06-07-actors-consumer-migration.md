---
session: Migrate Consumers from Flat Actor Columns to Actors Struct
status: closed
opened: 2026-06-07
closed: 2026-06-07
---
# Title: Migrate Consumers from Flat Actor Columns to Actors Struct

**Started**: 2026-06-07 00:30
**Briefing**: backend/data/fractalaw-actors-struct-migration.md
**Ended**: 2026-06-07 11:30
**Commits**: `c07785c`, `702a439`, `60d6f0f`

## Todo
- [x] Baserow LAT sync: switch "Regulated Actors" → actors where position=active (extract_active_actors/1)
- [x] Profile query aggregation: switch governed_actors unnest → actors struct jsonb query
- [x] Document actor tag usage map → backend/data/actor-tag-usage-map.md
- [x] Remove governed_actors/government_actors from ProvisionSubscriber @field_atoms
- [x] Clarify actor tag semantics — covered in actor-tag-usage-map.md (positions, DRRP mapping, label sources)

## Notes
- Fractalaw briefing updated mid-session: role→position, holder→active (Hohfeldian)
- 68 OH&S laws republished with new schema: 6,279 provisions, 9,742 active actors
- QQ register: 153/274 laws enriched (55.8%), 31,366 provisions
- ProvisionSubscriber log noise fixed: per-section "not found" folded into summary line
- Fixed mcp-proxy: path /var/home, streamablehttp transport
- #107 updated with PGLite IDB crash stack trace during bulk enrichment
