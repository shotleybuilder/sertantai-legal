---
session: Definitions UI Debugging
status: closed
opened: 2026-08-24
closed: 2026-08-25
outcome: success

summary: >
  Fixed 7 bugs across the definitions admin UI — Electric proxy routing, header forwarding,
  chunked streaming for large responses, sync race conditions, definition line break preservation,
  generated column exclusion, and a data quality fix. Triaged 7 enhancement gaps into GitHub Issues
  (#154-#160) with PENDING sessions for future work.

decisions:
  - what: Excluded generated columns from Electric shape column list rather than altering the DB schema
    why: Electric cannot sync PostgreSQL generated columns; explicit column lists are safer than SELECT *
    result: Shape sync succeeds with 83K+ definitions without 400 errors
  - what: Switched Electric proxy from buffered to chunked streaming
    why: 10MB+ responses caused PauseLock deadlock when proxy buffered entire body before forwarding
    result: Large shape responses stream without blocking
  - what: Deferred 7 enhancements to GitHub Issues rather than fixing in this debugging session
    why: Each is a self-contained feature (SSE progress, progressive sync, GridLite, help glossary) requiring its own design scope
    result: Clean separation — bugs fixed here, features tracked in #154-#160 with PENDING sessions

metrics:
  bugs_fixed: 7
  bugs_deferred: 0
  enhancements_raised: 7
  github_issues_created: { first: 154, last: 160 }

lessons:
  - title: Electric proxy must forward all electric-* headers, not a whitelist
    detail: >
      PGlite sync client requires electric-has-data header to determine initial sync completion.
      A header whitelist in the proxy silently dropped it, causing sync to abort. Forward all
      electric-* prefixed headers rather than maintaining a list.
    tag: infrastructure
  - title: Large Electric shape responses need chunked streaming, not buffered proxy
    detail: >
      The initial proxy implementation read the full response body before forwarding. For the
      legislative_definitions shape (~10MB), this caused a PauseLock deadlock. Switching to
      chunked streaming fixed it.
    tag: infrastructure
  - title: Definition list parser must preserve ListItem line breaks
    detail: >
      DefinitionParser.parse joined ListItem text flat, losing structure. Fix: join with newlines
      and set whitespace-pre-line on the frontend. Both parser and UI needed changes.
    tag: data

bugs:
  - pattern: "ElectricSQL proxy route missing — /api/electric/* returned 404, no reverse proxy controller existed"
    category: infrastructure
    module: SertantaiLegalWeb.Router
    fix: "Added ElectricProxyController + GET /api/electric/*path route forwarding to Electric on port 3002"
    status: fixed
  - pattern: "legal_register shape includes generated columns (number_int, has_fitness) — Electric rejects with 400"
    category: electric-sync
    module: frontend/src/lib/pglite/sync.ts
    fix: "Excluded generated columns from ALL_COLUMNS list; has_fitness computed client-side in mapColumns"
    status: fixed
  - pattern: "Electric proxy dropped electric-has-data header — PGlite sync client aborted"
    category: infrastructure
    module: SertantaiLegalWeb.ElectricProxyController
    fix: "Forward all electric-* headers instead of whitelist; added electric-has-data to Corsica expose_headers"
    status: fixed
  - pattern: "UK_ukpga_1989_29 had family '⚡ Energy' instead of '💚 ENERGY' — one-off data corruption"
    category: data-quality
    module: legal_register
    affected: 1
    fix: "UPDATE legal_register SET family = '💚 ENERGY' WHERE name = 'UK_ukpga_1989_29'"
    status: fixed

artifacts:
  - backend/lib/sertantai_legal_web/controllers/electric_proxy_controller.ex
  - frontend/src/lib/pglite/sync.ts

depends_on:
  - interpretation-definitions/2026-08-21-definitions-ui-phase-1-backend-api
  - interpretation-definitions/2026-08-21-definitions-ui-phase-3-family-dashboard
  - interpretation-definitions/2026-08-21-definitions-ui-phase-4-law-browser
  - interpretation-definitions/2026-08-21-definitions-ui-phase-5-definition-detail
  - interpretation-definitions/2026-08-21-definitions-ui-phase-6-action-triggers
  - interpretation-definitions/2026-08-21-definitions-ui-phase-7-diagnostic-explorer

enables:
  - "interpretation-definitions/2026-08-25-issue-154-reparse-progress-messaging"
  - "interpretation-definitions/2026-08-25-issue-155-progressive-sync-filters"
  - "interpretation-definitions/2026-08-25-issue-156-sortable-columns"
  - "interpretation-definitions/2026-08-25-issue-157-diagnostic-persistence"
  - "interpretation-definitions/2026-08-25-issue-158-diagnostic-family-dropdown"
  - "interpretation-definitions/2026-08-25-issue-159-contextual-help"
  - "interpretation-definitions/2026-08-25-issue-160-gridlite-migration"
---

# Session: Definitions UI Debugging (CLOSED)

## Problem

User-reported UI bugs in the definitions admin pages built in phases 1-7 (2026-08-21). Fixing iteratively — user describes each bug, we investigate and fix, then move to the next.

## Todo

- ✅ Bug 1: Electric proxy route missing — 404 + CORS errors on /api/electric/*
- ✅ Bug 2: legal_register shape requests generated columns Electric rejects (400)
- ✅ Bug 3: Electric proxy dropped electric-has-data header → PGlite sync abort
- ✅ Bug 4: UK_ukpga_1989_29 had wrong family '⚡ Energy' (data fix, not code)
- ✅ Bug 5: Browse page loadData() races sync — effect guard prevented reload after sync
- ✅ Bug 6: Proxy buffered 10MB response → PauseLock deadlock — switched to chunked streaming
- ✅ Bug 7: Definition text missing line breaks — parser joined ListItem text flat + UI needed whitespace-pre-line

## Deferred to own sessions (GitHub Issues)

- **#154** — Reparse button: add staged progress messaging (SSE pattern from LAT parser)
- **#155** — Progressive sync strategy + filter redesign (cold start syncs 83K rows; needs bounded initial shape, richer filter bar beyond Family-only dropdown)
- **#156** — Sortable columns with compound Term+Section sort (currently fixed Term-alpha only; Section needs natural-number ordering)
- **#157** — Diagnostic: persist results across navigation + stale-data indicator when definitions change after last run
- **#158** — Diagnostic: family filter should be a dropdown (not free-text input requiring exact emoji+name)
- **#159** — Contextual help/glossary for domain terminology across all three definitions admin pages (ExDoc as source of truth)
- **#160** — Migrate all three definitions tables to svelte-gridlite-kit (already in project at v0.10.0; delivers #156 sorting for free)

## Dependencies

- ✅ Definitions UI phases 1-7 complete (2026-08-21)
- ✅ Backend API for definitions (phase 1)
- ✅ Definition data populated (66K+ definitions)
