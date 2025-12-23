# AMENDING

## Notes

/home/jason/Desktop/legl/legl/lib/legl/countries/uk/legl_register/amend/amend.ex Particularly the amendment_bfs function.  This is more complex than needed since it is always called with an enumeration limit = 0.  And /home/jason/Desktop/legl/legl/lib/legl/countries/uk/legl_register/amend/amending.ex.  Suggest creating a new module to handle amending. Once the code is ported and working with tests we can refactor to simplify.  Tests will need fixtures.

## amending

The amending field is a list of the names of the laws amended by this law.

Example content:
UK_uksi_1996_1107,UK_uksi_1993_1288,UK_uksi_1980_376

The laws may or may not be held in the sertantai-legal database.

## Derived from amending

% amending - the percentage of laws amended by this law that are held in the sertantai-legal database.
count_amending - the number of laws amended by this law.
is_amending - boolean indicating whether the law is an amending law.

## Detailed amending information and statistics

**🔺_stats_affected_laws_count**

The number of distinct laws amended by this law.

**🔺_stats_affects_count**

The number of amendments made by this law.

**🔺_stats_self_affects_count**

The number of amendments made by this law to itself.

**🔺_stats_affects_count_per_law**

Summary list of the laws amended by this law.

```
UK_uksi_1993_596 - 1
The Veterinary Surgeons Qualifications (EEC Recognition) (Amendment) Order 1993
https://legislation.gov.uk/id/uksi/1993/596

UK_uksi_1991_1218 - 1
The Veterinary Surgeons Qualifications (EEC Recognition) (German Democratic Republic Qualifications) Order 1991
https://legislation.gov.uk/id/uksi/1991/1218

UK_uksi_1987_447 - 1
The Veterinary Surgeons Qualifications (EEC Recognition) (Spanish and Portuguese Qualifications) Order 1987
https://legislation.gov.uk/id/uksi/1987/447

UK_uksi_1982_1076 - 1
not available
https://legislation.gov.uk/id/uksi/1982/1076

UK_uksi_1980_1951 - 1
not available
https://legislation.gov.uk/id/uksi/1980/1951

UK_ukpga_1966_36 - 10
Veterinary Surgeons Act 1966
https://legislation.gov.uk/id/ukpga/1966/36
```

**🔺_stats_affects_count_per_law_detailed**

Sets out a detailed description of the amendments made by this law.  
The legl app donor code uses 💚 in place of new lines (\n).

Example:

```
  1 - The Veterinary Surgeons Qualifications (EEC Recognition) (Amendment) Order 1993
  https://legislation.gov.uk/id/uksi/1993/596
    rev [Not yet]
  
  1 - The Veterinary Surgeons Qualifications (EEC Recognition) (German Democratic Republic Qualifications) Order 1991
  https://legislation.gov.uk/id/uksi/1991/1218
    rev [Not yet]
  
  1 - The Veterinary Surgeons Qualifications (EEC Recognition) (Spanish and Portuguese Qualifications) Order 1987
  https://legislation.gov.uk/id/uksi/1987/447
    rev [Not yet]
  
  1 - not available
  https://legislation.gov.uk/id/uksi/1982/1076
    rev [Not yet]
  
  1 - not available
  https://legislation.gov.uk/id/uksi/1980/1951
    rev [Not yet]
  
  10 - Veterinary Surgeons Act 1966
  https://legislation.gov.uk/id/ukpga/1966/36
  s. 2(2)(a) substituted [Yes]
  s. 5A substituted [Yes]
  s. 5B inserted [Yes]
  s. 5C inserted [Yes]
  s. 5D inserted [Yes]
  s. 6(6) substituted [Yes]
  s. 27(1) words omitted [Yes]
  s. 27(1) words substituted [Yes]
  s. 27(1) words inserted [Yes]
  Sch. 1A substituted [Yes]
```

## Cascade Update Strategy

When a new amending law is scraped that amends other laws in the database, those affected laws need their `amended_by` field updated. This is handled through a cascade update process.

### Overview

1. **During Scrape**: When Law A is scraped and found to amend Laws B, C, D:
   - Law A's `amending` field is populated: `[uksi/2020/100, ukpga/2019/50, ...]`
   - Law A's `is_amending` flag is set to `true`
   - Affected laws (B, C, D) are queued for update

2. **Queue Storage**: Affected laws are stored in a session-specific JSON file:
   - Location: `priv/scraper_sessions/{session_id}/affected_laws.json`
   - Format: `{"amending_law": "uksi/2024/123", "affected_laws": ["uksi/2020/100", "ukpga/2019/50"]}`

3. **Batch Update**: After scraping completes, run cascade updates:
   - For each affected law that exists in uk_lrt
   - Add the new amending law to its `amended_by` list
   - Skip laws not in the database (they'll be updated when they're scraped)

### Implementation Notes

**Phase 1 (Current)**: Manual cascade updates
- After confirming a new amending law, manually trigger update for affected laws
- Use `/api/cascade-update/:name` endpoint

**Phase 2 (Future)**: Automatic cascade updates
- Background job to process affected_laws.json after scrape session completes
- Batch updates with rate limiting to avoid overwhelming legislation.gov.uk

### Data Flow

```
New Law Scraped (A)
    |
    v
Amending.get_laws_amended_by_this_law(A)
    |
    v
[B, C, D] affected laws identified
    |
    +---> A.amending = [B, C, D]
    |
    +---> Queue [B, C, D] for amended_by update
    |
    v
Cascade Update Job
    |
    +---> B.amended_by += [A]
    +---> C.amended_by += [A]
    +---> D.amended_by += [A]
```

### Edge Cases

- **Law not in database**: Skip, will be populated when that law is scraped
- **Already in amended_by**: Deduplicate before saving
- **Revocations**: Also tracked in `rescinded_by` field using same pattern
