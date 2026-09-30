# Function Values

The `function` field is a JSONB map indicating the purpose/role of the legislation. Keys are tag names, values are `true`.

Initial data: seeded from Airtable `Function` multi-select column (one-time import, not an ongoing source). Ongoing values are set by the LRT → LAT parsing pipeline.

## Valid Values

### Obligation content (derived, not stored in `function`)

Making / Empowering / Housekeeping describe a law's **obligation content**. They are **not** stored in `function` (`FunctionCalculator` writes structural roles only; `mix legal.fix_stale_function` strips old tags). They derive from `is_making` and the law-level DRRP in `duty_type`.

How provisions and laws get their DRRP (the five layers: per-actor Hohfeldian type → position → holder class → DRRP → law verdict) is defined in fractalaw's **[DRRP Classification Schema](https://github.com/fractalatai/fractalatai/blob/master/docs/architecture/DRRP-CLASSIFICATION.md)** (fractalatai #68, agreed 2026-09-29). Legal follows it; change it there first.

| Label | fractalaw verdict (`making_enrichment_verdict`) | Condition (active holders only) |
|-------|------------------------------------------------|---------------------------------|
| **Making** | `making` | at least one Duty or Responsibility |
| **Empowering** | `empowering` | Rights and/or Powers only |
| **Housekeeping** | `no_obligations` | parsed and reconciled, no DRRP |

