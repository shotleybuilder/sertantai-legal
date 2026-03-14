# Title: Add Taxa and Fitness record groups to admin LRT detail view

**Started**: 2026-03-14
**Status**: Complete

## Todo
- [x] Add fitness labels to FIELD_LABELS in field-config.ts
- [x] Add Stage 7 taxa section to SECTION_CONFIG
- [x] Add Stage 8 fitness section to SECTION_CONFIG
- [x] Widen FieldConfig.stage and SectionConfig.stage types for 'taxa' | 'fitness'
- [x] Add fitness fields to record_to_json/1 in uk_lrt_controller.ex
- [x] Move fitness JSONB[] to HEAVY_JSONB_COLUMNS in sync.ts
- [x] Remove fitness JSONB[] from PGLite schema, add has_fitness, bump schema v9
- [x] Per-subsection heavy detection in RecordDetailPanel
- [x] Server-side has_fitness generated column + migration (59 true / 19271 false)
- [x] has_fitness grid filter (select dataType, TEXT column, mapColumns computed)
- [x] Build fitness detail renderer (group-by-article / group-by-person views)
- [x] Verify full flow

## Files Changed
- `backend/lib/sertantai_legal/legal/uk_lrt.ex` — has_fitness attribute
- `backend/lib/sertantai_legal_web/controllers/uk_lrt_controller.ex` — record_to_json/1
- `backend/priv/repo/migrations/20260314173533_add_has_fitness.exs`
- `frontend/src/lib/components/FitnessRulesRenderer.svelte` — NEW: group-by-article/person
- `frontend/src/lib/components/RecordDetailPanel.svelte` — per-subsection heavy, fitness renderer
- `frontend/src/lib/components/parse-review/field-config.ts` — labels, types, Stage 7+8
- `frontend/src/lib/pglite/schema.sql.ts` — has_fitness TEXT col, schema v9
- `frontend/src/lib/pglite/sync.ts` — fitness in HEAVY_JSONB, has_fitness mapColumns
- `frontend/src/routes/admin/lrt/+page.svelte` — grid column + cell renderer

## Notes
- Electric can't sync generated columns → has_fitness computed in mapColumns
- PGLite stores has_fitness as TEXT 'true'/'false' (gridlite-kit boolean filter bug)
- Fitness tag arrays synced to PGLite; fitness JSONB[] rules are heavy (REST only)
- RecordDetailPanel now supports mixed heavy/light subsections within a section
