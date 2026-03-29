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

```
LRT Scraper (metadata only, lightweight)
  → making_classification = "making" / "not_making" / "uncertain"
  → MakingDetector: title patterns, structure, metadata signals
  → This is a GUESS — no full text parsing

LAT Queue (frontend)
  → Shows candidates where making_classification != "not_making"
  → These are laws that MIGHT create duties and need full-text parsing

LAT Parser (Rust service, resource-heavy full-text analysis)
  → Extracts duty_type from legislation body (Duty, Responsibility, Right, Power)
  → Derives is_making: true if duty_type contains "Duty" or "Responsibility"
  → This is the CONFIRMED answer

FunctionCalculator (Elixir, post-LAT)
  → Builds the function JSONB map using is_making as input
  → "Making": true added when is_making = true
  → Relationship labels (Amending Maker, etc.) depend on target law's is_making
```

### Key distinction

| Field | Stage | Certainty | Purpose |
|-------|-------|-----------|---------|
| `making_classification` | LRT parse | Guess | Builds the LAT queue — candidates for full-text parsing |
| `is_making` | LAT parse | Confirmed | Gold standard — law creates duties/responsibilities |
| `function` | Post-LAT | Derived | JSONB map built from `is_making` + relationship analysis |

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending Maker")
- For applicability screening, filter on `function` containing "Making"
- For the LAT parse queue, filter on `making_classification` (not `is_making`)

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
- **Purpose**: Lightweight guess from LRT metadata — used to build the LAT parse queue
- **Set by**: MakingDetector during LRT scraper stage (title patterns, structural signals)
- **Can be manually overridden**: via inline editing in the LAT queue UI

### `is_commencing` (boolean)

- **Column**: `is_commencing`
- **Type**: `boolean`
- **Purpose**: `true` if law brings other laws into force
- **Set by**: FunctionCalculator

## Related Fields

| Field | Type | Set By | Purpose |
|-------|------|--------|---------|
| `making_classification` | string | MakingDetector (LRT scraper) | Guess — builds LAT queue |
| `making_confidence` | float | MakingDetector (LRT scraper) | Confidence score (0.0–1.0) |
| `is_making` | boolean | LAT parser (Rust) | Confirmed — has Duty or Responsibility |
| `is_commencing` | boolean | FunctionCalculator | Brings other laws into force |
| `is_amending` | boolean | Derived from relationships | Primary purpose is amending |
| `is_rescinding` | boolean | Derived from relationships | Primary purpose is revoking |
| `is_enacting` | boolean | Derived from relationships | Is enabling legislation |

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
