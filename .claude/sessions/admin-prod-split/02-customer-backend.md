---
session: Move Customer Backend
status: active
opened: 2026-07-30
---

# Session: Move Customer Backend (ACTIVE)

## Problem

Phase 2 of the admin/prod split: move all customer-facing Elixir code from sertantai-legal to sertantai-compliance. This is the largest phase (~30 files) with deep dependency chains. Need to identify natural "packages" that can move independently with compilation checks between each.

## Todo

- ✅ Dependency analysis — 7 packages identified, ordered by dependency depth
- ⬜ Pkg 1: Sync domain + enums + org resources (12 enums, 10 resources, 1 domain module)
- ⬜ Pkg 2: Change detection (ApplicabilityEvent, ChangeNotifier, ChangeDetector)
- ⬜ Pkg 3: Fitness (EntityIndex, ApplicabilityEvaluator)
- ⬜ Pkg 4: Templates + webhook controllers (29 template files, 2 controllers)
- ⬜ Pkg 5: Sync engine (Engine, ProfileQuery, Credentials, Providers, Workers, SyncController)
- ⬜ Pkg 6: ElectricSQL proxy (zero deps, move anytime)
- ⬜ Pkg 7: Screening controller (depends on 1+2+3+5)

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
