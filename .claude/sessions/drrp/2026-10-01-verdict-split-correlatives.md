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
- ✅ Found while waiting: the JSON `lrt/*` queryable raised KeyError `:leg_gov_uk_url` (LegalRegister holds `source_url`; latent since the switch from UkLrt, first hit by fractalaw today). Fixed ce5ff234 with tests; restarted again (no publish in flight, heads-up sent)
- ℹ️ fractalaw 33f307a: R1a built. The publish is waiting on Jason's review of the dry run.
  - Dry run over 745 hub laws: current_verdict = revoked for 6 laws that are making as made (UK_ukpga_1994_21, UK_uksi_1999_1676, 2003_751, 2005_1726, 2010_768, 2013_1119). All 6 are wholly revoked in legal's `live` and is_making = true in legal, so this is consistent.
  - Otherwise the current view equals as made.
  - #72 correlatives come in a later fractalaw step (priority 2), unsent (null = keep) until then.
  - The 3 lrt/* not_found replies were fractalaw's wildcard probe, not a legal bug.
- ⬜ Verify arrival after fractalaw's first R1a/#72 publish (as of 19:01 nothing published: 0 rows with current_verdict / correlative holders, 0 provisions with actors[].correlatives)

## For Jason

- Should compliance screening move from `is_making` (as made) to `current_verdict`? Not decided; nothing reads it yet.
- **Existing prod-sync risk:** recent legal columns (`lat_scope`, `live_evidence`, `making_*`) aren't in compliance prod's schema and aren't listed as dev-only in `Sync.Delta.Config`. The next `mix data.export_delta` may fail on them or carry them into an apply that rejects them. Worth checking before the next prod sync.

## Compliance's answers (sertantai-compliance, 2026-10-01)

- **Delta sync:** compliance never migrates legal's tables. Legal's prod migration (#133) brings prod up to dev, and compliance tolerates extra columns because it uses explicit column lists.
  - Done: the 19 legal_register columns missing from the uk_lrt view are now dev-only in `Sync.Delta.Config`.
  - Also found and fixed: `country`/`jurisdiction` were exported though the view triggers set them. They're now never written.
  - New guard: `test/sertantai_legal/sync/delta/config_test.exs` checks that every exported column exists in the dev uk_lrt view.
  - Unmark a family once #133 lands and compliance asks for it.
  - **Time-sensitive:** if #163 ships before compliance's 20 Oct freeze, `application_regions` must reach prod with the deploy. Tell compliance before leaving it dev-only past #133.
- **current_verdict:** it doesn't block legal. Compliance raised compliance#37 (v0.2): screen on current_verdict and the current_* holders, add "my rights / what protects me" from the correlatives, and benchmark before and after. Compliance will ask legal to unmark those columns before that release.
