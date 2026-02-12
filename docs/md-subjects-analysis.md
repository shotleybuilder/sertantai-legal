# Analysis of `md_subjects` Column in `uk_lrt`

**Date**: 2026-02-12
**Database**: `sertantai_legal_dev` (19,318 records)
**Source**: The `md_subjects` field originates from legislation.gov.uk metadata. All `md_`-prefixed columns are scraped from the legislation.gov.uk API/feed.

---

## 1. Overall Population

| Metric | Value |
|--------|-------|
| Total rows | 19,318 |
| Rows with `md_subjects` (non-null) | 7,908 |
| Rows without `md_subjects` (null) | 11,410 |
| Population rate | **40.94%** |
| JSON type | All values are JSONB objects |
| Structure | `{"values": ["subject1", "subject2", ...]}` |
| Empty arrays or JSON nulls | 0 (every non-null value has real content) |

The column is a JSONB object containing a `values` key with an array of lowercase subject strings. There are no empty arrays or JSON null literals -- if the field is present, it always contains at least one subject.

---

## 2. Trend Over Time (by `year` column)

The data reveals a stark pattern: subjects were populated consistently from ~1987 to 2012, then stopped almost entirely in 2013.

### Pre-1987: Essentially Absent

| Period | Total Records | With Subjects | Coverage |
|--------|--------------|---------------|----------|
| 1267-1986 | 580 | 10 | 1.7% |

Only 10 scattered records from before 1987 have subjects, likely retroactively tagged.

### 1987-2012: Consistently Populated (65-85% coverage)

| Year | Total | With Subjects | % |
|------|-------|---------------|---|
| 1987 | 115 | 85 | 73.9% |
| 1988 | 130 | 89 | 68.5% |
| 1989 | 129 | 95 | 73.6% |
| 1990 | 140 | 109 | 77.9% |
| 1991 | 195 | 128 | 65.6% |
| 1992 | 203 | 153 | 75.4% |
| 1993 | 220 | 165 | 75.0% |
| 1994 | 328 | 279 | 85.1% |
| 1995 | 302 | 236 | 78.1% |
| 1996 | 414 | 354 | 85.5% |
| 1997 | 393 | 310 | 78.9% |
| 1998 | 339 | 285 | 84.1% |
| 1999 | 417 | 320 | 76.7% |
| 2000 | 394 | 277 | 70.3% |
| 2001 | 559 | 381 | 68.2% |
| 2002 | 513 | 327 | 63.7% |
| 2003 | 620 | 408 | 65.8% |
| 2004 | 582 | 403 | 69.2% |
| 2005 | 682 | 489 | 71.7% |
| 2006 | 753 | 515 | 68.4% |
| 2007 | 693 | 494 | 71.3% |
| 2008 | 572 | 392 | 68.5% |
| 2009 | 629 | 413 | 65.7% |
| 2010 | 651 | 447 | 68.7% |
| 2011 | 535 | 360 | 67.3% |
| 2012 | 499 | 338 | 67.7% |

Coverage in this period: **~7,800 out of ~10,900 records (71.6%)**.

The 20-35% without subjects in this period are likely records where legislation.gov.uk editors did not assign subjects (e.g., commencement orders, minor amendments).

### 2013: The Transition Year

| Year | Total | With Subjects | % |
|------|-------|---------------|---|
| 2013 | 581 | 26 | 4.5% |

Monthly breakdown using `md_date` shows the dropoff in detail:

| Month (2013) | Total | With Subjects | % |
|--------------|-------|---------------|---|
| January | 32 | 20 | 62.5% |
| February | 34 | 11 | 32.4% |
| March | 24 | 2 | 8.3% |
| April | 70 | 4 | 5.7% |
| May | 24 | 0 | 0.0% |
| June | 38 | 0 | 0.0% |
| July | 34 | 0 | 0.0% |
| August | 27 | 0 | 0.0% |
| September | 16 | 1 | 6.3% |
| October-December | 103 | 0 | 0.0% |

Subjects drop from ~62% in January 2013 to zero by May 2013.

### 2014-2024: Absent for New Legislation

