---
session: "QQ-01a: Making Pipeline Transparency"
status: closed
opened: 2026-09-25
closed: 2026-09-25
outcome: success
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161

summary: >
  is_making is now decided by one pure precedence resolver (review > enrichment >
  legacy DRRP > triage > legacy is_making > detector) behind a single row-locked
  write path that logs every change with writer, reason and dissent; a making_funnel
  view shows each law's stage, evidence and next action. UK backfill applied:
  72 laws became Making, none downgraded, 0 duty-bearing laws left not Making (was 33).

decisions:
  - what: One pure MakingResolver plus a single write path (Legal.Making.record/4) for every is_making writer
    why: Four writers overwrote each other with no audit trail; record_change_log had 0 is_making entries corpus-wide
    result: Triage, taxa, persister and admin PATCH all route through it; every change is logged with source, reason and dissent
  - what: Provenance columns on legal_register only; the uk_lrt view was not rebuilt
    why: All Making writers use LegalRegister, and definitions_parsed_at set the precedent; avoids a risky DROP VIEW
    result: Migration 20260925121805, six additive columns; compliance's Electric column list is unaffected
  - what: Row lock (SELECT ... FOR UPDATE) in the write path; rollback by snapshot table rather than a rollback task
    why: Gemini review. Triage and Taxa subscribers can race; a snapshot is simpler than reversing change-log entries
    result: making_backfill_snapshot_20260925 (20,704 rows)
  - what: Added a legacy_is_making tier between triage and detector (after the Gemini review)
    why: The first dry run let detector guesses overturn curated pre-resolver values (e.g. Computer Misuse Act)
    result: UK detector flips fell from 39 to 10, all null → true
  - what: Do not infer enrichment verdicts from historical duty_type
    why: Fractalaw QQ T1/T2 showed fitness doesn't imply DRRP ran, and published aggregates were stale pre-hub regex output
    result: Historical duty_type is legacy_drrp (upgrade-only); enrichment verdicts come only from fresh publishes
  - what: Apply 72 of 77 flips; hold 5 whose human review conflicts with fractalaw's text review
    why: Jason. The conflict turned on the amending-SI question
    result: 5 held for QQ-01
  - what: "Policy: an amending SI that inserts duties into a principal Act is not Making"
    why: Jason. The duties belong to the principal instrument
    result: Recorded in QQ-01 and in the fractalaw brief; fractalaw will exclude amendment instructions from DRRP aggregation
  - what: Relabel stale LAT session records as 'cleaned' only where the law is now not Making
    why: 39 Making laws also had deleted LAT; relabelling them would hide a real contradiction
    result: 51 relabelled; 39 laws flagged review_lat_deleted
  - what: AU backfill deferred
    why: Jason. Out of QQ scope
    result: 685 AU laws left for an AU session

metrics:
  resolver_tests: { making_resolver: 24, making_plan: 18, making_record_db: 2, backfill: 8, taxa_subscriber: 31 }
  full_suite: { passed: 1703, skipped: 2 }
  uk_backfill: { laws: 19812, flips_to_making: 72, downgrades: 0, held: 5, signals_decoded: 2029, duty_laws_not_making_before: 33, duty_laws_not_making_after: 0 }
  uk_is_making_source: { legacy_is_making: 15809, legacy_drrp: 3428, detector: 182, review: 182, default: 171, triage: 40, unresolved_held: 5 }
  making_funnel_uk: { lat_parse: 2729, lat_parse_or_review: 1000, enrich: 271, check_enrichment_output: 48, review_lat_deleted: 29, review_conflict: 20 }
  lat_session_records: { stale_confirmed: 111, relabelled_cleaned: 51, left_for_making_laws: 60 }
  benchmark_qq: { run: 2026-09-25T1306-legal-01a-transparency, both: "262 → 266", evaluable_agreement: "68.2% → 68.0%", register_recall: "47.9% → 48.6%", not_making: "163 → 155", screener_only: "172 → 138 (compliance 495976c)" }

