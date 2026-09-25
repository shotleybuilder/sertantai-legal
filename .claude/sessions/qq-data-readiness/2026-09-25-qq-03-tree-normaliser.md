---
session: "QQ-03: Tree Normaliser & Gate Fixes"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
---

# Session: QQ-03 Tree Normaliser & Gate Fixes (PENDING)

## Problem

34 QQ register laws have trees but miss because of how the tree is written, not because of QQ's profile:
- `generic_code_gate` 21
- `construction_misfire` 8
- `gov_actor_gate` 5

A further 45 screener-only laws are included only with a caveat a reviewer has to dismiss:
- `soft_disapplication` 34
- `time_window_caveat` 11

Corpus-wide lint over the 546 trees:
- 50 have expired TimeWindows.
- 315 contain `Not`.
- 251 use `construction`, 52 of them inside a `Not`.
- 230 use government-actor codes.
- 4 disapply their own jurisdiction.
- Duplicate sibling nodes are common.

Legal stores fractalaw's trees exactly as received. Fixing them at source means fractalaw changes plus full re-enrichment, which is hard to fit in before 17 Oct.

## Proposed approach (needs Jason's decision, see meta)

- Add a **legal-side deterministic tree normaliser**: a pure module with one flag per rule.
  - Keep the raw tree in a new `compiled_applicability_raw` column. `compiled_applicability` becomes the normalised tree, which is the column compliance reads.
  - Run it in TaxaSubscriber on ingest and as a backfill mix task.
- Log every rule as a source-fix request for fractalaw, so rules can be retired as fractalaw improves.
- Follow CLAUDE.md: TDD on the pure module, `@spec`/`@moduledoc`, and a Gemini review of the design before implementation.

## Todo

- ⬜ Decision recorded: normaliser vs fractalaw source fix (meta todo)
- ⬜ Gemini review of the normaliser design, saved to `backend/data/code-reviews/`
- ⬜ Migration: add `compiled_applicability_raw` (jsonb). Follow the `db-schema-changes` skill: `uk_lrt` view plus INSTEAD OF triggers.
- ⬜ `Fitness.TreeNormaliser` (pure, TDD) with rules, each benchmarked on its own:
  - ⬜ R1 dedupe identical siblings; flatten single-child And/Or
  - ⬜ R2 TimeWindow: drop `to` when `to` < today and `live` says in force; drop windows with `to` < `from`
  - ⬜ R3 Not: drop territorial codes equal to or containing the law's own extent (e.g. `scotland` in the Continuity (Scotland) Act)
  - ⬜ R4 `construction`, statutory-interpretation sense: check whether fitness mentions carry a provision ref. If they do, drop mentions from interpretation or construction provisions. If not, fall back to dropping `construction` when it sits in an Or or Not beside `interpretation`.
  - ⬜ R5 government-actor codes (`secretary_of_state`, `local_authority`, `scottish_ministers`, `welsh_ministers`, `enforcement_authority`, `public_authority`): remove them from gating And-branches, and keep them in Or-branches only when a governed actor is a sibling
  - ⬜ R6 generic codes (`building`, `land`, `licence`, `body_corporate`, `person`, `offence`, `application`): **agree with compliance first** whether they become implied org facts (compliance evaluator) or stop gating (normaliser). The effect on the metric is the same, but the owner differs.
- ⬜ Backfill task `mix fitness.normalise_trees [--rules …] [--dry-run]` reporting how many trees each rule changes
- ⬜ Benchmark one run per rule (`legal-03-r1` … `legal-03-r6`), then all rules together as `legal-03-normalised`
- ⬜ Write fractalaw source-fix requests, one per rule, with example laws
- ⬜ Update `docs/fitness/FITNESS-APPLICABILITY.md`: add the normaliser, fix the stale evaluator reference, and document the raw/normalised columns for compliance

## Dependencies

- ⬜ Jason: normaliser vs source-fix decision
- ⬜ Compliance: agreement on R6 ownership
- ✅ Worklists: `worklists/04-tree-gate-misses.csv`, `worklists/03-screener-only.csv`

## Per-law lists (from `legal-baseline`)

- **generic_code_gate (21)**: UK_asc_2023_3, UK_asp_2003_1, UK_eudr_1989_391, UK_eudr_2006_126, UK_eudr_2011_92, UK_eudr_2012_27, UK_eur_2008_304, UK_mwa_2010_8, UK_ssi_2004_428, UK_ssi_2009_140, UK_ssi_2016_146, UK_ssi_2016_93, UK_uksi_1971_161, UK_uksi_1999_1006, UK_uksi_1999_1774, UK_uksi_1999_916, UK_uksi_2008_2852, UK_uksi_2009_3344, UK_uksi_2012_2782, UK_uksi_2015_168, UK_wsi_2012_1903
- **construction_misfire (8)**: UK_eudr_1994_63, UK_eudr_2008_68, UK_uksi_1979_628, UK_uksi_1999_1148, UK_uksi_2008_2694, UK_uksi_2012_1657, UK_uksi_2015_51, UK_uksi_2020_1444
- **gov_actor_gate (5)**: UK_asp_2005_13, UK_asp_2021_4, UK_uksi_1992_2225, UK_uksi_2014_1643, UK_uksi_2019_421
- **time_window_caveat (11)**: UK_nisr_2009_273, UK_nisr_2015_279, UK_ukpga_1986_44, UK_ukpga_1989_29, UK_ukpga_2016_22, UK_uksi_2009_995, UK_uksi_2012_2999, UK_uksi_2014_3125, UK_uksi_2015_1947, UK_uksi_2017_544, UK_wsi_2026_103
- **soft_disapplication (34)**: see `03-screener-only.csv`. The most frequent triggering QQ facts are `construction_work` 8, `vehicle` 7, `explosives` 6, `worker` 5, `substances` 3 and `operator` 3. Most are scope exclusions compiled as whole-law negation. R3 and R4 remove the clearly wrong ones. The rest are real scope caveats that compliance already handles.

## Exit criteria

Measured with `mix screener.benchmark … --label legal-03-normalised`, compared with the previous `legal-*` run:
- `generic_code_gate` + `construction_misfire` + `gov_actor_gate`: 34 → ≤ 8
- `time_window_caveat`: 11 → 0
- `soft_disapplication`: 34 → ≤ 15, with no own-jurisdiction disapplications left
- `both` does not fall; any `screener_only` rise is itemised
- The raw tree is kept for every law, and each rule can be switched off
