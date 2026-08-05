---
session: Strip Legal + Sync Diverged Files
status: closed
opened: 2026-08-05
closed: 2026-08-05
outcome: success

summary: >
  Re-synced 6 diverged files from legal's Baserow work, then stripped all customer-facing
  code from legal across 9 dependency-ordered blocks. Legal went from 262 to 175 backend
  files, 1535 to 1337 tests, zero warnings. Legal is now admin-only.

decisions:
  - what: "Re-sync diverged files before stripping, not after"
    why: "Legal had 3 commits of Baserow work since Phase 3 that modified 6 files already in compliance. Syncing first ensures compliance has the latest, then stripping is clean."
    result: "6 files re-synced + 1 new template + 5 baserow/app modules copied to compliance"
  - what: "Strip in 9 dependency-ordered blocks with compile+test between each"
    why: "87 files with deep dependency chains. Removing leaf nodes first (app builder, frontend, controllers) then working inward to foundation (org resources, sync domain) prevents cascading failures."
    result: "9 blocks, 9 clean compiles, zero test failures at each step"
  - what: "Replace taxa_subscriber ApplicabilityEvent.log with raw SQL insert"
    why: "ApplicabilityEvent Ash resource moved to compliance but taxa_subscriber (Zenoh enrichment) stays in legal. Raw SQL avoids the dependency while writing to the same shared table."
    result: "INSERT INTO applicability_events directly — no Ash resource needed"
  - what: "Electric/PGLite/stores/views frontend libs are shared — kept in legal"
    why: "Admin /admin/lrt browse page uses PGLite + Electric for the same offline-first GridLite browsing. Removing them would break admin."
    result: "Only api/sync.ts and customer routes removed from frontend"
  - what: "Law write endpoints (PATCH/DELETE /laws/:id) moved from api_authenticated to api_admin pipeline"
    why: "api_authenticated pipeline removed (customer-facing). Law editing is admin-only, so api_admin is correct."
    result: "3 endpoints preserved under stricter auth"

metrics:
  files: { before: 262, after: 175, removed: 87 }
  tests: { before: 1535, after: 1337, removed: 198 }
  blocks: 9
  re_synced_files: 6
  skills_moved: 13
  mix_tasks_removed: 8
  controllers_removed: 5
  templates_removed: 31
  frontend_tests: { before: 127, after: 127 }

lessons:
  - title: "Active development on shared code causes divergence — split sooner"
    detail: "The Baserow self-hosted migration happened in legal between Phase 3 and Phase 4, modifying 6 files already copied to compliance. This created a re-sync burden. User correctly identified the root cause: Baserow app building is customer/compliance work, not legal data enrichment. Future feature work should happen in compliance."
    tag: tooling
  - title: "Dependency-ordered block removal is the safest stripping strategy"
    detail: "Removing 87 files in one go would produce dozens of compilation errors. By working from leaf nodes (app builder, frontend, controllers) inward to foundation (org resources, sync domain), each block compiled cleanly and tests passed before proceeding. Only 2 cross-boundary fixes needed (ChangeDetector.trigger_async removal, ApplicabilityEvent→raw SQL)."
    tag: infrastructure
  - title: "Electric/PGLite are shared infrastructure, not customer-only"
    detail: "Initially assumed Electric and PGLite frontend libs were customer-only and could be removed from legal. The admin /admin/lrt page uses PGLite for offline-first GridLite browsing via the same sync mechanism. These are shared."
    tag: sync

artifacts:
  - CLAUDE.md
  - backend/config/config.exs
  - backend/lib/sertantai_legal_web/router.ex
  - backend/lib/sertantai_legal/application.ex
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex
  - frontend/src/routes/+page.svelte

depends_on:
  - 03-customer-frontend.md

enables:
  - "Phase 5: Production cutover"
  - "All future customer feature work happens in sertantai-compliance"
---

# Session: Strip Legal + Sync Diverged Files (CLOSED)

## Problem

Phase 4 of the admin/prod split: remove customer-facing code from sertantai-legal. However, since Phase 3, legal has had active development on Baserow features (self-hosted migration, multi-customer demo, Customers template) that modified 6 files already copied to compliance + added 1 new template. These files have diverged and need re-syncing before stripping.

## Todo

- ✅ Re-sync 6 diverged files from legal → compliance (client.ex, engine.ex, profile_query.ex, applicator.ex, foundation.ex, registry.ex)
- ✅ Copy new customers.ex template + baserow/app/ (builder, page_builder, field_resolver, recipe_parser, schema_manager) + scripts + skill
- ✅ Fix Scraper.Models ref (re-introduced by re-sync), clean 3 warnings
- ✅ Compliance compiles (--warnings-as-errors), backend 2/2, frontend 73/73
- ✅ Block 1: Baserow app builder (4 app modules + 1 mix task + 2 scripts removed, 257 files compile clean)
- ✅ Block 2: Customer frontend (removed /app, /auth, /browse, /sync routes + api/sync.ts. Electric/PGLite/stores/views are shared — admin needs them. Root page redirects to /admin. 127 FE tests pass)
- ✅ Block 3: Customer controllers + router (5 controllers + 1 plug + 2 test files removed, router cleaned, api_authenticated/api_webhook pipelines removed, law write endpoints moved to api_admin. 251→249 files, 1459 tests pass)
- ✅ Block 4: Sync templates (31 templates + 2 mix tasks + 2 test files + application.ex ref removed. 249→218 files, 1383 tests pass)
- ✅ Block 5: Sync engine + providers + workers (9 modules + 5 mix tasks + 3 test files removed. 218→204 files, 1361 tests pass)
- ✅ Block 6: Change detection + fitness (4 modules + 2 tests removed, 2 ChangeDetector.trigger_async() calls removed from scraper. 204→200 files, 1337 tests pass)
- ✅ Block 7: Baserow client + schema_manager (2 files + dir removed. 200→198 files, 1337 tests pass)
- ✅ Block 8: Org resources + sync domain + enums (22 resources/enums + sync.ex domain removed, config.exs updated, taxa_subscriber ApplicabilityEvent→raw SQL. Delta/ stays. 198→175 files, 1337 tests pass)
- ✅ Block 9: Skills (13 customer-facing skills moved to compliance), CLAUDE.md rewritten for admin-only scope. 175 files, 1337 tests pass

## Dependencies

- ✅ Phase 3 complete: admin-prod-split/03-customer-frontend.md
- ✅ Baserow self-hosted migration landed in legal (062cff2)
