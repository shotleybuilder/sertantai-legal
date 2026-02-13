# Title: Consolidate Stats Text Field Pairs to JSONB

**Started**: 2026-01-24
**Issue**: None

## Schema Review

### Current Fields (Legacy Airtable Design)

Four pairs of text fields storing count-per-law data (summary + detailed):

| Pair | Direction | DB Columns (summary / detailed) | Purpose |
|------|-----------|--------------------------------|---------|
| **1. Affected By** | 🔻 inbound | `🔻_stats_affected_by_count_per_law` / `🔻_stats_affected_by_count_per_law_detailed` | Amendments made TO this law BY others |
| **2. Rescinded By** | 🔻 inbound | `🔻_stats_rescinded_by_count_per_law` / `🔻_stats_rescinded_by_count_per_law_detailed` | Repeals/revokes made TO this law BY others |
| **3. Rescinding** | 🔺 outbound | `🔺_stats_rescinding_count_per_law` / `🔺_stats_rescinding_count_per_law_detailed` | Repeals/revokes this law makes TO others |
| **4. Affects** | 🔺 outbound | `🔺_stats_affects_count_per_law` / `🔺_stats_affects_count_per_law_detailed` | Amendments this law makes TO others |

**Direction key**:
- 🔻 = Inbound (other laws → this law)
- 🔺 = Outbound (this law → other laws)

### Current Text Format

**Summary** (`count_per_law`):
```
UK_uksi_2023_1071 - 4
The Health and Care Act 2022 (Further Consequential Amendments) Regulations 2023
https://legislation.gov.uk/id/uksi/2023/1071

UK_uksi_2020_240 - 1
The Statutory Parental Bereavement Pay Regulations 2020
https://legislation.gov.uk/id/uksi/2020/240
```

**Detailed** (`count_per_law_detailed`):
```
4 - The Health and Care Act 2022 (Further Consequential Amendments) Regulations 2023
https://legislation.gov.uk/id/uksi/2023/1071
 reg. 1(2)(d) words omitted [Not yet]
 reg. 1(2)(e) word omitted [Not yet]
 reg. 1(2)(ea) inserted [Not yet]
 blanket amendment words substituted [Not yet]

1 - The Statutory Parental Bereavement Pay Regulations 2020
https://legislation.gov.uk/id/uksi/2020/240
 reg. 1(2) words substituted [Not yet]
```

### Proposed JSONB Schema

Combine each pair into single JSONB field with structured data:

| Old Fields (summary + detailed) | New Field | DB Column |
|--------------------------------|-----------|-----------|
| `🔻_stats_affected_by_count_per_law` + `_detailed` | `affected_by_stats_per_law` | `🔻_affected_by_stats_per_law` |
| `🔻_stats_rescinded_by_count_per_law` + `_detailed` | `rescinded_by_stats_per_law` | `🔻_rescinded_by_stats_per_law` |
| `🔺_stats_rescinding_count_per_law` + `_detailed` | `rescinding_stats_per_law` | `🔺_rescinding_stats_per_law` |
| `🔺_stats_affects_count_per_law` + `_detailed` | `affects_stats_per_law` | `🔺_affects_stats_per_law` |

**JSONB structure** (same for all 4 fields):

```json
{
  "UK_uksi_2023_1071": {
    "name": "UK_uksi_2023_1071",
    "title": "The Health and Care Act 2022 (Further Consequential Amendments) Regulations 2023",
    "url": "https://legislation.gov.uk/id/uksi/2023/1071",
    "count": 4,
    "details": [
      { "target": "reg. 1(2)(d)", "affect": "words omitted", "applied": "Not yet" },
      { "target": "reg. 1(2)(e)", "affect": "word omitted", "applied": "Not yet" },
      { "target": "reg. 1(2)(ea)", "affect": "inserted", "applied": "Not yet" },
      { "target": "blanket amendment", "affect": "words substituted", "applied": "Not yet" }
    ]
  },
  "UK_uksi_2020_240": {
    "name": "UK_uksi_2020_240",
    "title": "The Statutory Parental Bereavement Pay Regulations 2020",
    "url": "https://legislation.gov.uk/id/uksi/2020/240",
    "count": 1,
    "details": [
      { "target": "reg. 1(2)", "affect": "words substituted", "applied": "Not yet" }
    ]
  }
}
```

### Benefits

1. **4 fields** instead of 8 text fields
2. **Queryable** - can filter/search by affecting law name, count, applied status
3. **Type-safe** - structured data instead of parsing text
4. **Flexible** - can add new fields without schema change
5. **Frontend-friendly** - JSON maps directly to TypeScript objects

## Todo

- [x] Update Ash resource: add 4 new `:map` attributes, mark 8 old `:string` attributes as deprecated
- [x] Generate Ash migration for 4 new JSONB columns
- [x] Create data migration script to convert existing text → JSONB (all 4 pairs)
- [x] Run migration on dev database
- [x] Verify data integrity for all 4 conversions
- [x] Update `StagedParser.build_count_per_law_*` functions to return map instead of string
- [x] Update `ParsedLaw` typespecs for all 4 field pairs
- [x] Update frontend types and components (field-config.ts, RecordDiff.svelte)
- [ ] Remove 8 deprecated text fields (future cleanup)

## Commits
- `399ecfb` - feat(schema): Consolidate stats text fields to JSONB
- `fd0dd6f` - feat(parser): Add consolidated JSONB stats fields to parser and frontend
- `85ba716` - docs: Update LRT-SCHEMA.md with consolidated JSONB stats fields
- `b1ffad2` - fix(migration): Parse affect from target in stats JSONB fields

## Migration Results
| Field | Records Converted |
|-------|-------------------|
| affects_stats_per_law | 9,079 |
| rescinding_stats_per_law | 2,481 |
| affected_by_stats_per_law | 6,243 |
| rescinded_by_stats_per_law | 5,714 |

## Notes
- Keep old fields temporarily for rollback safety
- Migration script should handle null values and parsing edge cases
- Emoji in column names: already used extensively in this codebase, so consistency > avoiding emoji
  - Downsides: requires quoting in SQL, some CLI tools render poorly, harder to type
  - Mitigated by: Ash attribute names are plain ASCII, only DB column uses emoji

## Fix: Affect Field Parsing (2026-01-25)

The initial data migration put combined "target affect" strings entirely into the `target` field, leaving `affect` as null. A fix migration was created to parse affect keywords from target strings using regex.

**Parsing results after fix:**

| Field | With Affect | Null Affect | Coverage |
|-------|-------------|-------------|----------|
| 🔺_affects | 399,743 | 37,531 | 91.4% |
| 🔺_rescinding | 30,896 | 5,045 | 86.0% |
| 🔻_affected_by | 446,485 | 79,980 | 84.8% |
| 🔻_rescinded_by | 29,014 | 3,479 | 89.3% |

Remaining nulls are edge cases:
- Badly formatted data (count+title lines in details)
- Rare keywords not in pattern (deleted, renumbered, conferred, etc.)
- Can be addressed in future fix migrations if needed

**Ended**: 2026-01-25 11:35
