---
session: "QQ-01: Making Funnel — QQ Triage, Precedence & Traceability"
status: pending
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25, 120]

bugs:
  - pattern: "is_making changes are never recorded in record_change_log (0 entries corpus-wide); Triage/TaxaSubscriber writes bypass the change log"
    category: making-traceability
    module: zenoh/triage_subscriber.ex, zenoh/taxa_subscriber.ex
    affected: 19817
    fix: "Log every is_making / making_* / duty_type write with source (detector, triage, taxa, review, scraper) and reason"
    status: open
  - pattern: "In-force laws with Duty/Responsibility in duty_type but is_making = false"
    category: making-precedence
    module: is_making writers (staged_parser, taxa_subscriber, triage_subscriber)
    affected: 33
    fix: "Single resolver; duty_type Duty/Responsibility ⇒ is_making true unless making_review says otherwise; 21 of 33 last touched by the 12 Aug reparse"
    status: open
  - pattern: "LAT session records left at 'confirmed' after fractalaw-confirmed not-Making LAT was deleted (pre-dates the 'cleaned' status)"
    category: lat-session-status
    module: scrape_session_records (lat-reparse-shallow-2026-07-13)
    affected: 17
    fix: "Backfill status to 'cleaned' where lat_inserted > 0 and the law now has no LAT"
    status: open
  - pattern: "duty_type has no provenance: cannot tell fractalaw enrichment from legacy regex/Airtable values"
    category: making-traceability
    module: legal_register.duty_type
    fix: "Record duty_type source and timestamp alongside the value"
    status: open
---

# Session: QQ-01 Making Funnel — QQ Triage, Precedence & Traceability (PENDING)

## Problem

163 laws in QQ's register are never screened because `is_making` is false or null. `is_making` is decided through a funnel:
1. MakingDetector guesses (title, tier, signals).
2. Fractalaw triage estimates.
3. LAT is parsed.
4. Fractalaw enrichment confirms from the duties it finds.

The funnel is designed to minimise false positives, because parsing a whole law just to learn it has no duties is expensive.

QQ's register is a reference, not ground truth. It can easily contain laws without duties, such as amending instruments. For most of the 163, **the funnel has already given a verdict, and it's correct**: those laws are register cleanup findings for QQ. They are not changes to our DB.

The real problem is **traceability**. The funnel records a lot, but the final `is_making` write can't be traced:
- `record_change_log` has **0** entries for `is_making` across the whole corpus. Only the scraper and legacy import write to it; Triage and TaxaSubscriber don't.
- `duty_type` has no provenance, so a fractalaw result can't be told apart from a legacy regex or Airtable value.
- 17 LAT session records still say `confirmed` although fractalaw confirmed the laws not Making and their LAT was deleted in #120. This happened before the `cleaned` status existed.
- 33 in-force laws have Duty/Responsibility in `duty_type` but `is_making = false`. 21 of them were last touched by the 12 Aug reparse.

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

## Todo

- ⬜ **Traceability first** (TDD, pure module plus thin writers). Every write to `is_making`, `making_*` or `duty_type` appends a `record_change_log` entry with a `source` (`detector` | `triage` | `taxa` | `review` | `scraper`) and a reason.
- ⬜ **One precedence resolver** for `is_making`, applied by every writer:
  - `making_review` (human) comes first;
  - then fractalaw enrichment (`duty_type` has Duty/Responsibility means Making; Rights/Powers only means Empowering, not Making);
  - then triage;
  - then the detector.

  This matches #120's "taxa wins by design", but in one place.
- ⬜ Record `duty_type` provenance (source and timestamp), so fractalaw results can be told apart from legacy values.
- ⬜ Backfill `is_making` through the resolver corpus-wide:
  - Report every flip with its source.
  - Expect the 33 Duty/Responsibility laws to become true, including the 4 F1 QQ laws.
  - Check the 12 Aug reparse path (`staged_parser.ex` taxa/LAT substage) for the overwrite.
- ⬜ Backfill `scrape_session_records.status = 'cleaned'` for the 17 X1 records. Decide whether stale trees on confirmed not-Making laws should be cleared (13 laws).
- ⬜ Q1 (13): create a LAT session (`lat-session-build`); the laws are already candidates by the DB rule. Then send them to fractalaw with the brief's batch.
- ⬜ P1 (8): Jason decides, per Act, between parsing it and QQ cleanup.
- ⬜ X2 (6): check whether legislation.gov.uk has body XML for them. If not, they're an explained gap.
- ⬜ Fractalaw hand-off: `.claude/plans/qq-fractalaw-brief.md` (F3 question, L1 and QQ-02 enrichment batch, F2 spot-check)
- ⬜ QQ cleanup list: `backend/data/reports/qq/register-cleanup-not-making.csv` (the 81, plus whatever P1 and X2 add), with the funnel evidence for each law
- ⬜ Benchmark `legal-01-making` after the resolver backfill. Record it in the meta Results table and post on #161.

## Dependencies

- ✅ Worklist `worklists/01-not-making.csv` with `funnel_state` and `next_action`
- ✅ Baseline run `2026-09-25T1107-legal-baseline`
- ⬜ Fractalaw session for F3 and L1 (see the brief). The traceability and resolver work doesn't depend on it.

## Exit criteria

- Every `is_making` change is traceable to a source and reason in `record_change_log`.
- 0 in-force laws with Duty/Responsibility and `is_making = false`, unless a `making_review` overrides it.
- Every one of the 163 has a funnel state and next action. `not_making` in the benchmark contains only laws that are QQ cleanup or still waiting in the funnel.
- `legal-01-making`: `both` rises by the F1 laws that match. Evaluable agreement may dip slightly as laws enter the corpus without trees. Report register recall alongside it.
