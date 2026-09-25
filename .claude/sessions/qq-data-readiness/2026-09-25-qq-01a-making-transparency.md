---
session: "QQ-01a: Making Pipeline Transparency"
status: active
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25, 120]
enables: [qq-data-readiness/2026-09-25-qq-01-making-triage]

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
---

# Session: QQ-01a Making Pipeline Transparency (ACTIVE)

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
- ⏸️ Backfill `scrape_session_records.status = 'cleaned'` for the 17 stale records. Not needed: the view derives `cleaned`. Only do it if the LAT UI should show the badge.
- ✅ `mix making.resolve` (dry run by default; `--apply` snapshots first; `--country`, `--names`)
- ✅ UK dry run: **76 flips, all to Making, no downgrades**. Report: `backend/data/reports/making/resolve-20260925T1227.csv`
- ✅ Jason signed off on 72 of the 77 flips. The other 5 are held for QQ-01, because their human review conflicts with fractalaw's T1/T2 text review (`--exclude`).
- ✅ UK applied. Net change against `making_backfill_snapshot_20260925`: **72 laws became Making, with no downgrades**. 0 in-force Duty/Responsibility laws remain with `is_making = false` (was 33). 20 triage conflicts are now visible in `making_funnel`. A second dry run changes nothing, so the backfill is idempotent.
- ⏸️ AU: 685 laws have `making_review = 'making'` but null `is_making`. Jason: leave for an AU session.
- ✅ `mix making.review LAW… --verdict making|not_making --note …`. The note is stored on the change-log entry (`Making.record/4` `:note` option).
- ✅ Benchmark `2026-09-25T1306-legal-01a-transparency`. Effect of this session: `both` +4, and 4 QQ laws moved from not_making to no_tree (they join the QQ-02 queue). The drop in screener_only from 172 to 138 is compliance's own jurisdiction exclusion (commit `495976c`, 12:35), not ours.
- ⬜ Post the numbers on #161 (Jason to confirm)

## Dependencies

- ✅ Findings from the QQ-00 planning session (bugs above)
- ⬜ Coordinate with the fractalaw session running from `.claude/plans/qq-fractalaw-brief.md`. T1 may change how "tree but no duty types" payloads are published, which affects the TaxaSubscriber rules.

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
