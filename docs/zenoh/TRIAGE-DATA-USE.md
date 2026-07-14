# Triage Signal: How sertantai-legal stores and uses fractalaw's making classification

## Overview

fractalaw triages every law after ingesting its LAT provisions. The triage determines whether a law **makes obligations** (duties, responsibilities) or is non-making (empowering, housekeeping, commencement). This classification gates the entire downstream pipeline — only making laws receive DRRP enrichment, significance scoring, control generation, and Baserow sync.

The triage result is published over Zenoh to `fractalaw/@{tenant}/triage/{law_name}` and received by `TriageSubscriber`.

## Storage Mapping

| Triage field | LegalRegister column | Type | Why we store it |
|---|---|---|---|
| `classification` | `making_classification` | string | The canonical making signal. `"making"`, `"not_making"`, or `"uncertain"`. Used by LAT queue filters, Baserow sync profile queries, and applicability screening to determine which laws produce compliance obligations. |
| `confidence` | `making_confidence` | float | Bayesian posterior probability (0.0–1.0). Used for QA — low-confidence classifications (`< 0.7`) are flagged for human review via `making_review`. |
| `tier` | `making_detection_tier` | integer | Highest signal tier that contributed (1–5). Indicates the strength of evidence: tier 5 = strong lexical signals, tier 1 = structural heuristics only. Used in admin UI for transparency. |
| `counts` | `making_detection_signals` | JSONB map | Full provision breakdown: `total`, `process_rule`, `amendment`, `enactment`, `interpretation`, `with_actor`, `with_obligation`, `with_enabling`. Stored for auditability — explains *why* the triage reached its conclusion. Displayed in admin law detail view. |
| (derived) | `is_making` | boolean | `classification == "making"`. The boolean gate used by all downstream consumers. Set by TriageSubscriber on receipt. |

## Fields NOT stored

| Triage field | Why not stored |
|---|---|
| `sertantai_is_making` | Echo of our own `is_making` at the time fractalaw pulled the law. Informational only — we already have the current value. |
| `agrees` | Derived from `sertantai_is_making == (classification == "making")`. Useful for fractalaw's logs but redundant on our side since we can compute it. |

## Making lifecycle

```
1. LAT parsed (or re-parsed)
        ↓
2. fractalaw pulls new LAT via Zenoh queryable
        ↓
3. fractalaw triages: regex + Bayesian → classification
        ↓
4. fractalaw publishes triage result → TriageSubscriber
        ↓
5. TriageSubscriber writes making_classification, is_making, etc.
        ↓
6. IF making → fractalaw queues for DRRP enrichment
   IF not_making → law stops here (no enrichment, no controls)
        ↓
7. DRRP enrichment arrives → TaxaSubscriber writes function labels
   (Making/Empowering/Housekeeping — these CONFIRM the triage, they don't override it)
```

## Human override

`making_review` is a separate column for human-AI review that overrides `making_classification` in screening and queue logic. It is NOT overwritten by the triage subscriber — once a human reviews, their decision persists.

| Column | Set by | Overrides | Mutable |
|---|---|---|---|
| `making_classification` | TriageSubscriber (from fractalaw) | — | Yes — updated on each triage |
| `making_review` | Human via admin UI | `making_classification` for queue/screening | Yes — human can change |
| `is_making` | TriageSubscriber | — | Yes — updated on each triage |

## Downstream consumers

| Consumer | Uses | Behaviour |
|---|---|---|
| **LAT queue** (`/admin/lat/queue`) | `making_classification`, `making_review` | Filters to making + uncertain laws for parse prioritisation |
| **ProfileQuery** (Baserow sync) | `is_making` | Only syncs obligations from making laws |
| **Applicability screening** | `is_making` | Non-making laws excluded from customer legal registers |
| **Control generation** | `is_making` | fractalaw only generates controls for making laws |
| **Significance scoring** | `is_making` | Only making laws receive provision-level significance |
| **LAT pruning** (disabled) | `is_making` | Was: delete LAT for non-making laws. Currently disabled (#110). |
