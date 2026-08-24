---
session: Definitions UI Debugging
status: active
opened: 2026-08-24
depends_on:
  - interpretation-definitions/2026-08-21-definitions-ui-phase-1-backend-api
  - interpretation-definitions/2026-08-21-definitions-ui-phase-3-family-dashboard
  - interpretation-definitions/2026-08-21-definitions-ui-phase-4-law-browser
  - interpretation-definitions/2026-08-21-definitions-ui-phase-5-definition-detail
  - interpretation-definitions/2026-08-21-definitions-ui-phase-6-action-triggers
  - interpretation-definitions/2026-08-21-definitions-ui-phase-7-diagnostic-explorer
bugs:
  - pattern: "ElectricSQL proxy route missing — /api/electric/* returned 404, no reverse proxy controller existed"
    category: infrastructure
    module: SertantaiLegalWeb.Router
    fix: "Added ElectricProxyController + GET /api/electric/*path route forwarding to Electric on port 3002"
    status: fixed
  - pattern: "legal_register shape includes generated columns (number_int, has_fitness) — Electric rejects with 400"
    category: electric-sync
    module: frontend/src/lib/pglite/sync.ts
    fix: "Exclude generated columns from the legal_register shape column list"
    status: open
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
---

# Session: Definitions UI Debugging (ACTIVE)

## Problem

User-reported UI bugs in the definitions admin pages built in phases 1-7 (2026-08-21). Fixing iteratively — user describes each bug, we investigate and fix, then move to the next.

## Todo

- ✅ Bug 1: Electric proxy route missing — 404 + CORS errors on /api/electric/*
- ⬜ Bug 2: legal_register shape requests generated columns Electric rejects (400)
- ✅ Bug 3: Electric proxy dropped electric-has-data header → PGlite sync abort
- ✅ Bug 4: UK_ukpga_1989_29 had wrong family '⚡ Energy' (data fix, not code)
- ✅ Bug 5: Browse page loadData() races sync — effect guard prevented reload after sync
- ✅ Bug 6: Proxy buffered 10MB response → PauseLock deadlock — switched to chunked streaming
- ✅ Bug 7: Definition text missing line breaks — parser joined ListItem text flat + UI needed whitespace-pre-line

## Dependencies

- ✅ Definitions UI phases 1-7 complete (2026-08-21)
- ✅ Backend API for definitions (phase 1)
- ✅ Definition data populated (66K+ definitions)
