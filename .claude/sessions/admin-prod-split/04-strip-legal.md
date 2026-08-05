---
session: Strip Legal + Sync Diverged Files
status: active
opened: 2026-08-05
---

# Session: Strip Legal + Sync Diverged Files (ACTIVE)

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