| Year | Total | With Subjects | % |
|------|-------|---------------|---|
| 2014 | 562 | 0 | 0.0% |
| 2015 | 642 | 0 | 0.0% |
| 2016 | 505 | 0 | 0.0% |
| 2017 | 429 | 0 | 0.0% |
| 2018 | 439 | 0 | 0.0% |
| 2019 | 687 | 0 | 0.0% |
| 2020 | 790 | 0 | 0.0% |
| 2021 | 638 | 0 | 0.0% |
| 2022 | 478 | 0 | 0.0% |
| 2023 | 403 | 0 | 0.0% |
| 2024 | 425 | 0 | 0.0% |

**Zero new legislation from 2014-2024 has subjects.**

### 2025-2026: A Handful of Exceptions

| Year | Total | With Subjects | % |
|------|-------|---------------|---|
| 2025 | 340 | 5 | 1.5% |
| 2026 | 20 | 1 | 5.0% |

These 6 records are recent SIs that appear to have had subjects assigned (see Section 5 for details).

---

## 3. Content Analysis

### 3.1 Data Format

Every `md_subjects` value is a JSONB object with a single key `values` containing an array of lowercase strings:

```json
{"values": ["environmental protection", "waste policies and regulation", "pollution"]}
```

### 3.2 Subjects Per Record

| Subjects Per Record | Records | % of Records with Subjects |
|---------------------|---------|---------------------------|
| 1 | 3,329 | 42.1% |
| 2 | 1,283 | 16.2% |
| 3 | 964 | 12.2% |
| 4 | 641 | 8.1% |
| 5 | 1,505 | 19.0% |
| 6 | 165 | 2.1% |
| 7 | 20 | 0.3% |
| 8 | 1 | 0.01% |

- **Median**: 2 subjects per record
- **Mean**: 2.5 subjects per record
- **Range**: 1 to 8

The spike at 5 subjects is notable -- possibly a default template or tagging convention.

### 3.3 Distinct Subjects

There are **1,155 distinct subject values** across all records.

### 3.4 Top 30 Most Common Subjects

| Subject | Occurrences |
|---------|-------------|
| legislation | 506 |
| pollution | 449 |
| vehicles | 367 |
| local government | 366 |
| food standards | 357 |
| environmental protection | 340 |
| health and safety at work | 310 |
| waste policies and regulation | 305 |
| animals | 295 |
| health and safety requirements | 289 |
| care | 276 |
| planning (town and country) | 273 |
| national health service (nhs) | 266 |
| european union | 265 |
| animal health | 254 |
| food safety | 231 |
| traffic management | 228 |
| food legislation | 212 |
| environmentally sensitive areas | 212 |
| planning applications | 198 |
| business practice and regulation | 197 |
| rural development | 188 |
| parking fees | 188 |
| health care services and specialisms | 175 |
| parking | 164 |
| nhs management | 151 |
| water pollution | 151 |
| plant health | 142 |
| fisheries and aquaculture | 129 |
| regulation and deregulation | 127 |

### 3.5 Diverse Examples

| Title | Family | Subjects |
|-------|--------|----------|
| Green Deal (Acknowledgment) (Scotland) Regulations | CLIMATE CHANGE | energy conservation |
| Sea Fishing (Enforcement of Community Satellite Monitoring Measures) (Wales) Order | FISHERIES & FISHING | fisheries and aquaculture |
| Special Waste (Amendment) Regulations | WASTE | pollution, waste policies and regulation, litter |
| Electrical Luminous Tube Signs (Scotland) Regulations | *(empty)* | fire and rescue services, fire regulations, fire certificates, fire, electrical installation and servicing |
| Road Traffic (Permitted Parking Area) (Borough of Stockton-on-Tees) Order | *(empty)* | borough councils, parking, parking fees, traffic management |
| Environmentally Sensitive Areas (South Wessex Downs) Designation Order | WILDLIFE & COUNTRYSIDE | environmentally sensitive areas |
| Motor Vehicles (Approval) (Fees) (Amendment) Regulations | *(empty)* | vehicles, traffic management |
| Merchant Shipping (Oil Pollution) (Turks and Caicos Islands) Order | TRANSPORT: Harbours & Shipping | pollution |
| Local Government and Public Involvement in Health Act 2007 (Commencement) Order | *(empty)* | local government, fire and rescue services, local government structure, courts of law |
| Medicines (Homoeopathic Medicinal Products for Human Use) Regulations | *(empty)* | medicines |

