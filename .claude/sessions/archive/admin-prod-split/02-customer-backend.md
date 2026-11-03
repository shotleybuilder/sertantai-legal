---
session: Move Customer Backend
status: closed
opened: 2026-07-30
closed: 2026-07-30
outcome: success

summary: >
  Migrated 73 customer-facing Elixir files (~13K lines) from sertantai-legal to
  sertantai-compliance across 7 dependency-ordered packages. All cross-boundary deps
  resolved (Scraper.Models, ActorDictionary, Baserow.Client). Clean compilation with
  --warnings-as-errors. Git hooks activated. Legal untouched.

decisions:
  - what: "Copy-transform-load, not move — legal code stays untouched until Phase 4"
    why: "Allows rollback to legal at any point. Phase 4 (strip legal) is a separate session."
    result: "Both repos compile and run independently"
  - what: "Replace ActorDictionary with direct SQL queries on JSONB holder fields"
    why: "ActorDictionary is a Zenoh-dependent GenServer that compliance cannot access. DB query returns 113 actors (superset of the 92 curated labels)."
    result: "Filed #132 for proper refactor with persistent table"
  - what: "Extract FamilyLists from Scraper.Models"
    why: "Scraper.Models is admin-only code containing family name constants used by sync templates and Baserow provider. Pure data, no scraper logic."
    result: "SertantaiCompliance.Legal.FamilyLists — 48 EHS + 3 HR family names"
  - what: "Package migration in dependency order with compile checks between each"
    why: "73 files with deep dependency chains. Moving all at once risks hard-to-debug compilation failures."
    result: "7 packages, 7 commits, each compiles cleanly before proceeding"

metrics:
  files_migrated: { total: 73, enums: 12, resources: 10, templates: 30, controllers: 5, modules: 15, domain: 1 }
  lines_migrated: 13271
  packages: 7
  cross_boundary_fixes: { scraper_models: 2, actor_dictionary: 2, baserow_client: 1, oban_dep: 1, pubsub: 1 }
  warnings_fixed: 7

lessons:
  - title: "Dependency-ordered package migration prevents cascading compile failures"
    detail: "Moving 73 files at once would have produced dozens of undefined module errors. By ordering packages (enums first, controllers last) each package compiled cleanly against the previous ones. Only 3 cross-boundary issues surfaced, all fixable in isolation."
    tag: tooling
  - title: "Shared database eliminates most cross-service data access problems"
    detail: "The biggest feared risk was Engine/ProfileQuery reading legal tables. Since compliance shares sertantai_legal_dev, all raw SQL queries work unchanged — just the Repo module name changes. Zero query rewrites needed."
    tag: infrastructure
  - title: "ActorDictionary is the only Zenoh dependency in customer-facing code"
    detail: "Every other cross-boundary dep was pure data (family lists) or an HTTP client (Baserow.Client). ActorDictionary was the sole Zenoh-coupled module. Replacing it with a DB query was trivial but the curated vs raw label difference (92 vs 113) warrants a proper table (#132)."
    tag: data

artifacts:
  - backend/lib/sertantai_compliance/legal/family_lists.ex

depends_on:
  - 01-bootstrap.md

enables:
  - "Phase 3: Move customer frontend"
  - "Phase 4: Strip customer code from legal"
---

# Session: Move Customer Backend (CLOSED)

## Problem

Phase 2 of the admin/prod split: move all customer-facing Elixir code from sertantai-legal to sertantai-compliance. This is the largest phase (~30 files) with deep dependency chains. Need to identify natural "packages" that can move independently with compilation checks between each.

## Todo

- ✅ Dependency analysis — 7 packages identified, ordered by dependency depth
- ✅ Pkg 1: Sync domain + enums + org resources (12 enums, 10 resources, 1 domain — 23 files, compiles clean, reads live data)
- ✅ Pkg 2: Change detection (ChangeNotifier, ChangeDetector — 2 files, ApplicabilityEvent already in Pkg 1)
- ✅ Pkg 3: Fitness (EntityIndex, ApplicabilityEvaluator — 2 files, 1395 entities indexed)
- ✅ Pkg 4: Templates + webhook controllers (30 template files, 2 controllers, 1 FamilyLists extract — Scraper.Models dep replaced)
- ✅ Pkg 5: Sync engine (Engine, ProfileQuery, Credentials, Providers.Baserow, Baserow.Client, Workers, ActorTupleSync, FieldTiers, ProviderBehaviour — 10 files. Scraper.Models→FamilyLists, ActorDictionary→DB query)
- ✅ Pkg 6: ElectricSQL proxy (1 file, zero deps)
- ✅ Pkg 7: Screening + Sync controllers (2 files, ActorDictionary→DB query, see #132)
- ✅ Clean compilation (--warnings-as-errors passes)
- ✅ Git hooks (pre-commit + pre-push) copied from legal and activated

## Package Dependency Map

```
Pkg 6 (Electric proxy) ──── independent, move anytime
Pkg 1 (enums + resources) ── foundation, move first
  ↓
Pkg 2 (change detection) ── reads org tables from Pkg 1
Pkg 3 (fitness) ──────────── reads legal_register (read-only resource exists)
  ↓
Pkg 4 (templates) ────────── uses Pkg 1 resources + Providers.Baserow
  ↓
Pkg 5 (sync engine) ──────── uses Pkg 1-4 + reads legal data (read-only resources exist)
  ↓
Pkg 7 (screening ctrl) ──── uses Pkg 1+2+3+5
```

Cross-boundary deps to legal data (Control, LegalRegister, LegalArticle, etc.) are
resolved — compliance already has read-only Ash resources for all reference tables.
Raw SQL queries in Engine/ProfileQuery/EntityIndex need updating to use compliance's Repo.

## Dependencies

- ✅ Bootstrap compliance repo: admin-prod-split/01-bootstrap.md
