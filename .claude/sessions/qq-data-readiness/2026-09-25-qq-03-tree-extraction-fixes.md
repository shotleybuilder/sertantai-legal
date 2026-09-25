---
session: "QQ-03: Tree Extraction Fixes (fractalaw) & Tree Lint"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
---

# Session: QQ-03 Tree Extraction Fixes (fractalaw) & Tree Lint (PENDING)

## Problem

34 QQ register laws have trees but miss because of how the tree is written, not because of QQ's profile:
- `generic_code_gate` 21
- `construction_misfire` 8
- `gov_actor_gate` 5

A further 45 screener-only laws are included only with a caveat a reviewer has to dismiss:
- `soft_disapplication` 34
- `time_window_caveat` 11

Corpus-wide over the 546 trees:
- 50 have expired TimeWindows.
- 315 contain `Not`.
- 251 use `construction`, 52 of them inside a `Not`.
- 230 use government-actor codes.
- 4 disapply their own jurisdiction.
- Duplicate sibling nodes are common.

## Decision (Jason, 2026-09-25)

Fix extraction **at source in fractalaw**. Legal keeps storing trees unchanged; it doesn't add a legal-side normaliser. Legal's part:
1. Precise source-fix specs with example laws and expected trees.
2. A read-only tree lint to measure each defect before and after.
3. A snapshot of trees before re-enrichment, and a check afterwards.

## Todo

- ⬜ `mix fitness.lint_trees`: a read-only lint over in-force Making trees. Pure checks with `@spec`, and TDD with hand-built trees. It counts and lists each defect:
  - L1 duplicate siblings
  - L2 TimeWindow `to` in the past, or `to` < `from`
  - L3 Not on the law's own jurisdiction
  - L4 `construction` beside `interpretation`, or inside a Not
  - L5 government-actor codes in gating And-branches
  - L6 generic codes gating
  - L7 no jurisdiction gate (shared with QQ-04)
  - L8 territory-only tree

  Baseline counts from 2026-09-25 go in the table below.
- ⬜ Source-fix specs for fractalaw, one per defect L1–L8, in `docs/fitness/FRACTALAW-TREE-FIXES.md`. Each has the defect, why it's wrong, 2–3 example laws with the current tree fragment, and the expected tree. Point for L4: `construction` as a section-heading sense ("Interpretation and construction") should never become a material code.
- ⬜ L6 (generic codes): agree with compliance first whether they become implied org facts (compliance evaluator) or stop gating (fractalaw). The metric effect is the same; the owner differs.
- ⬜ Hand the specs to Jason for fractalaw. Agree the order: fixes by about 6 Oct, then one combined re-enrichment of all 546 trees plus QQ-02's batch.
- ⬜ Before re-enrichment: snapshot `compiled_applicability` (copy table `compiled_applicability_snapshot_20261006`, or a NAS backup).
- ⬜ After re-enrichment: lint again; benchmark `legal-03-fractalaw-fixes`; diff trees for laws that moved from `both` to anything else.
- ⬜ Update `docs/fitness/FITNESS-APPLICABILITY.md`: fix the stale evaluator reference (it's in compliance now) and link the lint.
- ⬜ Fallback if fractalaw fixes slip past about 10 Oct: record which defects remain and hand them to compliance to soft-handle for v0.1.

## Dependencies

- ✅ Decision: fractalaw source fixes
- ⬜ Jason: fractalaw implementation and re-enrichment slot
- ⬜ Compliance: agreement on L6 ownership
- ✅ Worklists: `worklists/04-tree-gate-misses.csv`, `worklists/03-screener-only.csv`

## Lint baseline (2026-09-25, 546 in-force Making trees, ad-hoc SQL)

| Defect | Trees |
|---|---|
| Expired TimeWindow (L2) | 50 |
| Contains Not | 315 |
| Not on own jurisdiction (L3) | 4 |
| Uses `construction` / inside Not (L4) | 251 / 52 |
| Government-actor codes (L5) | 230 |
| Territory-only, no non-territorial positive match (L8) | 48 |
| Devolved law without own-jurisdiction gate (L7) | 26 (with current `geo_extent`, which is itself wrong for 481 laws) |

## Per-law lists (from `legal-baseline`)

- **generic_code_gate (21)**: UK_asc_2023_3, UK_asp_2003_1, UK_eudr_1989_391, UK_eudr_2006_126, UK_eudr_2011_92, UK_eudr_2012_27, UK_eur_2008_304, UK_mwa_2010_8, UK_ssi_2004_428, UK_ssi_2009_140, UK_ssi_2016_146, UK_ssi_2016_93, UK_uksi_1971_161, UK_uksi_1999_1006, UK_uksi_1999_1774, UK_uksi_1999_916, UK_uksi_2008_2852, UK_uksi_2009_3344, UK_uksi_2012_2782, UK_uksi_2015_168, UK_wsi_2012_1903
- **construction_misfire (8)**: UK_eudr_1994_63, UK_eudr_2008_68, UK_uksi_1979_628, UK_uksi_1999_1148, UK_uksi_2008_2694, UK_uksi_2012_1657, UK_uksi_2015_51, UK_uksi_2020_1444
- **gov_actor_gate (5)**: UK_asp_2005_13, UK_asp_2021_4, UK_uksi_1992_2225, UK_uksi_2014_1643, UK_uksi_2019_421
- **time_window_caveat (11)**: UK_nisr_2009_273, UK_nisr_2015_279, UK_ukpga_1986_44, UK_ukpga_1989_29, UK_ukpga_2016_22, UK_uksi_2009_995, UK_uksi_2012_2999, UK_uksi_2014_3125, UK_uksi_2015_1947, UK_uksi_2017_544, UK_wsi_2026_103
- **soft_disapplication (34)**: see `03-screener-only.csv`.
  - The most frequent triggering QQ facts are `construction_work` 8, `vehicle` 7, `explosives` 6, `worker` 5, `substances` 3 and `operator` 3.
  - Most are scope exclusions compiled as whole-law negation. Ask fractalaw to scope those to provisions rather than negating the whole law.
- Example trees for the specs: `UK_asp_2021_4` (Not `scotland`, duplicates, `construction`) and `UK_anaw_2017_2` (TimeWindow `to` 2017-04-15, `construction` inside Not).

## Exit criteria

Measured with `mix screener.benchmark … --label legal-03-fractalaw-fixes` and `mix fitness.lint_trees`:
- `generic_code_gate` + `construction_misfire` + `gov_actor_gate`: 34 → ≤ 8
- `time_window_caveat`: 11 → 0; lint L2 50 → 0; L3 4 → 0
- `soft_disapplication`: 34 → ≤ 15
- `both` does not fall; every law that leaves `both` is explained
