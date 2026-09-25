---
session: "QQ-04: Jurisdiction & Territory Over-match"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
---

# Session: QQ-04 Jurisdiction & Territory Over-match (PENDING)

## Problem

172 laws match QQ that aren't in its register.
- **40 are Northern Ireland laws**, and QQ operates only in England, Scotland and Wales:
  - 23 are `register_gap_or_overmatch`, 11 `soft_disapplication`, 3 `territory_branch_match`, 2 `time_window_caveat` and 1 `territory_only_tree`.
  - 28 of the 40 mention `northern_ireland`, but only 4 use it as a root-level gate:
    - Those 4 also list `united_kingdom` in the same Match, which a GB org satisfies through the territorial hierarchy.
    - The other 24 nest it inside Or branches next to place types such as `premises` and `workplace`, so any GB org with premises matches.
  - 12 have no jurisdiction code at all.
- Separately, 16 trees are territory-only and 38 match on a territory-only OR branch.

`geo_extent` can't be used as a gate yet. It says `UK` for 481 devolved in-force Making laws: nisr 192, ssi 195, wsi 94. Another ~150 have null extent.

These fixes don't move evaluable agreement, because screener-only laws aren't in it. They cut what a QQ reviewer has to read and dismiss.

## Todo (loose; rewrite on resume)

- ⬜ Fix `geo_extent` for devolved types from legislation.gov.uk extent metadata. Lint type_code against extent afterwards.
- ⬜ Jurisdiction gate (lint L7): spec for fractalaw to AND the law's extent (from the corrected `geo_extent`/`geo_region`) at the tree root, with place types in their own branch. Fix `geo_extent` first. Check whether fractalaw reads it from the LRT queryable or works out extent itself.
  - Alternative: compliance treats `geo_extent` as a categorical exclusion. Agree the owner with compliance.
- ⬜ Territory-only trees (16) and territory branches (38): decide per law whether they are genuinely universal (e.g. offshore first-aid applies to every offshore employer) or have lost a condition during extraction. Send lost-condition cases to fractalaw.
- ⬜ Settle the question from #161: are place types (`premises`, `ship`, `installation`) under `territorial` intentional, or should they move to a `locational` dimension? This is shared with QQ-05.
- ⬜ Benchmark `legal-04-jurisdiction`

## Dependencies

- ⬜ QQ-03 lint (L7, L8) and the fractalaw re-enrichment slot
- ✅ Worklist `worklists/03-screener-only.csv` (`ni_law` flag, cause buckets)

## Exit criteria

Measured with `legal-04-jurisdiction`, compared with the previous run:
- NI laws in QQ's `screener_only`: 40 → 0.
- `territory_only_tree` + `territory_branch_match`: 54 → ≤ 20, with every remaining law judged "genuinely universal".
- `both` doesn't fall.
- Devolved `geo_extent` mislabels: 481 → 0.
