# Function Values

The `function` field is a JSONB map indicating the purpose/role of the legislation. Keys are tag names, values are `true`.

Initial data: seeded from Airtable `Function` multi-select column (one-time import, not an ongoing source). Ongoing values are set by the LRT → LAT parsing pipeline.

## Valid Values

### Base Functions (what the law does)

| Value | Description | Screening Relevance |
|-------|-------------|---------------------|
| **Making** | Creates new substantive duties/obligations | Primary - laws that create duties for compliance |
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

Stage 3: LAT Parser (Rust service, resource-heavy full-text analysis)
  → Extracts duty_type from legislation body (Duty, Responsibility, Right, Power)
  → Derives is_making: true if duty_type contains "Duty" or "Responsibility"
  → This is the CONFIRMED answer — overrides all prior stages

FunctionCalculator (Elixir, post-LAT)
  → Builds the function JSONB map using priority cascade:
     1. is_making (definitive, from taxa/full-text)
     2. making_review (human-AI confirmed, pre-parse)
     3. making_classification (auto-detected, provisional)
  → "Making": true added when any of the above resolves to making/true
  → Relationship labels (Amending Maker, etc.) depend on target law's is_making
```

### Key distinction

| Field | Stage | Certainty | Purpose |
|-------|-------|-----------|---------|
| `making_classification` | LRT scrape | Auto-guess | Immutable auto-detection from title/metadata signals |
| `making_review` | LAT session scoping | Human-confirmed | Human-AI review, overrides auto for queue and Function |
| `is_making` | LAT parse | Definitive | Gold standard — law creates duties/responsibilities |
| `function` | Post-LAT | Derived | JSONB map built from priority cascade + relationship analysis |

### Effective classification

The **effective classification** is `COALESCE(making_review, making_classification)` — the review takes precedence when present, otherwise the auto-detection is used. This drives:
- LAT Queue filtering (which laws appear as parse candidates)
- FunctionCalculator `Making` label (when `is_making` is not yet set)

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending Maker")
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
