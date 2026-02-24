# Function Values

The `function` field is a JSONB map indicating the purpose/role of the legislation. Keys are tag names, values are `true`.

Source of truth: Airtable `Function` multi-select column (8 tags).

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

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending Maker")
- 107 unique tag combinations exist in the Airtable data
- For applicability screening, filter on `function` containing "Making"
- 12,860 records have Function data; 6,713 are empty in the Airtable export
- 3,186 records (16.3%) have the Making tag — these are laws needing taxa parsing

## DB Columns

### `function` (JSONB map)

- **Column**: `function`
- **Type**: `map` (JSONB) — keys are tag names, values are `true`
- **Example**: `{"Making": true, "Amending Maker": true}`
- **Query**: `fragment("? \\? ?", function, "Making")` (JSONB `?` operator)

### `is_making` (boolean)

- **Column**: `is_making`
- **Type**: `boolean`
- **Purpose**: `true` if `function` contains "Making"
- **Derived from**: `function` map

### `is_commencing` (boolean)

- **Column**: `is_commencing`
- **Type**: `boolean`
- **Purpose**: `true` if `function` contains "Commencing"
- **Derived from**: `function` map

## Related Fields

| Field | Type | Purpose |
|-------|------|---------|
| `is_making` | boolean | `true` if function contains "Making" |
| `is_commencing` | boolean | `true` if function contains "Commencing" |
| `is_amending` | boolean | Primary purpose is amending (derived from relationship arrays) |
| `is_rescinding` | boolean | Primary purpose is revoking (derived from relationship arrays) |
| `is_enacting` | boolean | Is enabling legislation (derived from relationship arrays) |

## Airtable Statistics

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