lessons:
  - title: Test that a backfill is idempotent before the first --apply
    detail: >
      The legacy_is_making tier only counted values with no is_making_source. After the first apply set
      source = legacy_is_making, a re-run treated those values as having no legacy evidence, and detector
      guesses flipped 26 laws while about 15,600 were relabelled. Repaired from the snapshot with logged
      reversals. A plan → apply → re-plan test on the pure plan/4 would have caught it before any data changed.
    tag: data
  - title: A pre-encoded JSON string passed to a jsonb param is stored as a JSON string, and Ash then can't load the record
    detail: >
      legal.backfill_making_provenance passed Jason.encode!(map) to Repo.query for a jsonb column. Postgrex
      encoded it again, so 2,029 rows held a JSON string where the Ash :map type expected an object, and
      Ash.get raised on those records. Pass maps directly; repair in SQL with (col #>> '{}')::jsonb.
    tag: data
  - title: A lower tier that "no-ops" on unknown data can still overturn curated values
    detail: >
      Ranking the detector above "keep the existing value" looked harmless, but legacy is_making values were
      curated (Airtable) while detector signals had been stamped onto them later without changing is_making.
      Pre-resolver values need their own tier.
    tag: data
  - title: Cross-check a backfill's flip list against independent evidence before applying
    detail: >
      Fractalaw's T1/T2 text review showed 5 human making_reviews were wrong for amending SIs, and showed
      that historical fractalaw duty_type was stale. Both changed the design and the apply scope. Comparing the
      dry-run CSV with the peer session's CSVs took minutes.
    tag: data
  - title: A concurrent change in the benchmark's other repo confounds before/after numbers
    detail: >
      Compliance shipped a jurisdiction exclusion (495976c) between the legal baseline and the legal-01a run,
      so screener_only dropped 34 for reasons unrelated to legal. Attribute by tracing the changed laws through
      triage.csv rather than reading the headline delta.
    tag: tooling
  - title: A "stale status" backfill can hide real contradictions
    detail: >
      Relabelling every confirmed-but-LAT-deleted session record as 'cleaned' would have hidden 39 laws that
      are Making yet had their LAT deleted. Check the current verdict before assuming a status is merely stale.
    tag: data

bugs:
  - pattern: "Records with double-encoded making_detection_signals cannot be loaded by Ash at all (map type)"
    category: data-format
    module: legal_register.making_detection_signals
    affected: 2029
    fix: "Backfill.repair_signal_encoding!/0 decoded all 2,029 in SQL (2026-09-25)"
    status: fixed
  - pattern: "MakingDetector and TriageSubscriber both write making_classification; a reparse re-runs the detector and erases the triage verdict"
    category: making-traceability
    module: scraper/staged_parser.ex (run_making_detection), zenoh/triage_subscriber.ex
    fix: "Add making_classification_source; the detector never overwrites a triage classification"
    status: open
  - pattern: "making_detection_signals stored as a double-encoded JSON string"
    category: data-format
    module: mix legal.backfill_making_provenance (probable)
    affected: 1994
    fix: "Decode the string to a JSON object; fix the writer"
    status: open
  - pattern: "is_making changes are never recorded in record_change_log (0 entries corpus-wide); Zenoh subscriber writes bypass ChangeLogger"
    category: making-traceability
    module: zenoh/triage_subscriber.ex, zenoh/taxa_subscriber.ex
    affected: 19817
    fix: "Every write to is_making / making_* / duty_type goes through one path that appends a ChangeLogger entry with source and reason"
    status: open
  - pattern: "TriageSubscriber overwrites is_making from the triage estimate, even when enrichment has already found duties"
    category: making-precedence
    module: zenoh/triage_subscriber.ex (apply_triage)
    affected: 26
    fix: "Triage writes making_classification only; is_making comes from the resolver, where enrichment evidence outranks triage"
    status: open
  - pattern: "In-force laws with Duty/Responsibility entries but is_making = false"
    category: making-precedence
    module: is_making writers (triage_subscriber, taxa_subscriber, staged_parser/persister)
    affected: 33
    fix: "Resolver backfill; 26 explained by triage overwrite, 7 (classification making) by an unlogged writer: housekeeping, derive_is_making or the 12 Aug reparse"
    status: open
  - pattern: "TaxaSubscriber sets is_making = false for any payload without duty_type (derive_is_making) and for empty payloads (apply_housekeeping), whatever evidence the record already holds"
    category: making-precedence
    module: zenoh/taxa_subscriber.ex
    fix: "Only a payload that carries DRRP results may set the enrichment verdict; fitness/tree/significance-only payloads leave it alone"
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
    fix: "Record the source and timestamp of the enrichment verdict"
    status: open
  - pattern: "is_making changes are never recorded in record_change_log (0 entries corpus-wide); Zenoh subscriber writes bypass ChangeLogger"
    category: making-traceability
    module: zenoh/triage_subscriber.ex, zenoh/taxa_subscriber.ex
    affected: 19817
    fix: "Every writer goes through Legal.Making.record/4, which logs a 'making' change-log entry"
    status: fixed
  - pattern: "TriageSubscriber overwrites is_making from the triage estimate, even when enrichment has already found duties"
    category: making-precedence
    module: zenoh/triage_subscriber.ex (apply_triage)
    affected: 26
    fix: "Triage records evidence only; MakingResolver ranks triage below enrichment and legacy DRRP"
    status: fixed
  - pattern: "In-force laws with Duty/Responsibility entries but is_making = false"
    category: making-precedence
    module: is_making writers (triage_subscriber, taxa_subscriber, staged_parser/persister)
    affected: 33
    fix: "UK resolver backfill: 0 remain"
    status: fixed
  - pattern: "TaxaSubscriber sets is_making = false for any payload without duty_type (derive_is_making) and for empty payloads (apply_housekeeping), whatever evidence the record already holds"
    category: making-precedence
    module: zenoh/taxa_subscriber.ex
    fix: "Verdict only from non-null DRRP; empty payload records no_obligations evidence; the resolver decides"
    status: fixed
  - pattern: "LAT session records left at 'confirmed' after fractalaw-confirmed not-Making LAT was deleted (pre-dates the 'cleaned' status)"
    category: lat-session-status
    module: scrape_session_records (lat-reparse-shallow-2026-07-13)
    affected: 51
    fix: "51 records for not-Making laws relabelled 'cleaned'; the Making-law records are a separate bug"
    status: fixed
  - pattern: "duty_type has no provenance: cannot tell fractalaw enrichment from legacy regex/Airtable values"
    category: making-traceability
    module: legal_register.duty_type
    fix: "making_enrichment_verdict + making_enriched_at record fresh enrichment; historical duty_type is legacy_drrp by definition"
    status: fixed
  - pattern: "MakingDetector and TriageSubscriber both write making_classification; a reparse re-runs the detector and erases the triage verdict"
    category: making-traceability
    module: scraper/staged_parser.ex (run_making_detection), zenoh/triage_subscriber.ex
    fix: "making_classification_source column plus guard in Making.plan/4; backfilled from signal shape"
    status: fixed
  - pattern: "making_detection_signals stored as a double-encoded JSON string"
    category: data-format
    module: mix legal.backfill_making_provenance (probable)
    affected: 2029
    fix: "Writer fixed (no Jason.encode! for jsonb params); 2,029 rows decoded"
    status: fixed
  - pattern: "is_making has four writers and the human making_review verdict never wins"
    category: making-precedence
    module: zenoh/taxa_subscriber.ex, zenoh/triage_subscriber.ex, scraper/staged_parser.ex, legal/taxa/making_detector.ex
    affected: 14
    fix: "MakingResolver: review is the top tier; single write path"
    status: fixed
  - pattern: "Making laws whose LAT was deleted by a not-Making clean-up (Making verdict and deletion disagree)"
    category: making-funnel
    module: making_review (stale human reviews of amending SIs)
    affected: 39
    fix: "Re-review in QQ-01 (making_funnel.next_action = review_lat_deleted); re-parse LAT for any that stay Making"
    status: open
  - pattern: "AU laws with making_review = 'making' but is_making null (au.apply_nsw_annotations never set is_making)"
    category: making-precedence
    module: mix au.apply_nsw_annotations
    affected: 685
    fix: "mix making.resolve --country au, in an AU session"
    status: open

artifacts:
  - backend/lib/sertantai_legal/legal/taxa/making_resolver.ex
  - backend/lib/sertantai_legal/legal/making.ex
  - backend/lib/sertantai_legal/legal/making/backfill.ex
  - backend/lib/mix/tasks/making.resolve.ex
  - backend/lib/mix/tasks/making.review.ex
  - backend/lib/sertantai_legal/zenoh/taxa_subscriber.ex
  - backend/lib/sertantai_legal/zenoh/triage_subscriber.ex
  - backend/lib/sertantai_legal/scraper/persister.ex
  - backend/lib/sertantai_legal_web/controllers/uk_lrt_controller.ex
  - backend/lib/mix/tasks/legal.backfill_making_provenance.ex
  - backend/lib/sertantai_legal/legal/legal_register.ex
  - backend/priv/repo/migrations/20260925121805_add_making_provenance.exs
  - backend/priv/repo/migrations/20260925122809_add_making_funnel_view.exs
  - backend/priv/repo/migrations/20260925123321_refine_making_funnel_next_action.exs
  - backend/priv/repo/migrations/20260925131308_flag_making_laws_with_deleted_lat.exs
  - backend/test/sertantai_legal/legal/taxa/making_resolver_test.exs
  - backend/test/sertantai_legal/legal/making_test.exs
  - backend/test/sertantai_legal/legal/making_record_test.exs
  - backend/test/sertantai_legal/legal/making/backfill_test.exs
  - backend/data/code-reviews/2026-09-25-qq-01a-making-transparency-design.md
  - backend/data/reports/making/resolve-20260925T1237.csv
  - .claude/plans/qq-fractalaw-brief.md
  - "DB: making_backfill_snapshot_20260925"

depends_on:
  - 2026-09-25-qq-00-meta.md
  - 2026-07-13-issue-120.md
  - qq-requirements/2026-07-28-bms-lat-parse.md

enables:
  - "QQ-01 QQ Making triage (5 held laws, 39 review_lat_deleted, cleanup list)"
  - "Fractalaw T4 publish under the TaxaSubscriber contract"
  - Traceable is_making for compliance's screener corpus
---

# Session: QQ-01a Making Pipeline Transparency (CLOSED)

## Problem

`is_making` is decided by a funnel:
1. MakingDetector guesses.
2. Fractalaw triage estimates.
3. LAT is parsed.
4. Fractalaw enrichment confirms from the duties it finds.

The funnel records a lot (detection tier and signals, triage confidence, LAT session records, DRRP entries). Yet the final `is_making` can't be traced to the step that set it:
- `record_change_log` has **0** `is_making` entries corpus-wide. Only the persister and law_parser use `ChangeLogger`; the Zenoh subscribers write directly.
- Four writers overwrite each other:
  - TriageSubscriber: `is_making = classification == "making"`.
  - TaxaSubscriber: `derive_is_making`, plus `apply_housekeeping` for empty payloads, which sets false.
  - Persister: only ever upgrades to true.
  - `making_review`: human, but nothing reads it for `is_making`.
- As a result, 33 in-force laws have Duty/Responsibility entries but `is_making = false`. 26 of them were overwritten by a triage estimate; for the other 7, the cause wasn't recorded.

Goal: every Making decision can be traced to its source and evidence. One resolver decides; a DB view shows each law's funnel state.

## Todo

- ✅ Design note: precedence rules, the write path, change-log entry shape, provenance fields and the `making_funnel` view. Put it in this session under "Design".
- ✅ Gemini review of the design, saved to `backend/data/code-reviews/2026-09-25-qq-01a-making-transparency-design.md`
- ✅ Red: tests for `Legal.Taxa.MakingResolver` (pure), in `test/sertantai_legal/legal/taxa/making_resolver_test.exs`. All 21 failed as expected: the module didn't exist.
- ✅ Green: `lib/sertantai_legal/legal/taxa/making_resolver.ex`. 21/21 pass; credo clean. `Decision` includes `dissent`, the lower tiers that disagree.
- ✅ `making_classification_source`: the column exists and the detector-never-overwrites-triage guard is in `Making.plan/4`
- ✅ Backfill inference, `Legal.Making.Backfill.infer_evidence/1` (10 tests): classification source from signal shape, decoding double-encoded strings, and an enrichment verdict where fitness and DRRP both exist
- ✅ One write path, `Legal.Making.record/3` (row lock, `plan/4` pure). 13 unit tests plus 2 DB tests:
  - It records a writer's evidence (triage fields, enrichment verdict, review) and runs the resolver.
  - It writes `is_making` and appends a `ChangeLogger` entry with the `source` (`detector` | `triage` | `taxa` | `review` | `scraper` | `backfill`) and the reason.
- ✅ TriageSubscriber: writes triage evidence only (`making_classification_source: "triage"`) through `Making.record`.
- ✅ TaxaSubscriber:
  - Records `making_enrichment_verdict` only when the payload carries non-null DRRP data. Fitness, tree and significance-only payloads leave it alone.
  - Open for fractalaw: null DRRP columns are dropped during normalisation, so "DRRP ran and found nothing" can't be told apart from a fitness-only publish. The rule is conservative: no verdict, so no downgrade.
  - Housekeeping (empty payload) records `no_obligations` with `changed_by: taxa_subscriber:empty_payload`.
- ✅ Persister (all four create/update paths): the detector estimate is split out and recorded through `Making.record`, tagged `detector`. `is_making` is never persisted directly; the regex `duty_type` reaches the resolver as legacy evidence. The staged parser only feeds the persister.
- ✅ Admin `PATCH /laws/:id` (a fifth writer, found during this session): Making fields go through `Making.record`, and a direct `is_making` edit is recorded as a human `making_review`.
- ✅ `legal.backfill_making_provenance`: removed the `Jason.encode!` that double-encoded `making_detection_signals` (the cause of the 1,994 string rows)
- ✅ `making_review`: the top tier in the resolver. Setting it through the admin UI or `Making.record` is logged and time-stamped. A `mix making.review` task is still to do.
- ✅ Provenance columns, migration `20260925121805_add_making_provenance`. Added to the parent `legal_register` only, as for `definitions_parsed_at`; the `uk_lrt` view is unchanged because all Making writers use `LegalRegister`.
- ✅ `making_funnel` view (migration `20260925122809`): stage, evidence, the latest LAT session record, a `conflict` flag and `next_action`. Treats `confirmed` + LAT deleted as `cleaned`, which covers the 17 stale records without editing session history.
- ✅ Stale LAT session records: 111 corpus-wide. The 17 figure was only the QQ subset.
  - Relabelled `cleaned` only where the law is now not Making: 51 records across 29 laws.
  - Left alone: 60 records for **39 laws that are Making but whose LAT was deleted**. Most are Making on a human review (23), the rest on legacy duties (14) or the detector (2). Many are amending SIs, so the reviews are probably stale under the new policy.
  - The view flags them as `next_action = 'review_lat_deleted'` (migration `20260925131308`), and they're handed to QQ-01.
- ✅ `mix making.resolve` (dry run by default; `--apply` snapshots first; `--country`, `--names`)
- ✅ UK dry run: **76 flips, all to Making, no downgrades**. Report: `backend/data/reports/making/resolve-20260925T1227.csv`
- ✅ Jason signed off on 72 of the 77 flips. The other 5 are held for QQ-01, because their human review conflicts with fractalaw's T1/T2 text review (`--exclude`).
- ✅ UK applied. Net change against `making_backfill_snapshot_20260925`: **72 laws became Making, with no downgrades**. 0 in-force Duty/Responsibility laws remain with `is_making = false` (was 33). 20 triage conflicts are now visible in `making_funnel`. A second dry run changes nothing, so the backfill is idempotent.
- ⏸️ AU: 685 laws have `making_review = 'making'` but null `is_making` (deferred: Jason, leave for an AU session)
- ✅ `mix making.review LAW… --verdict making|not_making --note …`. The note is stored on the change-log entry (`Making.record/4` `:note` option).
- ✅ Benchmark `2026-09-25T1306-legal-01a-transparency`. Effect of this session: `both` +4, and 4 QQ laws moved from not_making to no_tree (they join the QQ-02 queue). The drop in screener_only from 172 to 138 is compliance's own jurisdiction exclusion (commit `495976c`, 12:35), not ours.
- ✅ Posted on #161: https://github.com/shotleybuilder/sertantai-legal/issues/161#issuecomment-5832999577

## Dependencies

- ✅ Findings from the QQ-00 planning session (bugs above)
- ✅ Coordinated with fractalaw: added a TaxaSubscriber contract section to the brief (null vs empty DRRP, enrichment precedence, fresh PG DRRP, the amending-SI policy, server up before T4), and messaged the `fractalaw-a9` session

## Findings (2026-09-25)

- **The 33 laws**: all have Duty or Responsibility entries. Their current `making_classification` is `not_making` 20, `uncertain` 6 and `making` 7.
  - The 26 not_making or uncertain laws were overwritten by the triage estimate (`apply_triage` sets `is_making` unconditionally).
  - The 7 `making` laws were set false by some other writer. Nothing recorded which.
- **`derive_is_making`**: any payload with taxa fields but no `duty_type` gives `is_making = false`. `convert_duty_type` does fall back to the record's existing entries, but only when it finds entries.
- **Persister**: logs through `ChangeLogger` and only upgrades `is_making` to true. So every false write in the corpus came from a subscriber that doesn't log.
- **Detector and triage share `making_classification`.** Each overwrites the other. Only 246 laws still carry triage signals: an object of counts. 5,575 carry detector signals as an object, and 1,994 carry detector signals as a double-encoded JSON string, which is a separate bug. Triage evidence has been lost wherever the detector re-ran on reparse.
- **#120 said "taxa wins by design"**, but no code enforces it. Each subscriber overwrites independently.

### Corpus state (UK, 2026-09-25)

| Evidence present | is_making true | false | null |
|---|---|---|---|
| Fractalaw fitness (enriched) + `duty_type` | 578 | 28 | — |
| Fractalaw fitness, no `duty_type` | — | 48 | — |
| `duty_type` without fitness (Airtable or legal regex TaxaParser) | 2,851 | 190 | 5 |
| No `duty_type`, no fitness | 96 | 15,545 | 476 |

Triage and `is_making` disagree in both directions: 45 laws classed `making` are false, and 29 classed `not_making` are true. `making_review` holds 749 `making` and 123 `not_making` verdicts.

## Design (draft for Gemini review)

### Evidence tiers

A higher tier always wins. A tier with no verdict defers to the next. Within a tier, the latest evidence wins.

| # | Tier | Source | Verdict mapping |
|---|---|---|---|
| 1 | `review` | `making_review` (human) | `making` → true, `not_making` → false |
| 2 | `enrichment` | Fractalaw DRRP, recorded by TaxaSubscriber. Only a payload that carries DRRP columns counts | Duty/Responsibility/Obligation entries → true (`making`). Rights/Powers only → false (`empowering`). Explicit empty payload → false (`no_obligations`) |
| 3 | `legacy_drrp` | `duty_type` or entries with no enrichment provenance (Airtable import, legal TaxaParser) | Duty/Responsibility → true. Anything else → no verdict. Never downgrades on its own |
| 4 | `triage` | Fractalaw triage `making_classification` | `making` → true, `not_making` → false, `uncertain` → no verdict |
| 5 | `detector` | MakingDetector classification | Same mapping as triage |
| 6 | `default` | — | Keep the existing value. A never-set law defaults to false |

### Components

- **`Legal.Taxa.MakingResolver`** (pure). `resolve(evidence) :: %{is_making: boolean, source: tier, reason: String.t()}`. The input is a struct with `@enforce_keys` for each tier's verdict and timestamp.
- **`Legal.Making`** (thin write path). `record(record, tier, evidence_attrs, changed_by)`:
  1. Merges the evidence attributes.
  2. Resolves `is_making` from the merged state.
  3. Builds a `ChangeLogger` entry with `source: "making"`, `changed_by: <writer>`, the field diffs and a `reason`.
  4. Does a single `Ash.update`.
- **Every writer calls it:** TriageSubscriber, TaxaSubscriber (upsert and housekeeping), the persister's true-upgrade, a new `mix making.review LAW --verdict making|not_making --note`, and the backfill.
- **TaxaSubscriber rule.** Enrichment evidence is recorded only when the payload includes any of `duties`/`rights`/`responsibilities`/`powers`/`duty_type`. Fitness, tree and significance-only payloads never touch the verdict. The empty-payload housekeeping path records `no_obligations`.
- **New columns** (migration, `uk_lrt` view and triggers per the `db-schema-changes` skill):
  - `making_enrichment_verdict` (`making` | `empowering` | `no_obligations`) and `making_enriched_at`;
  - `is_making_source` (tier), `is_making_reason` and `is_making_decided_at`.

  `is_making` stays a plain boolean, so compliance is unaffected.
- **`making_funnel` view**, one row per law: stage (`detected` | `triaged` | `lat_parsed` | `enriched` | `cleaned` | `skipped` | `deferred` | `reviewed`), `is_making` with source and reason, triage and review, enrichment verdict, `lat_count`, fitness, tree, the latest LAT session id and status, and a next action. It formalises the QQ-01 worklist query.

### Backfill

`mix making.resolve [--names …] [--dry-run]`:
- Builds each law's evidence from existing columns. Enrichment is inferred where `has_fitness` is true and DRRP is present, with the reason tagged `inferred`.
- Resolves, and writes through `Legal.Making` with `changed_by: "backfill"`.
- Reports flips by (old → new, tier, reason).

Separately, set `scrape_session_records.status = 'cleaned'` for the 17 stale `confirmed` records.

### Open questions

1. **Triage `uncertain` with no other evidence.** Should `is_making` be false, as today (excluded from screening), or keep its previous value? Draft: no verdict, so keep the existing value.
2. **Enrichment vs legacy.** When fractalaw says `empowering` or `no_obligations` but legacy `duty_type` says Duty, should enrichment override it? Draft: yes, by tier. Measure the flip count in the dry-run before deciding.
3. **Evidence as columns plus change log, or an append-only `making_evidence` table?** Draft: columns plus change log for v0.1.
4. **The 96 laws that are true with no `duty_type` and no enrichment** (probably Airtable Making). Draft: keep them true under `default`, and list them for review.

## Gemini review (2026-09-25)

Saved to `backend/data/code-reviews/2026-09-25-qq-01a-making-transparency-design.md` (gemini-2.5-pro).

Accepted:
- **Open questions 1–4 as drafted.** Plus: the dry-run must list every true → false downgrade for Jason's sign-off before the real run.
- **Row lock in the write path.** Resolve and update inside a transaction with `SELECT … FOR UPDATE`, because the Triage and Taxa subscribers can race on the same law.
- **Conflict flag.** When a newer lower-tier verdict disagrees with an older higher-tier one (e.g. a re-triage after enrichment), `making_funnel` shows `conflict = true`. It is not an override.
- **Rollback by snapshot.** Before the backfill, copy the Making columns to `making_backfill_snapshot_20260925` (name, is_making, making_*, duty_type).

Rejected:
- **Amending instruments inheriting Making from the duties they insert.** In our model, Making means the instrument itself creates duties, so amending instruments are correctly not Making.
- **Cutting the `making_funnel` view.** Transparency is the goal of this session, and the view is cheap SQL.
- **"Defer the benchmark".** Gemini read it as a performance benchmark; it's the screener benchmark.

Already covered:
- **Idempotency.** `ChangeLogger` only writes an entry when something changed, so a re-delivered message adds nothing.
- **Change-log growth.** The log is a column on the law row, and the backfill adds one entry per law that changes.

## Implementation notes (2026-09-25)

- **Tier added after the Gemini review: `legacy_is_making`.** It ranks between triage and detector.
  - The first dry run over the whole corpus (UK + AU) flipped 39 UK laws on detector guesses alone. Examples: Abolition of Feudal Tenure (Scotland) Act, Debt Arrangement and Attachment (Scotland) Act, Computer Misuse Act.
  - Those laws had a curated pre-resolver `is_making = false`, and `legal.backfill_making_provenance` had stamped detector signals on them without changing `is_making`.
  - An `is_making` with no `is_making_source` now counts as legacy evidence. The detector only decides for laws that were never set. Detector flips fell from 39 to 10, all of them null → true.
- **UK dry run, final** (19,817 laws). Flips: legacy_drrp 23, review 22 + 8, enrichment 12, detector 10 (null only), triage 1. Decisions by source: legacy_is_making 15,798, legacy_drrp 2,872, enrichment 570, review 187, detector 182, default 171, triage 37.
- **Legal's server was not running** during this session. The subscriber changes take effect on the next `mix phx.server`, which must happen before fractalaw's T4 publish.
- **6 laws in the `cleaned` stage still have `is_making = true`.** Check them after the apply.

## Incident: the legacy tier wasn't sticky (2026-09-25)

- **What happened.** The first `--apply` failed on 2,029 laws: Ash can't load `making_detection_signals` stored as a double-encoded string. I added `Backfill.repair_signal_encoding!/0` (SQL decode, after the snapshot) and re-ran the apply.
- **The bug.** On the re-run, laws resolved in the first run carried `is_making_source = "legacy_is_making"`. The legacy tier only counted values with no source, so those curated values lost their standing. Detector guesses flipped **26 laws** from false to true, and about 15,600 laws were relabelled `default` or `detector`.
- **Fix.** `legacy_is_making` now also counts values whose source is `legacy_is_making`. Tests were added for this and for idempotency.
- **Repair.** In SQL, restored `is_making` from the snapshot for the 15,640 affected laws and cleared their source. The 26 reversals each got a `backfill_repair` change-log entry. Re-applied, and verified that a second dry run has 0 changes.
- **Net result.** Exactly the 72 approved flips, no downgrades.
- **Lesson.** Test that a backfill is idempotent (re-planning already-resolved state) **before** the first `--apply`, not after.
