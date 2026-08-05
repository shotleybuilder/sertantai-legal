---
session: "Admin/Prod Split — Meta Tracker"
status: closed
opened: 2026-07-30
closed: 2026-08-05
outcome: success

summary: >
  Split sertantai-legal into admin-only data workbench and sertantai-compliance
  as production SaaS across 5 phases. 73 backend files + 35 frontend files migrated,
  87 files stripped from legal (262→175), all data deployed to production (471K rows).
  compliance.sertantai.com live and verified.
---

# Session: Admin/Prod Split — Meta Tracker (CLOSED)

## Problem

Implementing the admin/production split plan (.claude/plans/admin-prod-split.md) requires coordinated work across 6 phases. This meta-session tracks phase progress and links to delivery sessions. Sessions are scoped to natural working units, not artificially split by plan bullet points.

## Todo

- ✅ Phase 0+1: Prepare and bootstrap compliance
- ✅ Phase 2: Move customer backend
- ✅ Phase 3: Move customer frontend
- ✅ Phase 4: Strip legal
- ✅ Phase 5: Production cutover

## Phase 0+1: Prepare & Bootstrap Compliance

Phases 0 and 1 merged — preparation work only matters at production time, and compliance dev shares `sertantai_legal_dev`. One session to stand up compliance with auth, read-only resources, and Electric.

| Session | Scope | Status |
|---------|-------|--------|
| `01-bootstrap.md` | Auth infra, read-only Ash resources for reference data, Electric config, org-scoped migrations against legal_dev | **closed** |

## Phase 2: Move Customer Backend

Move all customer-facing Elixir code. Screening/fitness and sync/webhooks are tightly coupled — likely one session unless it gets too large.

| Session | Scope | Status |
|---------|-------|--------|
| `02-customer-backend.md` | Move screening controller, fitness module, sync engine + 27 templates, webhook controllers, org resources. Verify API parity. | **closed** |

## Phase 3: Move Customer Frontend

Move all customer-facing Svelte code. Routes, stores, components, and E2E verification in one session.

| Session | Scope | Status |
|---------|-------|--------|
| `03-customer-frontend.md` | Move /app/*, /browse, /sync, /auth/callback routes. Auth store, PGLite/Electric sync, GridLite adapter, components. E2E verification. | **closed** |

## Phase 4: Strip Legal

Remove customer code from legal. Small enough for one session.

| Session | Scope | Status |
|---------|-------|--------|
| `04-strip-legal.md` | Remove customer routes/pages/controllers from legal. Update delta sync to target compliance_prod. Remove legal from Hetzner deploy. | **closed** |

## Phase 5: Production Cutover

Deploy to Hetzner. This splits into prep (schema seed, data migration) and go-live (deploy, verify).

| Session | Scope | Status |
|---------|-------|--------|
| `05-production-cutover.md` | Deploy partition migrations, push 471K rows reference data, verify compliance.sertantai.com loads | **closed** |

## Dependencies

- ✅ Plan written and Gemini-reviewed: .claude/plans/admin-prod-split.md
- ✅ Research session: 2026-07-30-plans-housekeeping-and-split-research.md
