---
session: "QQ-02: Tree Coverage for QQ Laws"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
---

# Session: QQ-02 Tree Coverage for QQ Laws (PENDING)

## Problem

74 in-force Making laws in QQ's register have no `compiled_applicability`, so the screener can't evaluate them. This is the biggest lever on evaluable agreement: at the current 84.5% match rate, trees for all 74 would add about 62 to `both` (68% → about 84%). QQ-01 will add about 45 more newly-Making laws without trees.

Trees are built by fractalaw, not legal. A law needs:
1. LAT in legal;
2. a fractalaw enrichment run, which is manual (`fractalaw sync publish --laws …`), and fractalaw only queues laws its own triage calls Making;
3. the tree arriving through TaxaSubscriber.

## Todo

- ⬜ **(a) 22 laws need LAT first**: build a LAT session (`lat-session-build` skill, `mix lat.create_session`) and parse. Run the `lat-qa` checks. Nine of the 22 are Merchant Shipping and Fishing Vessels H&S instruments.
- ⬜ **(b) 51 laws have LAT but no fitness enrichment**: included in the fractalaw brief (`.claude/plans/qq-fractalaw-brief.md`, T4) as one combined publish. Monitor TaxaSubscriber on `/admin/zenoh` (Received = Updated, Failed = 0).
- ⬜ **(c) 1 law has fitness but no tree**: `UK_ukpga_1990_9`, Planning (Listed Buildings and Conservation Areas) Act. It has 24,430 applies mentions. Find out why no tree was compiled (size limit? compile failure?) and report it to fractalaw.
- ⬜ Add the QQ-01 hand-off (confirmed Making, no tree) to (a) or (b) according to LAT status.
- ⬜ Before the batch: check whether fractalaw's triage agrees these are Making. If triage says not Making, fractalaw won't queue them, so they need `making_review` set (QQ-01) or a forced publish.
- ⬜ Time the (b) batch to run after QQ-03's fractalaw fixes, so it runs once. Lint the new trees (`mix fitness.lint_trees`).
- ⬜ Benchmark `legal-02-coverage` after each batch.
- ⬜ Record laws where fractalaw legitimately returns NULL (no fitness mentions) as an explained gap.
- ⬜ Wider corpus (loose, shape it after the QQ batch): 2,703 in-force Making laws have no tree. 2,444 of them have no LAT and 258 have LAT without fitness.
  - Next batch: the 258 with LAT, since they only need a fractalaw run.
  - After that, LAT parsing in the families where QQ has the most `register_only` laws: WASTE, OH&S, ENV PROTECTION, CLIMATE CHANGE, TRANSPORT.

## Dependencies

- ✅ Worklist `worklists/02-no-tree.csv` (74 rows, bucketed a/b/c)
- ⬜ QQ-01 hand-off list (adds to the queue, doesn't block starting (a) and (b))
- ⬜ Jason: fractalaw enrichment slot (QQ batch in week 1, wider-corpus batch in week 2)
- ⬜ QQ-03 fractalaw fixes (so the batch is not re-run)

## Worklist summary (2026-09-25)

| Bucket | Laws | Needs |
|---|---|---|
| a_needs_lat | 22 | LAT parse, then fractalaw |
| b_needs_enrichment | 51 | fractalaw run only |
| c_fitness_no_tree | 1 | compile investigation |

Needs LAT (a):
UK_anaw_2016_3, UK_asp_2003_2, UK_ssi_2007_80, UK_ukpga_2003_21, UK_ukpga_2006_49, UK_ukpga_2020_7, UK_uksi_1989_1796, UK_uksi_1997_2962, UK_uksi_2002_1587, UK_uksi_2006_2183, UK_uksi_2006_2184, UK_uksi_2007_3075, UK_uksi_2007_3077, UK_uksi_2010_330, UK_uksi_2010_332, UK_uksi_2015_962, UK_uksi_2016_1026, UK_uksi_2018_800, UK_uksi_2018_98, UK_wsi_2001_3545, UK_wsi_2009_2861, UK_wsi_2010_1821

Families with the most no-tree laws: OH&S Occupational (9), TRANSPORT Maritime (9), none (8), ENV PROTECTION (5), WASTE (5).

Some of these are "(Amendment)" instruments currently flagged Making, e.g. `UK_uksi_2018_98` (F-gas Amendment), `UK_wsi_2001_3545` and `UK_wsi_2009_2861`. Check them in passing. If they are really amending-only, they are Making false positives, and QQ-01's resolver should drop them rather than build trees.

## Exit criteria

Measured with `mix screener.benchmark … --label legal-02-coverage`, compared with `legal-baseline` and `legal-01-making`:
- `no_tree` for QQ register laws ≤ 5. Each remaining law has a reason (no fitness mentions, or awaiting fractalaw).
- Evaluable agreement ≥ 80%.
- No rise in `screener_only` that isn't explained (new trees can over-match; hand those to QQ-04).

## T4 result (2026-09-25)

- Trees for QQ register laws: `no_tree` 74 → 28 (benchmark `legal-t4`). 30 laws moved from no_tree to both, and `UK_ukpga_1990_9` now has a tree.
- The in-force Making corpus has 613 trees (was 546).
- Still outstanding: the provision-level publish for the new laws (the SLM is still running), and the 35 laws awaiting LAT.
- **Provision-level publish (after the position SLM), 2026-09-25:**
  - ProvisionSubscriber received 63 of 63 laws and 32,638 of 32,638 provisions, exactly matching fractalaw's log, with 0 errors and 0 warnings.
  - Against `t4_provision_snapshot_20260925`: 11,570 provisions changed, and provisions with DRRP classifications went from 8,406 to 19,805 across the 63 laws.
  - Throughput is about 30 provisions/s (one law at a time), so large Acts take minutes.
  - Not sent: `UK_ukpga_1933_13` and `UK_ukpga_1947_41`, which have no DRRP actors.
