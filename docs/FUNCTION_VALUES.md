# Function Values

The `function` field is a JSONB map indicating the purpose/role of the legislation. Keys are tag names, values are `true`.

Initial data: seeded from Airtable `Function` multi-select column (one-time import, not an ongoing source). Ongoing values are set by the LRT → LAT parsing pipeline.

## Valid Values

### Enrichment Functions (set by taxa pipeline — definitive)

These are mutually exclusive. Their presence means enrichment has run on this law.

| Value | Description | Set When | Screening Relevance |
|-------|-------------|----------|---------------------|
| **Making** | Creates duties/responsibilities | duty_type contains Duty or Responsibility | Primary — laws that create obligations for compliance |
| **Empowering** | Grants powers/rights but no duties | duty_type present but no Duty/Responsibility | May affect rights holders; no compliance obligations |
| **Housekeeping** | Procedural/administrative — zero DRRP output | Taxa parser found nothing extractable | No ESH relevance — commencement, fees, corrections |

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

## Pipeline: How Function is Determined

The making classification has a three-stage lifecycle, each refining certainty:

```
Stage 1: LRT Scraper (metadata only, lightweight)
  → making_classification = "making" / "not_making" / "uncertain"
  → MakingDetector: title patterns, structure, metadata signals
  → This is a GUESS — no full text parsing
  → Immutable after scrape (never overwritten)

Stage 2: Human-AI Review (LAT session scoping)
  → making_review = "making" / "not_making" / "uncertain" / NULL
  → AI sense-checks auto-classification, human confirms
  → making_review_at records when the review happened
  → Overrides making_classification for queue filtering and Function derivation

Stage 3: Taxa Enrichment (fractalaw DRRP pipeline via Zenoh)
  → Extracts duty_type from legislation body (Duty, Responsibility, Right, Power)
  → Sets enrichment function label in function JSONB:
     - Making:      duty_type has Duty or Responsibility → is_making=true
     - Empowering:  duty_type has Power/Right but no Duty → is_making=false
     - Housekeeping: no DRRP signal at all → procedural/administrative
  → Enrichment labels are mutually exclusive and definitive
  → Empowering and Housekeeping prune LAT rows (not needed for duty tracking)

FunctionCalculator (Elixir, for batch recalculation)
  → Builds the function JSONB map:
     1. If Empowering or Housekeeping already set → enrichment ran, skip Making
     2. is_making = true → Making (definitive, from taxa)
     3. making_review = "making" → Making (provisional, pre-enrichment)
     4. making_classification = "making" → Making (provisional, pre-enrichment)
  → Relationship labels (Amending Maker, etc.) depend on target law's is_making
```

### Key distinction

| Field | Stage | Certainty | Purpose |
|-------|-------|-----------|---------|
| `making_classification` | LRT scrape | Auto-guess | Immutable auto-detection from title/metadata signals |
| `making_review` | LAT session scoping | Human-confirmed | Human-AI review, overrides auto for queue filtering |
| `is_making` | Taxa enrichment | Definitive | Gold standard — law creates duties/responsibilities |
| `function` | Taxa enrichment | Definitive | Enrichment labels (Making/Empowering/Housekeeping) + relationship labels |

### Effective classification

The **effective classification** is `COALESCE(making_review, making_classification)` — the review takes precedence when present, otherwise the auto-detection is used. This drives:
- LAT Queue filtering (which laws appear as parse candidates)
- FunctionCalculator `Making` label (provisional, before enrichment runs)

### Post-enrichment actions

| Enrichment Result | LAT Rows | uk_lrt DRRP Fields | Function Label |
|-------------------|----------|-------------------|----------------|
| Making | Retained | Populated (duties, holders, fitness) | `{"Making": true}` |
| Empowering | **Pruned** | Populated (powers/rights, holders) | `{"Empowering": true}` |
| Housekeeping | **Pruned** | Empty (nothing to retain) | `{"Housekeeping": true}` |

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending Maker")
- Enrichment labels (Making, Empowering, Housekeeping) are mutually exclusive
- For applicability screening, filter on `function` containing "Making"
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
- **Set by**: LAT parser (Rust service) — derived from `duty_type` containing "Duty" or "Responsibility"
- **Used by**: FunctionCalculator to set `"Making": true` in `function` map, and to determine "Maker" suffix on relationship labels

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
| `making_review` | string | Human via LAT Queue UI | 2: Review | Human-AI review — overrides auto for queue/Function |
| `making_review_at` | datetime | Auto-stamped on review | 2: Review | Audit timestamp |
| `is_making` | boolean | LAT parser (Rust) | 3: Definitive | Confirmed — has Duty or Responsibility |
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