---

## 4. Utility Analysis

### 4.1 Coverage Across Families

Subjects span nearly all families. Of 54 distinct families, **52 have at least some records with subjects**. Only two families have zero subject coverage:

| Family | Records | Reason |
|--------|---------|--------|
| HEALTH: Coronavirus | 554 | All enacted 2020+ (post-cutoff) |
| PLANNING & INFRASTRUCTURE | 1 | Single record, likely miscategorized |

### 4.2 Coverage by `type_code`

| type_code | Records with Subjects | Description |
|-----------|----------------------|-------------|
| uksi | 3,934 | UK Statutory Instruments (largest group) |
| *(empty)* | 2,025 | Records without type_code |
| nisr | 710 | Northern Ireland Statutory Rules |
| ssi | 710 | Scottish Statutory Instruments |
| wsi | 392 | Welsh Statutory Instruments |
| ukpga | 75 | UK Public General Acts |
| ukla | 34 | UK Local Acts |
| asp | 13 | Acts of the Scottish Parliament |
| nisi | 6 | Northern Ireland Orders in Council |
| nia | 4 | Acts of the NI Assembly |
| ukcm | 3 | Church Measures |
| mwa / anaw | 1 each | Welsh Measures/Acts |

### 4.3 Subjects Provide Cross-Cutting Themes Beyond Family

The `family` column provides a single hierarchical classification (e.g., "ENERGY", "WASTE"). Subjects provide **cross-cutting, multi-dimensional tagging** that a single family cannot capture.

**Cross-cutting subjects** (appearing in 10+ different families):

| Subject | Families It Spans | Records |
|---------|-------------------|---------|
| legislation | 36 | 260 |
| local government | 32 | 205 |
| european union | 29 | 215 |
| business practice and regulation | 28 | 114 |
| regulation and deregulation | 26 | 94 |
| health and safety at work | 24 | 276 |
| health and safety requirements | 23 | 227 |
| european parliament | 22 | 78 |
| waste policies and regulation | 21 | 302 |
| pollution | 20 | 442 |

For example, "pollution" appears in 20 different families -- it cuts across ENERGY, WASTE, WATER, MARINE, TRANSPORT, ENVIRONMENTAL PROTECTION, and more. A user searching for pollution-related legislation cannot find all relevant records by filtering on `family` alone.

### 4.4 Subjects Fill Gaps Where Family Is Missing

**5,996 records (31% of the dataset) have no family assigned.** Of those, **2,638 (44%) have subjects**, meaning subjects are the only topical classification available for those records.

Examples where subjects provide the only categorization:

| Title | Family | Subjects |
|-------|--------|----------|
| Port of Blyth (Battleship Wharf Railway) Order | *(empty)* | transport and works, england, transport |
| Highway Litter Clearance and Cleaning (Transfer Of Responsibility) (A13 Trunk Road) Order | *(empty)* | environmental protection, roads and highways |
| Crime and Disorder Act 1998 (Commencement No. 1) Order | *(empty)* | crime |

### 4.5 Subjects Provide Sub-Family Granularity

Within a family, subjects differentiate records at a finer grain. For example, within the ENERGY family:

| Subject | Occurrences |
|---------|-------------|
| fossil fuels | 34 |
| electricity supply | 33 |
| renewable energy | 32 |
| gas supply | 31 |
| local government | 20 |
| energy efficiency | 10 |
| wind power | 10 |
| biofuels | 8 |
| energy conservation | 8 |

This allows filtering ENERGY records into sub-topics (fossil fuels vs. renewables vs. grid) that the family column alone cannot express.

---

## 5. The "Stopped Populating" Hypothesis

### Confirmed: legislation.gov.uk Stopped Assigning Subjects in Early 2013

The data strongly supports a **cutoff in February-March 2013**.

**Monthly transition (by `md_date`)**:

| Month | Total Records | With Subjects | Coverage |
|-------|--------------|---------------|----------|
| 2012-12 | 28 | 17 | 60.7% |
| 2013-01 | 32 | 20 | 62.5% |
| 2013-02 | 34 | 11 | 32.4% |
| 2013-03 | 24 | 2 | 8.3% |
| 2013-04 | 70 | 4 | 5.7% |
| 2013-05 | 24 | 0 | 0.0% |
| 2013-06 onwards | -- | 0 | 0.0% |

From May 2013 through December 2024, **zero new legislation was assigned subjects**.

### Post-Cutoff Records That Do Have Subjects

There are exactly **100 records** with `md_date` after April 2013 that have subjects. These break into two categories:

**Category 1: Pre-2013 legislation updated after the cutoff (94 records)**

These are older Acts and SIs (enacted before 2013) whose `md_date` was updated when legislation.gov.uk made editorial changes. The subjects were assigned when the legislation was originally catalogued. Examples:

| Title | Year Enacted | md_date | md_modified |
|-------|-------------|---------|-------------|
| Northern Ireland Constitution Act | 1973 | 2016-04-01 | 2019-11-05 |
| Education Act | 2011 | 2018-07-09 | 2018-02-15 |
| Pensions Act | 2008 | 2022-08-01 | 2021-08-04 |

**Category 2: Genuinely recent legislation with subjects (6 records)**

| Title | Year | type_code | md_date | Subjects |
|-------|------|-----------|---------|----------|
| Phytosanitary Conditions (Amendment) Regulations | 2025 | uksi | 2025-05-07 | plant health |
| Aviation Safety (Amendment) (No. 2) Regulations | 2025 | uksi | 2025-07-14 | civil aviation |
| Waste Electrical and Electronic Equipment (Amendment, etc.) Regulations | 2025 | uksi | 2025-07-22 | environmental protection |
| Ozone-Depleting Substances (Grant of Halon Derogations) Regulations | 2025 | uksi | 2025-12-30 | environmental protection |
| Conservation of Salmon (Scotland) Amendment Regulations | 2025 | ssi | 2026-04-01 | fisheries, river, sea fisheries |
| Building (Fees) (Scotland) Amendment Regulations | 2026 | ssi | 2026-04-01 | building and buildings |

These 6 records (4 uksi, 2 ssi) from 2025-2026 suggest that legislation.gov.uk may be **reintroducing subject tagging** for some new legislation, or these were manually tagged. This is worth monitoring -- if the trend continues, future data refreshes may bring subjects back for new records.

---

## 6. Conclusions

1. **The field is valuable but historically bounded.** 40.9% of records have subjects (7,908 of 19,318), but this is concentrated in the 1987-2012 era. For legislation from that period, coverage is ~71%.

2. **legislation.gov.uk stopped populating subjects in early 2013.** The cutoff is sharp: coverage drops from ~62% in January 2013 to 0% by May 2013. This aligns with when legislation.gov.uk underwent major platform changes.

3. **Subjects provide genuine analytical value.** They offer:
   - Cross-cutting thematic tags that span multiple families (e.g., "pollution" across 20 families)
   - Sub-family granularity (e.g., "wind power" vs. "fossil fuels" within ENERGY)
   - The only topical classification for 2,638 records that have no family assigned

4. **The taxonomy is large but manageable.** 1,155 distinct subjects exist, but the top 50 cover the vast majority of occurrences. A curated subset could serve as filter facets.

5. **There are signs of resumed tagging in 2025-2026.** 6 recent records have subjects. Whether this represents a policy change at legislation.gov.uk or one-off manual additions is unclear.

6. **For filtering/search in the application**, subjects would be most useful as:
   - A secondary facet alongside family (especially for the 1987-2012 corpus)
   - A way to surface cross-cutting themes like "health and safety at work" that span many families
   - A fallback classification for the ~6,000 records with no family

7. **The 2013+ gap is the main limitation.** Over half the dataset (post-2013) has no subjects. Any UI feature built on subjects would need to clearly communicate that it only covers pre-2013 legislation, or the project would need to generate subjects for post-2013 records through other means (e.g., LLM-based classification from titles, or mapping from the `family` column).
