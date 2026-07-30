---
session: Fractalaw Arrow Schema Adaptation
status: closed
opened: 2026-06-22
closed: 2026-06-22
---
# Title: Fractalaw Arrow Schema Adaptation

**Started**: 2026-06-22
**Context**: fractalaw restructured provision taxa payload — removed flat actor columns, added inference metadata

## Todo
- [x] Read breaking changes doc (`backend/data/fractalaw-schema-breaking-changes.md`)
- [x] Add `holder_inferred_from` and `ancestor_distance` attrs to LegalArticle
- [x] Wire new fields into `update_taxa` action accept list
- [x] Map new Arrow columns in ProvisionSubscriber `@field_atoms`
- [x] Fix stale `actors` description (was role/recipient_type, now position/relates_to/reason)
- [x] Fix `extraction_method` description (add classifier, local)
- [x] Migration `20260622000001` — add columns + recreate lat view
- [x] Verify migration runs clean
- [x] Run tests (1461 pass, 0 failures)
- [x] Commit

## Notes
- OrgScreeningProfile governed/government_actors NOT changed — user selections, not payload
- Baserow fallback to governed_actors kept — needed for historical data
- Law-level taxa payload unchanged
- duty_actor.ex/duty_type.ex unchanged — sertantai's own regex extractors

**Ended**: 2026-06-22
**Commits**: `84b3d03`, `cb5a9d3`

## Summary
- Completed: 10 of 10 todos
- Files: `legal_article.ex`, `provision_subscriber.ex`, migration `20260622000001`, `provision_subscriber_test.exs`
- Outcome: sertantai-legal now accepts the restructured fractalaw provision taxa payload with holder_inferred_from and ancestor_distance fields
- Next: none — adaptation complete, ready for next fractalaw enrichment run
