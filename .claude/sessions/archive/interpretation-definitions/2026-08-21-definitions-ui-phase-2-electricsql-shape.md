---
session: Definitions UI Phase 2 — ElectricSQL Shape
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Added ElectricSQL shape sync for legislative_definitions (83K rows) and definition_links
  (2.8K rows) to PGLite. Updated 106 frontend dependencies within semver ranges. Electric
  shapes verified serving correct data. Browser sync test deferred to Phase 3 integration.

decisions:
  - what: Sync all definition columns including full definition text
    why: >
      Average definition is 161 chars, total table is 50MB. PGLite handles this fine —
      the laws table is similar size. Excluding definition text would save ~13MB but
      would require an API call for every detail view, defeating the offline-first goal.
    result: All 13 columns synced, no column exclusions needed
  - what: Only safe semver updates, no major version bumps
    why: >
      Svelte 4→5, Vite 5→8, TypeScript 5→7 are major migrations that would derail
      the definitions UI work. Electric packages already at latest (client 1.5.26,
      pglite 0.5.5, pglite-sync 0.6.6).
    result: 106 packages updated, 0 breaking changes, type check + build clean
  - what: Add definition_links to Electric publication manually via ALTER PUBLICATION
    why: >
      Electric auto-created electric_publication_default with specific tables on first
      connect. New tables must be explicitly added. No migration needed — this is a
      runtime config on the dev database.
    result: definition_links added, shape endpoint returns 200

metrics:
  data_sizes:
    definitions_rows: 83369
    definition_links_rows: 2814
    definitions_table_size: "50 MB"
    avg_definition_length: 161
    max_definition_length: 11325
  schema:
    version_before: 17
    version_after: 18
    new_tables: 2
    new_indexes: 6
  dependencies:
    packages_updated: 106
    breaking_changes: 0

lessons:
  - title: "Electric publication must be updated manually when adding new sync tables"
    detail: >
      Electric creates electric_publication_default on first connection with whatever
      tables it finds. New tables added later need ALTER PUBLICATION ... ADD TABLE.
      This is a dev-only step — production Electric would need the same treatment.
      Check pg_publication_tables to verify.
    tag: sync
  - title: "npm update after SvelteKit upgrade can leave stale Vite processes"
    detail: >
      After npm update changed 106 packages, the existing dev server on port 5175
      returned 500 with __SVELTEKIT_APP_VERSION__ not defined. The old Vite process
      had cached the pre-update modules. Must kill and restart dev server after any
      npm update that touches @sveltejs/kit or vite.
    tag: infrastructure
  - title: "@sveltejs/kit 2.70 emits untrack/fork/settled import warnings with Svelte 4"
    detail: >
      After updating @sveltejs/kit to 2.70.3, the build emits warnings about
      untrack, fork, settled not being exported from svelte runtime. These are
      Svelte 5 APIs that kit now references but Svelte 4 doesn't have. Harmless
      at runtime (tree-shaken), but noisy. Will resolve when upgrading to Svelte 5.
    tag: infrastructure

artifacts:
  - frontend/src/lib/pglite/schema.sql.ts
  - frontend/src/lib/pglite/sync.ts
  - frontend/package-lock.json

depends_on:
  - 2026-08-21-definitions-ui-phase-1-backend-api
  - 2026-08-21-definitions-admin-ui

enables:
  - 2026-08-21-definitions-ui-phase-3-family-dashboard
  - 2026-08-21-definitions-ui-phase-4-law-browser
  - 2026-08-21-definitions-ui-phase-5-definition-detail
---

# Session: Definitions UI Phase 2 — ElectricSQL Shape (CLOSED)

## Problem

Definitions (66K rows) and definition_links (5K rows) need to sync to PGLite via ElectricSQL for offline-first browsing in the admin UI. Follow the established pattern from uk_lrt/laws shape sync. Frontend dependencies (ElectricSQL, PGLite, SvelteKit) should be updated to latest before building new shapes.

## Todo

- ✅ Update frontend dependencies — 106 packages updated within semver ranges, type check + build pass
- ✅ Verify existing sync still works after updates — build succeeds, no breaking changes
- ✅ Add `definitions` and `definition_links` tables to PGLite schema (`schema.sql.ts`)
- ✅ Add shape subscriptions in `sync.ts` (following laws pattern)
- ✅ Sync all columns (avg definition 161 chars, 50MB total — manageable for PGLite)
- ✅ Bump `SCHEMA_VERSION` 17→18 to trigger schema recreation
- ✅ Add indexes on `law_name`, `term`, `references_other_law`, `citation`, composite `(law_name, term)`, and `root_definition_id`
- ✅ Added `definition_links` to Electric publication (`electric_publication_default`)
- ✅ Verified Electric shape endpoints serve data (both return 200 with correct schemas)
- ⏸️ Test sync performance with 83K definitions in browser (deferred — will verify during Phase 3 integration)

## Dependencies

- ✅ ElectricSQL shape pattern established (sync.ts, schema.sql.ts, client.ts)
- ✅ PGLite singleton with live + electric extensions
- ✅ Phase 1 — Backend API (closed, endpoints working)
