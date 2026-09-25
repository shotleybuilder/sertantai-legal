---
session: "QQ-01a: Making Pipeline Transparency"
status: active
opened: 2026-09-25
parent: qq-data-readiness/2026-09-25-qq-00-meta.md
issue: 161
related: [25, 120]
enables: [qq-data-readiness/2026-09-25-qq-01-making-triage]

bugs:
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

- ⬜ Design note: precedence rules, the write path, change-log entry shape, provenance fields and the `making_funnel` view. Put it in this session under "Design".
- ⬜ Gemini review of the design (CLAUDE.md acceptance gate), saved to `backend/data/code-reviews/`
- ⬜ Red: tests for `Legal.Taxa.MakingResolver` (pure). Inputs are review, enrichment verdict, triage and detector; output is `{is_making, source, reason}`.
- ⬜ Green: implement the resolver, with `@spec`/`@moduledoc`
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
- **#120 said "taxa wins by design"**, but no code enforces it. Each subscriber overwrites independently.
