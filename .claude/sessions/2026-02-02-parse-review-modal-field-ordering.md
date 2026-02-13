# Fix ParseReviewModal Field Ordering

**Started**: 2026-02-02 15:40 UTC
**Issue**: None (fix field/section ordering to match LRT-SCHEMA.md)

## Problem

The "Update existing record" view in ParseReviewModal shows fields in incorrect order.
Currently showing: FUNCTION section with Amended By fields first.
Should follow: docs/LRT-SCHEMA.md section ordering.

## Todo

- [x] Review LRT-SCHEMA.md for correct section/field order
- [x] Update RecordDiff.svelte fieldGroups and groupOrder to match schema order
- [x] Test in UI
- Commit: `ed657d1`

## Notes

- Screenshot shows FUNCTION section displaying "Amended By" fields which belong in a different section

## Field Clarification: Affected By Count vs Amending Laws Count

From LRT-SCHEMA.md - these are **distinct metrics**:

| Field | Measures | Example |
|-------|----------|---------|
| `amended_by_stats_affected_by_count` | Total number of **individual amendments** made to this law | 31 (total amendment operations) |
| `amended_by_stats_affected_by_laws_count` | Number of **distinct laws** that amend this law | 10 (unique amending laws) |
| `amended_by` | Array of law names that amend this law | `[UK_ssi_2025_166, UK_ssi_2025_125, ...]` (10 items) |

**Why they differ**: A single amending law can make multiple amendments to the target law. For example, if UK_ssi_2019_80 makes 12 amendments to this law (inserting words in 12 different places), that counts as:
- 12 towards `affected_by_count` (12 individual changes)
- 1 towards `affected_by_laws_count` (1 amending law)

The JSONB field `affected_by_stats_per_law` shows the breakdown - e.g., `"UK_ssi_2019_80": { "count": 12, "details": [...] }`

## Additional Commits

- `ec641e3` - Update Amended By field labels per LRT-SCHEMA.md
- `9700527` - Sort fields by schema order instead of change type

**Ended**: 2026-02-02 15:55 UTC
