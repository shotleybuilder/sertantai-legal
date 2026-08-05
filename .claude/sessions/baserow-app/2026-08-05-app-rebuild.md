---
session: Baserow App — Self-Hosted Rebuild
status: closed
opened: 2026-08-05
closed: 2026-08-05
outcome: partial

summary: >
  Rebuilt the Compliance Workbench app on self-hosted Baserow (14 pages, app ID 231).
  Fixed two builder bugs (link params, row_id format) and added SaaS/self-hosted
  auto-detection for API differences. App structure is in place but page-level errors
  need a debug session. Baserow Cloud SaaS account can be closed.

decisions:
  - what: Auto-detect SaaS vs self-hosted rather than config flag
    why: Customers may be on either platform. Try-then-fallback avoids forcing them to declare their environment.
    result: row_id tries plain string then formula object; publish tries baserow.site then skips gracefully

  - what: Store email/password + database_token together in credentials
    why: App Builder API needs JWT (from email/password), sync needs permanent database token. Single credential store, dual auth paths.
    result: Client.authenticate prefers email/password for JWT when present, falls back to token-only for sync

  - what: Bug 3 (field_ID vs field names) is not a bug
    why: Recipes already use correct format — field names for data_source refs, {curlied} field names for table column formulas. FieldResolver only interpolates curlied patterns.
    result: No code change needed

lessons:
  - title: Self-hosted Baserow row_id API expects plain string, SaaS expects formula object
    detail: >
      Self-hosted (open-source) Baserow's data source PATCH endpoint expects row_id as a
      plain string like "get('page_parameter.id')". The SaaS version wraps it in
      {"formula": "...", "mode": "simple", "version": "0.1"}. The try/fallback pattern
      handles both without configuration.
    tag: baserow

  - title: Self-hosted Baserow can't publish to baserow.site subdomains
    detail: >
      The baserow.site subdomain publishing is SaaS-only. Self-hosted instances need a
      custom domain configured via the Baserow admin UI, or publishing is skipped. The
      builder now handles this gracefully — tries subdomain creation, skips on failure.
    tag: baserow

  - title: Baserow App Builder API requires JWT, not database tokens
    detail: >
      The App Builder endpoints (pages, elements, data sources, workflows, publishing)
      are metadata APIs that require JWT auth. Database tokens only work for row-level
      CRUD. Credentials must store both email/password (for JWT) and database_token
      (for sync) to support both app building and data sync.
    tag: baserow

artifacts:
  - backend/lib/sertantai_legal/baserow/app/page_builder.ex
  - backend/lib/sertantai_legal/baserow/app/builder.ex
  - backend/lib/sertantai_legal/baserow/client.ex
  - backend/scripts/update_sync_target.exs

depends_on:
  - 2026-08-05-cloud-to-hetzner.md
  - 2026-07-20-build.md

enables:
  - App debug session (fix page-level errors, manual steps, customer scoping)
  - Decommission Baserow Cloud SaaS account
---

# Session: Baserow App — Self-Hosted Rebuild (CLOSED)

## Problem

The Compliance Workbench app needs to be rebuilt on the self-hosted Baserow (`baserow.sertantai.com`, database 230). The existing 7 YAML recipes and `mix app.build` builder were created for the cloud instance — field IDs differ on the new database so the FieldResolver will pick up fresh IDs. Three known builder bugs from the cloud build remain unfixed (link params, row_id formulas, field_ID vs field names). The app must also be scoped to QQ via the Customers link_row filter on data sources.

## Todo

- ✅ Fix builder bug: link element `query_parameters` / `page_parameters` — added to regular link elements (was only on table columns)
- ✅ Fix builder bug: Get Row data source `row_id` — auto-detects SaaS vs self-hosted format
- ❌ Builder bug: data source element formulas use `field_ID` — not a bug, recipes already correct
- ✅ Auth: credentials store email/password + database_token together
- ✅ SaaS/self-hosted compat: row_id try/fallback, publish skip on failure
- ✅ Run `mix app.build` — 14 pages created, app ID 231
- ⏸️ Add customer scoping to app data sources — deferred to debug session
- ⏸️ Fix action rollup fields (Actions_Open/Overdue/Done) — deferred, Phase 3 ordering
- ⏸️ Test + fix app page errors — deferred to debug session
- ⏸️ Manual steps (form nesting, workflow actions) — deferred to debug session
- ✅ Decommission Baserow Cloud account — user closing SaaS account

## Dependencies

- ✅ Self-hosted Baserow with 14 tables, 651 rows synced — `2026-08-05-cloud-to-hetzner.md`
- ✅ QQ customer row linked to all LRT rows
- ✅ Recipe-driven app builder (`mix app.build`, 7 YAML recipes) — `2026-07-20-build.md`
- ✅ Database token auth configured
