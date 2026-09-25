---
session: "QQ-01: Making Triage & is_making Precedence"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25]
---

# Session: QQ-01 Making Triage & is_making Precedence (PENDING)

## Problem

163 laws in QQ's register are never screened, because legal has `is_making = false` (or null) for them. This is the largest single cause in the benchmark. Some are legal misclassifications (fix here, #25). Others are amending or procedural instruments that QQ keeps in its register (a cleanup finding for QQ, not a legal fix).

There is also a code bug:
- `is_making` has four writers:
  - TriageSubscriber sets it from `making_classification`.
  - TaxaSubscriber overwrites it from `duty_type`.
  - The staged parser decides locally.
  - MakingDetector writes only the provenance fields.
- The human `making_review` verdict never wins.
- As a result, 14 of the 163 carry a `making` classification or review but have `is_making = false`.

## Todo

- ⬜ Fix precedence: one resolver for `is_making`, with `making_review` > taxa-derived `duty_type` > triage `making_classification` > MakingDetector. TDD on a pure module; TaxaSubscriber and TriageSubscriber call it rather than setting `is_making` themselves.
- ⬜ Backfill `is_making` corpus-wide through the resolver. Report how many laws flip each way; laws outside QQ's register will flip too.
- ⬜ Resolve the 14 laws with a `making` signal (list below) through the resolver, then check each by eye.
- ⬜ Review the 83 `principal_candidate` + 6 `eu_directive_or_decision` rows in `worklists/01-not-making.csv`:
  - Set `making_review` to `making`, `not_making` or `empowering`.
  - Fill the `verdict` column with `legal_fix` or `register_cleanup:<reason>`.
- ⬜ Quick check of the 74 `procedural_by_title` rows. Default is `register_cleanup:procedural`. Flag any substantive "(Amendment)" instruments (#25: about 17% of amending titles are Making).
- ⬜ Run MakingDetector on the 43 rows with no `making_classification` (`mix legal.backfill_making_provenance` scoped to these names).
- ⬜ Benchmark `legal-01-making`. Record the results in the meta Results table and post on #161.
- ⬜ Hand to QQ-02: the confirmed-Making laws with no tree (expected about 45) join its queue.
- ⬜ Write the register-cleanup list for QQ: `backend/data/reports/qq/register-cleanup-not-making.csv` with law, title and reason. It's a finding for QQ, not something to change in their register.

## Dependencies

- ✅ Worklist `worklists/01-not-making.csv` (163 rows, bucketed by title heuristic)
- ✅ Baseline run `2026-09-25T1107-legal-baseline`
- ⬜ None blocking. Can start Mon 29 Sep.

## Worklist summary (2026-09-25)

| Bucket | Laws | Already have tree | Have LAT |
|---|---|---|---|
| principal_candidate | 83 | 38 | 41 |
| procedural_by_title | 74 | 24 | 22 |
| eu_directive_or_decision | 6 | 0 | 0 |

`making_classification` breakdown: `not_making` 87, null 43, `uncertain` 24, `making` 9.

Laws with a `making` signal but `is_making = false` (precedence bug):

| Law | Title | classification / review | Tree |
|---|---|---|---|
| UK_ssi_2005_22 | Waste (Scotland) Regulations | making / — | ✓ |
| UK_ssi_2010_435 | Waste Information (Scotland) Regulations | making / — | ✓ |
| UK_ukpga_1990_18 | Computer Misuse Act | making / — | |
| UK_ukpga_2019_17 | Offensive Weapons Act | making / — | |
| UK_ukpga_2023_55 | Levelling-up and Regeneration Act | making / — | ✓ |
| UK_uksi_2005_1904 | Passenger and Goods Vehicles (Recording Equipment) Regs | uncertain / making | ✓ |
| UK_uksi_2006_2950 | Merchant Shipping (Prevention of Pollution by Sewage and Garbage) Order | making / — | ✓ |
| UK_uksi_2006_3368 | Smoke-free (Premises and Enforcement) Regulations | making / — | ✓ |
| UK_uksi_2008_198 | Passenger and Goods Vehicles (Recording Equipment) (Downloading…) Regs | uncertain / making | ✓ |
| UK_uksi_2014_2868 | Drug Driving (Specified Limits) (E&W) Regulations | not_making / making | ✓ |
| UK_uksi_2016_1245 | Companies, Partnerships and Groups (Accounts and Non-Financial Reporting) Regs | not_making / making | ✓ |
| UK_uksi_2017_1177 | Environmental Damage (Prevention and Remediation) (England) (Amendment) Regs | making / — | ✓ |
| UK_uksi_2018_24 | Community Drivers' Hours Offences (Enforcement) Regulations | uncertain / making | ✓ |
| UK_uksi_2021_746 | Town and Country Planning (Development Management Procedure…) | making / — | ✓ |

## Exit criteria

Measured with `mix screener.benchmark … --label legal-01-making`, compared with `legal-baseline`:
- Every one of the 163 laws has a verdict in the worklist.
- `not_making` contains only laws with a `register_cleanup` verdict.
- `both` rises (expected +25–35).
- **Evaluable agreement is expected to fall** (about 68% → 63%), because newly Making laws without trees enter the denominator as `no_tree`. Report it, and report register recall excluding revoked and cleanup laws alongside it. Warn compliance on #161 so it doesn't retune against the dip.

## Notes

- The Making definition (from #25): a law is Making if it creates Duties or Responsibilities. A law with only Powers or Rights is "Empowering", not Making. Some of QQ's register laws will turn out to be Empowering. Those are register cleanup too.
- The LAT parse queue (`lat_session_manager.ex`) reads `making_review` first, so reviews set here feed QQ-02's LAT sessions directly.