Raw `Obligation` / `Liberty` is **holder unknown** (no actors, or no active actor): not DRRP, and never Making evidence on its own. Legacy law-level `Obligation` and legacy `Rule` are treated the same way (`Rule` was dropped by #68; `mix drrp.remap` rewrote stored `Rule` to `Obligation`).

### Relationship Functions (set by relationship analysis)

| Value | Description | Screening Relevance |
|-------|-------------|---------------------|
| **Amending** | Modifies existing legislation (targets are non-makers) | Changes to existing obligations |
| **Revoking** | Repeals/revokes other laws (targets are non-makers) | Removes obligations |
| **Commencing** | Brings other laws into force | Triggers when obligations start |
| **Enacting** | Primary legislation enabling SIs (targets are non-makers) | Parent enabling legislation |

### Maker Qualifiers (what the TARGET law does)

The "Maker" suffix means the target law of the relationship has `Making` in its own Function. This creates a network view — you can trace which amendments/revocations affect duty-creating laws vs procedural ones.

| Value | Description | Screening Relevance |
|-------|-------------|---------------------|
| **Amending Maker** | Modifies existing legislation that IS a maker | Changes to duty-creating laws |
| **Revoking Maker** | Repeals/revokes other laws that ARE makers | Removes duty-creating laws |
| **Enacting Maker** | Primary legislation enabling SIs that ARE makers | Enables duty-creating laws |

## Pipeline: How `is_making` is Determined

`is_making` is resolved by `Legal.Making` (`Taxa.MakingResolver`, pure) from all the evidence gathered. A higher tier always wins; a tier without a verdict defers to the next one down. Each decision records `is_making_source` and `is_making_reason`.

| Tier | Evidence | Verdicts |
|------|----------|----------|
| `review` | `making_review` (human, LAT session scoping) | making / not_making |
| `enrichment` | `making_enrichment_verdict` from fractalaw (layer 5 of the [spec](https://github.com/fractalatai/fractalatai/blob/master/docs/architecture/DRRP-CLASSIFICATION.md)) | making → true; empowering / no_obligations → false; holder-unknown-only → none |
| `legacy_drrp` | `duty_type` with no enrichment provenance | Duty / Responsibility → true, else none |
| `triage` | fractalaw triage (regex making-detection at sync) | making / not_making; uncertain → none |
| `legacy_is_making` | `is_making` stored before the resolver | its value |
| `detector` | `making_classification` (MakingDetector, LRT scrape) | as triage |
| `default` | — | keep current; never set → false |

fractalaw's verdict is **one input**, not the final word: e.g. UK_uksi_2008_198 and UK_uksi_2014_2868 stay Making by human review despite `no_obligations`.

LAT is **not** pruned for Empowering / Housekeeping laws (the pruner was removed, #110). A not-Making law's LAT may be discarded by an explicit discard, which is logged in `lat_events`.

### Key distinction

| Field | Stage | Certainty | Purpose |
|-------|-------|-----------|---------|
| `making_classification` | LRT scrape | Auto-guess | Immutable auto-detection from title/metadata signals |
| `making_review` | LAT session scoping | Human-confirmed | Top tier of the resolver |
| `making_enrichment_verdict` | Taxa enrichment | Evidenced | fractalaw's law-level DRRP verdict |
| `is_making` | `Legal.Making` | Resolved | The decision, with `is_making_source` / `is_making_reason` |
| `function` | FunctionCalculator | Structural | Commencing / Enacting / Amending / Revoking (+ Maker composites) |

### Effective classification

The **effective classification** is `COALESCE(making_review, making_classification)` — the review takes precedence when present, otherwise the auto-detection is used. This drives LAT Queue filtering (which laws appear as parse candidates).

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending Maker")
- Obligation-content labels (Making, Empowering, Housekeeping) are mutually exclusive and derived, not stored in `function`
- For applicability screening, filter on `is_making`
- For the LAT parse queue, filter on effective classification (not `is_making`)

## DB Columns

### `function` (JSONB map)

- **Column**: `function`
- **Type**: `map` (JSONB) — keys are tag names, values are `true`
- **Example**: `{"Making": true, "Amending Maker": true}`
- **Query**: `fragment("? \\? ?", function, "Making")` (JSONB `?` operator)
- **Set by**: FunctionCalculator, using `is_making` and relationship arrays as inputs

### `is_making` (boolean)

- **Column**: `is_making`
- **Type**: `boolean`
- **Purpose**: Confirmed — law creates substantive duties/responsibilities
- **Set by**: `Legal.Making` (resolver; see the pipeline above) — Making = at least one Duty or Responsibility held by an active actor, per the [DRRP spec](https://github.com/fractalatai/fractalatai/blob/master/docs/architecture/DRRP-CLASSIFICATION.md)
- **Used by**: FunctionCalculator to determine the "Maker" suffix on relationship labels; applicability screening

### `making_classification` (string)

- **Column**: `making_classification`
- **Type**: `string` — `"making"`, `"not_making"`, or `"uncertain"`
- **Purpose**: Auto-detected guess from LRT metadata — immutable after scrape
- **Set by**: MakingDetector during LRT scraper stage (title patterns, structural signals)
- **Not manually editable**: preserved as the auto-detection record; human edits go to `making_review`

### `making_review` (string)

- **Column**: `making_review`
- **Type**: `string` — `"making"`, `"not_making"`, `"uncertain"`, or `NULL` (unreviewed)
- **Purpose**: Human-AI review classification — overrides `making_classification` for filtering and Function
- **Set by**: Human via LAT Queue grid (double-click "Review" column), auto-stamps `making_review_at`
- **NULL means**: unreviewed — effective classification falls back to `making_classification`

### `making_review_at` (utc_datetime_usec)

- **Column**: `making_review_at`
- **Type**: `utc_datetime_usec`
- **Purpose**: Audit timestamp — when `making_review` was last set
- **Set by**: Auto-stamped when `making_review` changes in the LAT Queue UI

### `is_commencing` (boolean)

- **Column**: `is_commencing`
- **Type**: `boolean`
- **Purpose**: `true` if law brings other laws into force
- **Set by**: FunctionCalculator

## Related Fields

| Field | Type | Set By | Stage | Purpose |
|-------|------|--------|-------|---------|
| `making_classification` | string | MakingDetector (LRT scraper) | 1: Auto | Immutable auto-guess — builds initial LAT queue |
| `making_confidence` | float | MakingDetector (LRT scraper) | 1: Auto | Confidence score (0.0–1.0) |
| `making_review` | string | Human via LAT Queue UI | 2: Review | Human-AI review — top resolver tier |
| `making_review_at` | datetime | Auto-stamped on review | 2: Review | Audit timestamp |
| `making_enrichment_verdict` | string | TaxaSubscriber (fractalaw) | 3: Enrichment | making / empowering / no_obligations |
| `is_making` | boolean | `Legal.Making` resolver | Resolved | Has Duty or Responsibility (resolved across tiers) |
| `is_commencing` | boolean | FunctionCalculator | Derived | Brings other laws into force |
| `is_amending` | boolean | Derived from relationships | Derived | Primary purpose is amending |
| `is_rescinding` | boolean | Derived from relationships | Derived | Primary purpose is revoking |
| `is_enacting` | boolean | Derived from relationships | Derived | Is enabling legislation |

## Airtable Statistics (initial seed)

| Tag | Records | % of tagged |
|-----|---------|-------------|
| Amending | 7,420 | 37.9% |
| Amending Maker | 6,213 | 31.7% |
| Making | 3,186 | 16.3% |
| Revoking | 2,329 | 11.9% |
| Commencing | 1,505 | 7.7% |
| Revoking Maker | 697 | 3.6% |
| Enacting | 622 | 3.2% |
| Enacting Maker | 234 | 1.2% |
