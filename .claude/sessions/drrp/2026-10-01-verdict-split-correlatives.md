---
session: "Verdict split (current view) + correlative holder lists — legal build"
status: active
opened: 2026-10-01
related: ["fractalatai#73", "fractalatai#72"]
depends_on: ["drrp/2026-09-30-drrp-temporal", "drrp/2026-09-30-issue-72-correlatives"]
---

# Session: Verdict split + correlatives, legal build (ACTIVE)

Jason, 2026-10-01: "start the verdict split and #72 build" — one bundle (a conceptual "release": one migration, one restart, one heads-up). Spec: fractalaw DRRP-TEMPORAL-PROPOSAL R1a (6591492) and DRRP-CLASSIFICATION layer 1b (a26ec52). Legal's review of R1a: see `drrp/2026-09-30-drrp-temporal`.

## Problem

fractalaw will publish a current (as amended) view beside the as-made DRRP fields, and #72's correlative holder lists. Legal must store them without touching the as-made fields or is_making.

## Todo

- ✅ Migration 20261001183411 on `legal_register`: the 9 columns (`current_verdict` text with a check constraint; the rest jsonb `{values: [...]}`). **Not added to the `uk_lrt` view** (same as `lat_scope`): LegalRegister maps the table directly and compliance doesn't read these yet, so the view/trigger rebuild isn't needed. Ash attrs + accept lists on LegalRegister
- ✅ TaxaSubscriber: maps the 9 fields; never-cross-assign filter on `current_*` holders, none on correlatives; `[]` clears; `current_verdict` stored as sent (unknown value dropped and logged); `classify_enrichment` / `is_making` ignore all of them
- ✅ ProvisionSubscriber: `actors[].correlatives` pass through (actor maps are stored whole); `correlative_violations/1` checks position vs type (counterparty → claim_right/liability/no_right, beneficiary → protected, mentioned → none, active → none unless #67 `reason: inferred` → claim_right only); logged per law, never dropped
- ✅ Tests: `taxa_current_view_test.exs` (5), `provision_correlatives_test.exs` (7, from the layer-1b worked examples: HSWA s.2(1), s.3(1), Water Act s.82(2)(c), EPA s.20(7)); full suite 2107 passed
- ✅ Delta sync: the 9 columns are dev-only in `Sync.Delta.Config` (compliance prod lacks them)
- ✅ Docs: `docs/zenoh/ZENOH-SPEC.md` law + provision records
- ✅ Restart (no publish in flight; heads-up sent), confirmed to fractalaw 2026-10-01
- ⬜ Verify arrival after fractalaw's first R1a/#72 publish

## For Jason

- Should compliance screening move from `is_making` (as made) to `current_verdict`? Not decided; nothing reads it yet.
- **Existing prod-sync risk:** recent legal columns (`lat_scope`, `live_evidence`, `making_*`) aren't in compliance prod's schema and aren't listed as dev-only in `Sync.Delta.Config`. The next `mix data.export_delta` may fail on them or carry them into an apply that rejects them. Worth checking before the next prod sync.
