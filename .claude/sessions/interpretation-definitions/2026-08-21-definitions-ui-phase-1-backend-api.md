---
session: Definitions UI Phase 1 — Backend API
status: closed
opened: 2026-08-21
closed: 2026-08-22
outcome: success

summary: >
  Built DefinitionsAdminController with 4 authenticated admin endpoints for definition
  resolution management — stats, diagnostic, parse, and resolve. All 13 tests pass,
  1023 tests across scraper + controller suites with 0 failures.

decisions:
  - what: Use raw SQL CTEs for stats rather than Ash queries
    why: >
      Stats endpoint joins legislative_definitions with legal_register and definition_links
      across 66K+ rows with GROUP BY family. Raw SQL with CTEs is clearer and more performant
      than composing Ecto queries across three tables with aggregate functions.
    result: Single query returns all family stats in <100ms
  - what: Fire-and-forget Tasks for parse/resolve operations
    why: >
      Parse and resolve are long-running operations (minutes for family-scope parse with
      rate limiting). HTTP endpoint should return immediately with {status: started}.
      Full job tracking deferred to Phase 6 (action triggers with progress feedback).
    result: Endpoints return immediately, background tasks log progress
  - what: Diagnostic results via API call, not ElectricSQL sync
    why: >
      Diagnostic findings are ephemeral — recomputed each run from current DB state.
      Syncing via ElectricSQL would require a persistence table and staleness management.
      API call is simpler and always returns fresh data.
    result: Diagnostic endpoint runs full Diagnostic.run/1 on each call
  - what: Route prefix /api/definitions/admin/* not /api/admin/definitions/*
    why: >
      Existing public endpoints are at /api/definitions. Nesting admin under the same
      resource prefix keeps definition-related routes grouped. The api_admin pipeline
      handles auth regardless of path structure.
    result: Clean URL grouping — /api/definitions for public, /api/definitions/admin/* for admin

metrics:
  tests:
    controller_tests: 13
    controller_failures: 0
    full_suite: 1023
    full_failures: 0
  endpoints:
    stats: "GET /api/definitions/admin/stats"
    diagnostic: "GET /api/definitions/admin/diagnostic"
    parse: "POST /api/definitions/admin/parse"
    resolve: "POST /api/definitions/admin/resolve"

lessons:
  - title: "Raw binary UUIDs from Ecto string-table queries need casting before JSON encoding"
    detail: >
      When using from(d in "legislative_definitions", select: %{id: d.id}), the id
      comes back as a raw 16-byte binary, not a string UUID. Jason.encode! raises
      invalid byte errors. Fix: Ecto.UUID.cast/1 converts binary to string format.
      This only affects string table names — Ash module references return proper types.
    tag: infrastructure
  - title: "linked_counts must filter to cross-refs only to prevent effective % > 100%"
    detail: >
      The initial stats query counted ALL definitions with links in definition_links,
      but the denominator (cross_refs) only counts references_other_law=true AND
      citation=false. Some linked definitions may have citation=true or
      references_other_law=false, making linked > cross_refs. Fix: add the same
      WHERE filters to the linked_counts CTE.
    tag: data
  - title: "Ecto SQL Sandbox and fire-and-forget Tasks are inherently incompatible"
    detail: >
      Task.start spawns a process that outlives the test. Even with
      Ecto.Adapters.SQL.Sandbox.allow, the test process exits before the Task
      checks out its connection, causing Postgrex disconnection errors. The tests
      pass (they only verify the HTTP response), but produce noisy error logs.
      @tag :capture_log suppresses logger output but not Postgrex stderr. This is
      cosmetic — the real fix would be Task.async + await, but that changes the
      fire-and-forget semantics needed in production.
    tag: infrastructure

artifacts:
  - backend/lib/sertantai_legal_web/controllers/definitions_admin_controller.ex
  - backend/test/sertantai_legal_web/controllers/definitions_admin_controller_test.exs

depends_on:
  - 2026-08-21-definitions-admin-ui

enables:
  - 2026-08-21-definitions-ui-phase-2-electricsql-shape
  - 2026-08-21-definitions-ui-phase-3-family-dashboard
  - 2026-08-21-definitions-ui-phase-6-action-triggers
  - 2026-08-21-definitions-ui-phase-7-diagnostic-explorer
---

# Session: Definitions UI Phase 1 — Backend API (CLOSED)

## Problem

The definitions admin UI needs backend endpoints for stats, diagnostic results, and operation triggers. Currently all definition operations are CLI-only (mix tasks, Tidewave eval). Need authenticated admin endpoints that the SvelteKit frontend can call.

## Todo

- ✅ Create `DefinitionsAdminController` module
- ✅ `GET /api/definitions/admin/stats` — family-level aggregated stats (defs, cross-refs, linked, effective %)
- ✅ `GET /api/definitions/admin/diagnostic` — run diagnostic, return findings as JSON (optional family filter)
- ✅ `POST /api/definitions/admin/parse` — trigger parse for a law name or family scope
- ✅ `POST /api/definitions/admin/resolve` — trigger root resolver (async via Task)
- ⏸️ `GET /api/definitions/admin/diagnostic/history` — deferred, needs diagnostic persistence table
- ✅ Add routes under authenticated admin scope in router.ex
- ✅ Tests for each endpoint (13 tests, 0 failures)

## Dependencies

- ✅ Diagnostic module stable (Diagnostic.run/1, summarise/1)
- ✅ RootResolver.resolve_all/1 working
- ✅ DefinitionParser + DefinitionPersister working
- ✅ Admin auth middleware in router.ex
