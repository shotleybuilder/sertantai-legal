---
session: "QQ-01a: Making Pipeline Transparency"
status: active
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25, 120]
enables: [qq-data-readiness/2026-09-25-qq-01-making-triage]

bugs:
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
- ⬜ `making_classification_source` (`detector` | `triage`): the detector must never overwrite a triage classification. Backfill the source from the shape of `making_detection_signals`.
- ⬜ One write path (`Legal.Making.apply/3` or similar):
  - It records a writer's evidence (triage fields, enrichment verdict, review) and runs the resolver.
  - It writes `is_making` and appends a `ChangeLogger` entry with the `source` (`detector` | `triage` | `taxa` | `review` | `scraper` | `backfill`) and the reason.
- ⬜ TriageSubscriber: write the triage fields only, through the write path. Remove the direct `is_making`.
- ⬜ TaxaSubscriber:
  - Record an enrichment verdict only when the payload carries DRRP results. Fitness, tree and significance-only payloads leave the verdict alone.
  - Housekeeping (empty payload) records an explicit "enriched: no obligations" verdict, with a source.
- ⬜ Persister and staged parser: route `is_making` through the write path. Check the 12 Aug reparse path.
- ⬜ `making_review`: honoured by the resolver as the top precedence. Setting it goes through the write path, so it's logged.
- ⬜ Provenance: add enrichment-verdict source and timestamp columns (migration; `db-schema-changes` skill for the `uk_lrt` view and triggers)
- ⬜ `making_funnel` view: one row per law with funnel state, evidence, the latest LAT session record and a next action. It formalises the QQ-01 worklist query.
- ⬜ Backfill `scrape_session_records.status = 'cleaned'` for the 17 stale `confirmed` records
- ⬜ Backfill `is_making` corpus-wide through the resolver (`--dry-run` first). Log every flip; report counts by source and reason.
- ⬜ Benchmark `legal-01a-transparency`. Record it in the meta Results table and post on #161.

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
