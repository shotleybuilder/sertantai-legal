---
session: "QQ-01: QQ Making Triage"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25, 120]
depends_on: [qq-data-readiness/2026-09-25-qq-01a-making-transparency]
---

# Session: QQ-01 QQ Making Triage (PENDING)

## Problem

163 laws in QQ's register are never screened because `is_making` is false or null. `is_making` is decided through a funnel:
1. MakingDetector guesses (title, tier, signals).
2. Fractalaw triage estimates.
3. LAT is parsed.
4. Fractalaw enrichment confirms from the duties it finds.

The funnel is designed to minimise false positives, because parsing a whole law just to learn it has no duties is expensive.

QQ's register is a reference, not ground truth. It can easily contain laws without duties, such as amending instruments. For most of the 163, **the funnel has already given a verdict, and it's correct**: those laws are register cleanup findings for QQ. They are not changes to our DB.

The traceability problems found alongside this (untraced `is_making` writes, no `duty_type` provenance, stale session statuses, and 33 Duty/Responsibility laws with `is_making = false`) are fixed in [QQ-01a](./2026-09-25-qq-01a-making-transparency.md). This session is only the QQ triage.

## Funnel state of the 163 (from recorded data, 2026-09-25)

Source: `worklists/01-not-making.csv` (`funnel_state`, `next_action`). The states come from `lat_count`, `has_fitness`, `duty_type`, the LAT candidacy rule in `lat_session_manager.ex`, and the latest `scrape_session_records` row from a `lat_parse` session.

| State | Laws | Meaning | Next action |
|---|---|---|---|
| C1 fractalaw confirmed, LAT `cleaned` | 11 | BMS session 28 Jul: fractalaw said not Making, LAT deleted | QQ cleanup |
| X1 LAT deleted, status left `confirmed` | 17 | #120 shallow reparse: fractalaw confirmed no obligations, LAT deleted; 13 still carry a stale tree | QQ cleanup; set status to `cleaned` |
| F2 enriched, Rights/Powers only | 8 | Fractalaw found no Duty/Responsibility | QQ cleanup (spot-check, see the fractalaw brief) |
| S1 skipped in LAT session | 13 | Amending or commencement orders skipped by hand (BMS session) | QQ cleanup |
| Q2 not a LAT candidate, never parsed | 32 | `making_classification = not_making`; the funnel stopped them before LAT | QQ cleanup unless there's evidence to override |
| F1 enriched, duties found, `is_making = false` | 4 | Precedence bug | **Legal fix** |
| F3 enriched, tree built, no duty types | 37 | Fractalaw produced fitness and a tree but no DRRP | **Ask fractalaw** |
| L1 LAT parsed, never enriched | 14 | LAT exists; fractalaw never ran on it | **Fractalaw enrichment batch** |
| Q1 LAT candidate, never queued | 13 | The funnel says parse, but no LAT session was ever created | **LAT session** |
| P1 deferred in LAT session | 8 | Large out-of-scope Acts (Official Secrets, Bribery, Companies Act, EU Withdrawal…) | **Jason: parse or QQ cleanup** |
| X2 parsed, produced no LAT | 6 | 4 EU directives, Forestry (Felling of Trees) Regs, Compressed Acetylene Order | Investigate (no body text?) |

In total: **81 are QQ register cleanup on the funnel's own verdict** (C1 + X1 + F2 + S1 + Q2), 4 are a legal fix, 51 are waiting on fractalaw, 13 need LAT, 8 need your decision and 6 need investigating.

## Policy (Jason, 2026-09-25)

An amending instrument that inserts duties into a principal Act or SI is **not Making**. The duties belong to the principal instrument. QQ register entries for such instruments are register cleanup.

## Todo

- ⬜ Wait for QQ-01a (transparency and resolver backfill) so `is_making` is correct before triaging. The 4 F1 laws flip there.
- ⬜ Wait for fractalaw T1 (37 F3 laws: tree but no duty types) and T2 (8 F2 Rights/Powers-only spot-check) from `.claude/plans/qq-fractalaw-brief.md`. Re-derive states from the `making_funnel` view (QQ-01a).
- ⬜ Re-review the 5 laws held out of the QQ-01a backfill. Their earlier `making_review = 'making'` conflicts with fractalaw's T1/T2 text review. Under the policy above, expect `not_making`; record it with `mix making.review`:
  - `UK_uksi_2008_198`: inserts TA 1968 ss97C–G
  - `UK_uksi_2016_1245`: inserts CA 2006 s414CA–CB
  - `UK_uksi_2014_2868`: specifies limits for the RTA s5A offence
  - `UK_uksi_2018_24`: amends offence machinery
  - `UK_uksi_2005_1904`: amending instrument
- ⬜ Review the laws with `making_funnel.next_action = 'review_lat_deleted'`: 39 laws that are Making but had their LAT deleted by a not-Making clean-up. 23 are Making on a human review, mostly 2026 amending SIs, which the policy says aren't Making. Record each verdict with `mix making.review`.
- ⬜ Also check `UK_uksi_2018_1214`, the WEEE (Amendment) (No. 2) Regs: an amending SI made Making by legacy Duty/Responsibility in the QQ-01a backfill. Under the policy it may be not Making.
- ⬜ Fractalaw T1/T2 results (`~/fractalaw/data/qq-readiness/t1-no-duty-findings.csv`, `t2-rights-only-verdicts.csv`):
  - 33 of 37 F3 laws are correctly not Making, so they're QQ cleanup.
  - `UK_ssi_2012_148` and `UK_uksi_1998_3111` have Obligation rows in PG, so T4's republish should make them Making.
  - T2: `UK_ssi_2010_435` has a genuine duty (it becomes Making on republish). `UK_ssi_2005_22` is an amending SI, so it's not Making under the policy.
  - Under the amending-SI policy, fractalaw will exclude amendment instructions from its DRRP aggregation. So `UK_ssi_2012_148` (inserts EPA s34 duties) and `UK_ssi_2005_22` (inserts WML duties) become **not Making**. `UK_uksi_1998_3111` and `UK_ssi_2010_435` keep their own duties and stay Making.
  - Correction to the brief: `UK_uksi_2025_140` and `UK_uksi_2018_24` have no duties.
- ⬜ Q1 (13): create a LAT session (`lat-session-build`); the laws are already candidates by the DB rule. Then send them to fractalaw (brief T4, item 4).
- ⬜ P1 (8): Jason decides, per Act, between parsing it and QQ cleanup.
- ⬜ X2 (6): check whether legislation.gov.uk has body XML for them. If not, they're an explained gap.
- ⬜ QQ cleanup list: `backend/data/reports/qq/register-cleanup-not-making.csv` (the 81, plus whatever T1, T2, P1 and X2 add), with the funnel evidence for each law
- ⬜ Benchmark `legal-01-making`. Record it in the meta Results table and post on #161.

## Dependencies

- ✅ Worklist `worklists/01-not-making.csv` with `funnel_state` and `next_action`
- ✅ Baseline run `2026-09-25T1107-legal-baseline`
- ⬜ QQ-01a Making Pipeline Transparency (resolver backfill, `making_funnel` view)
- ⬜ Fractalaw T1/T2 answers (the fractalaw session is running)

## Exit criteria

- Every one of the 163 has a funnel state and next action. `not_making` in the benchmark contains only laws that are QQ cleanup or still waiting in the funnel.
- `legal-01-making`: `both` rises by the newly Making laws that match. Evaluable agreement may dip slightly as laws enter the corpus without trees. Report register recall alongside it.
