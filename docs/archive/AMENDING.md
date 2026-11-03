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

When new amending laws are scraped, the laws they amend need their `amended_by` field updated. Rather than manually manipulating arrays, we re-run enrichment parse on affected laws - this recycles existing code and ensures all stats recalculate correctly.

### Overview

1. **Batch Parse & Persist**: New laws are parsed and persisted as a batch (close session):
   - Each law's `amending` field is populated with UK IDs
   - Amendment stats are calculated
   - All affected laws are collected into a session JSON file

2. **Cascade Update UI**: After batch persist, show modal with aggregated affected laws:
   - **Header**: Session summary (e.g., "5 new laws persisted")
   - **In Database**: Combined list of all amended laws that exist in uk_lrt
   - **Not in Database**: Combined list of all amended laws not in uk_lrt

3. **Batch Re-parse**: User triggers re-parse for laws in database:
   - Run enrichment parse on each (same as existing ParseReviewModal flow)
   - The `/changes/affected` endpoint returns updated amending laws
   - `amended_by` field updates automatically via parse result
   - All stats recalculate correctly

4. **Batch Scrape (Recursive)**: User can scrape laws not in database:
   - Scrape and persist as a new batch
   - This builds another JSON with their affected laws
   - Creates next cascade layer
   - User decides when to stop (break point)

### UI Design

```
┌─────────────────────────────────────────────────────────────┐
│  Cascade Update: Session 2024-12-23                         │
│  5 new laws persisted                                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Affected Laws in Database (8)                              │
│  ┌─────────────────────────────────────────────┬──────────┐ │
│  │ ☐ UK_eur_2011_305 - Construction Products   │          │ │
│  │ ☐ UK_uksi_2013_1387 - CPR (Amd) Regs 2013   │          │ │
│  │ ☐ UK_ukpga_1974_37 - HSWA 1974              │          │ │
│  │ ... (5 more)                                │          │ │
│  └─────────────────────────────────────────────┴──────────┘ │
│                                                             │
│  Affected Laws Not in Database (3)                          │
│  ┌─────────────────────────────────────────────┬──────────┐ │
│  │ ☐ uksi/2019/465                             │          │ │
│  │ ☐ uksi/2018/230                             │          │ │
│  │ ☐ eur/2016/425                              │          │ │
│  └─────────────────────────────────────────────┴──────────┘ │
│                                                             │
│  [ Re-parse All In DB ]  [ Scrape & Add Selected ]  [Done]  │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
SESSION BATCH 1: Parse & Persist New Laws
    |
    v
Laws [A1, A2, A3] persisted
    |
    +---> A1.amending = [B, C]
    +---> A2.amending = [C, D, E]
    +---> A3.amending = [B, F]
    |
    v
Collect all affected: [B, C, D, E, F] --> affected_laws.json
    |
    v
CASCADE LAYER 1: Cascade Update Modal
    |
    +---> [B, C, D] in DB --> "Re-parse All In DB"
    |         |
    |         v
    |     Batch re-parse B, C, D
    |     amended_by fields update from /changes/affected
    |
    +---> [E, F] not in DB --> "Scrape & Add Selected"
              |
              v
SESSION BATCH 2: Scrape [E, F], persist
    |
    +---> E.amending = [G, H]
    +---> F.amending = [H, I]
    |
    v
New affected: [G, H, I] --> affected_laws.json
    |
    v
CASCADE LAYER 2: New Cascade Update Modal
    |
    v
User decides to continue or stop
```

### Processing Model: Breadth-First by Layer

**Important**: Each cascade layer is completed before moving to the next layer. Within a layer, the user has flexibility:

- **Individual processing**: Re-parse or scrape one law at a time
- **Batch processing**: "Re-parse All" or "Scrape All Selected"
- **Mixed**: Process some individually, then batch the rest

What we avoid is **depth-first chasing**: Don't follow Law A's full cascade chain before returning to Law B. Instead:

```
CORRECT (Breadth-First):
  Layer 1: [A, B, C] → process all/individually → complete layer
  Layer 2: [D, E, F, G] → process all/individually → complete layer
  Layer 3: [H, I] → process all/individually → done

INCORRECT (Depth-First):
  A → D → H → (backtrack) → E → (backtrack) → B → F → I → ...
```

This ensures predictable progress and lets the user see the full scope of each layer before deciding to continue.

### Implementation Notes

- Re-uses existing `StagedParser.parse/1` for enrichment
- Re-uses existing `ParseReviewModal` pattern for individual law updates
- No manual array manipulation needed - stats recalculate from source
- Rate limiting applies to legislation.gov.uk fetches

### Edge Cases

- **Already parsed recently**: Show last parse date, allow skip or re-parse
- **Parse fails**: Show error, allow retry or skip
- **Revocations**: Same pattern applies for `rescinded_by` updates
- **Circular references**: Law A amends B, B amends A - both get updated, no infinite loop since we parse each law once per cascade session
