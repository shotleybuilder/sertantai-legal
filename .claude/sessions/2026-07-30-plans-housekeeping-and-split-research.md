---
session: Plans Housekeeping & Admin/Prod Split Research
status: closed
opened: 2026-07-30
closed: 2026-07-30
outcome: success

summary: >
  Added YAML frontmatter and archival to .claude/plans (20 files audited, 8 archived).
  Researched and planned splitting sertantai-legal into admin-only (local) and moving
  customer-facing features to sertantai-compliance (production SaaS). Gemini-reviewed
  twice — simplified from two-database to single-database architecture.

decisions:
  - what: "sertantai-compliance becomes the production SaaS, sertantai-legal becomes admin-only"
    why: "Customer-facing product IS compliance (screening, sync, change management). Legal is a data enrichment workbench. The naming fits and the compliance repo scaffold already exists."
    result: "Plan written with 5 migration phases, Gemini-reviewed and approved"
  - what: "Single production database owned by compliance, not two databases"
    why: "Two databases would require cross-database access, dual Electric instances, and FDWs. One database with legal pushing reference data via existing delta sync is simpler and eliminates all those concerns."
    result: "One Ecto repo, one Electric instance, no duplication, no sync reliability concerns"
  - what: "Compliance is the local-first alternative to Baserow for QQ"
    why: "QQ needs applicability screening built on secondary sources already being enriched. Compliance is tailored for local-first with ElectricSQL rather than depending on Baserow's API."
    result: "Compliance will serve QQ's applicability screener as first production use case"
  - what: "Plan YAML frontmatter schema: plan, status, created, completed, outcome, summary"
    why: "Plans are longer-lived than sessions — no decisions/lessons/metrics (those belong in implementation sessions). Frontmatter is for discovery: what is this, is it still relevant, what replaced it."
    result: "20 plans tagged, 8 archived (6 completed, 2 superseded), 12 active"

metrics:
  plans: { total: 20, active: 12, completed: 6, superseded: 2, archived: 8 }
  gemini_reviews: { round_1: "flash", round_2: "flash", concerns_resolved: 6 }

lessons:
  - title: "Single-database beats cross-database for same-instance services"
    detail: "Initial plan proposed two databases on the same PostgreSQL instance with cross-database read-only access. This introduced FDW/dual-Electric complexity for no benefit. One database with ownership conventions and existing delta sync is simpler and eliminates entire categories of problems."
    tag: infrastructure
  - title: "Gemini's Round 1 over-engineering is useful signal"
    detail: "Gemini flagged shared PostgreSQL as a 'distributed monolith' and recommended event-driven decoupling. This was premature for a 1-customer startup, but the concern correctly identified the two-database approach as unnecessarily complex. The fix was simplification (one DB), not more architecture (Kafka)."
    tag: tooling

artifacts:
  - .claude/plans/admin-prod-split.md
  - scripts/maintenance/add_plan_frontmatter.py
  - backend/data/code-reviews/2026-07-30-admin-prod-split-gemini-flash.md
  - backend/data/code-reviews/2026-07-30-admin-prod-split-gemini-flash-r2.md

depends_on:
  - 2026-07-30-sqlite-session-management.md

enables:
  - "Implementation of admin/compliance split (Phase 0-5)"
  - "QQ applicability screener built in sertantai-compliance"
---

# Session: Plans Housekeeping & Admin/Prod Split Research (CLOSED)

## Problem

The .claude/plans directory has 21 plan files with no YAML frontmatter, no status tracking, and no archival — the same problem sessions had before the SQLite migration. Separately, the codebase has grown to serve two distinct audiences (internal admin tooling vs production SaaS) and needs a split assessment.

## Todo

- ✅ Audit all 20 plan files — 12 active, 6 completed, 2 superseded
- ✅ Define YAML frontmatter schema for plans (plan, status, created, completed, outcome, summary)
- ✅ Add frontmatter to all 20 plan files
- ✅ Archive 8 completed/superseded plans to .claude/plans/archive/
- ✅ Research admin vs production app split — survey current codebase boundaries
- ✅ Document split options and trade-offs → .claude/plans/admin-prod-split.md

## Dependencies

- ✅ SQLite session management (2026-07-30-sqlite-session-management.md) — established the frontmatter + archive pattern
