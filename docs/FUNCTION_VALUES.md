# Function Values

The `function` field is a JSONB array indicating the purpose/role of the legislation.

## Valid Values

| Value | Description | Screening Relevance |
|-------|-------------|---------------------|
| **Making** | Creates new duties/obligations | Primary - laws that create duties for compliance |
| **Amending** | Modifies existing legislation | Changes to existing obligations |
| **Revoking** | Repeals/revokes other laws | Removes obligations |
| **Commencing** | Brings other laws into force | Triggers when obligations start |
| **Enacting** | Primary legislation enabling SIs | Parent enabling legislation |

## Usage

- A law can have multiple functions (e.g., both "Making" and "Amending")
- For applicability screening, filter on `function` containing "Making"
- The `is_making` flag (decimal 1.0) indicates Making function is present

## DB Column

- **Column**: `function` (JSONB)
- **Type**: Array of strings
- **Example**: `["Making", "Amending"]`

## Related Fields

| Field | Type | Purpose |
|-------|------|---------|
| `is_making` | decimal | 1.0 if function contains "Making" |
| `is_commencing` | decimal | 1.0 if function contains "Commencing" |
| `is_amending` | boolean | Primary purpose is amending |
| `is_rescinding` | boolean | Primary purpose is revoking |
| `is_enacting` | boolean | Is enabling legislation |
