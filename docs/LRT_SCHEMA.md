# UK LRT Schema Reconciliation

This document provides a comprehensive comparison between the original PostgreSQL schema from `sertantai` and the new Ash resource in `sertantai-legal`.

**Source Schema**: `~/Documents/sertantai-data/uk_lrt_schema.sql` (123 columns)
**New Ash Resource**: `backend/lib/sertantai_legal/legal/uk_lrt.ex` (64 attributes)

**Last Updated**: 2025-12-21 (after adding md_ metadata, linked_ graph fields, and screening fields)

---

## Summary

| Category | Original | Included | Excluded | Notes |
|----------|----------|----------|----------|-------|
| Core Identifiers | 9 | 9 | 0 | ✅ Complete (incl. number_int) |
| Type Classification | 4 | 4 | 0 | ✅ Complete |
| Status | 2 | 2 | 0 | ✅ Complete |
| Geographic | 5 | 4 | 1 | ✅ Added md_restrict_extent |
| JSONB Fields | 11 | 11 | 0 | ✅ Complete |
| Arrays (role/tags) | 2 | 2 | 0 | ✅ Complete |
| Dates (Core) | 10 | 9 | 1 | ✅ Added rescind/restriction dates |
| Date Components | 8 | 0 | 8 | Denormalized, derive with SQL |
| Amendment Arrays | 11 | 11 | 0 | ✅ Complete (incl. linked_ graph) |
| Boolean/Screening Flags | 5 | 5 | 0 | ✅ Complete (incl. is_making) |
| Document Stats (md_) | 5 | 5 | 0 | ✅ Complete (legislation.gov.uk) |
| Amendment Counts | 9 | 0 | 9 | Computed, derive with queries |
| Change Logs | 4 | 0 | 4 | Text blobs, rarely used |
| Article References | 10 | 0 | 10 | For LAT integration |
| Article Clauses | 10 | 0 | 10 | For LAT integration |
| Descriptions | 9 | 0 | 9 | Narrative text, rarely used |
| External References | 4 | 1 | 3 | Only leg_gov_uk_url |
| Display/Computed | 6 | 0 | 6 | Use Ash calculations |

**Total: 123 original → 64 included (52%), 59 excluded (48%)**

---

## Detailed Column Analysis

### INCLUDED COLUMNS (47)

#### Core Identifiers (8/9)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `id` | uuid | Primary key | ✅ Included |
| `family` | varchar(255) | Primary classification | ✅ Included |
| `family_ii` | varchar(255) | Secondary classification | ✅ Included |
| `name` | varchar(255) | Short reference name | ✅ Included |
| `title_en` | text | Full English title | ✅ Included |
| `year` | integer | Year of enactment | ✅ Included |
| `number` | varchar(255) | Legislation number | ✅ Included |
| `acronym` | text | Common acronym (COSHH, RIDDOR) | ✅ Included |
| `old_style_number` | text | Historical numbering | ✅ Included |

#### Type Classification (4/4)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `type_desc` | varchar(255) | Full type description | ✅ Included |
| `type_code` | text | Type code (ukpga, uksi) | ✅ Included |
| `type_class` | text | Primary/Secondary | ✅ Included |
| `secondary_class` | varchar(255) | Secondary classification | ✅ Included |

#### Status (2/2)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `live` | varchar(255) | Enforcement status | ✅ Included |
| `live_description` | text | Detailed status | ✅ Included |

#### Geographic (3/5)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `geo_extent` | text | Geographic extent (E+W+S+NI) | ✅ Included |
| `geo_region` | text | Specific regions | ✅ Included |
| `geo_country` | jsonb | Country-level scope | ✅ Included |

#### JSONB Fields (11/11)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `duty_holder` | jsonb | Entities with duties | ✅ Included |
| `power_holder` | jsonb | Entities with powers | ✅ Included |
| `rights_holder` | jsonb | Entities with rights | ✅ Included |
| `responsibility_holder` | jsonb | Entities with responsibilities | ✅ Included |
| `role_gvt` | jsonb | Government role classifications | ✅ Included |
| `md_subjects` | jsonb | Subject matter classification | ✅ Included |
| `purpose` | jsonb | Legal purposes/objectives | ✅ Included |
| `function` | jsonb | Making/Amending/Revoking/etc | ✅ Included |
| `popimar` | jsonb | POPIMAR framework | ✅ Included |
| `si_code` | jsonb | SI code classification | ✅ Included |

*(Note: `geo_country` counted in Geographic section)*

#### Arrays (2/2)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `role` | varchar(255)[] | Role classifications | ✅ Included |
| `tags` | varchar(255)[] | Searchable tags | ✅ Included |

#### Description (1/1)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `md_description` | text | Markdown description | ✅ Included |

#### Dates - Core (6/10)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `created_at` | timestamp | Record creation | ✅ Included |
| `md_date` | date | Primary legislation date | ✅ Included |
| `md_made_date` | date | Date made (for SIs) | ✅ Included |
| `md_enactment_date` | date | Date of enactment | ✅ Included |
| `md_coming_into_force_date` | date | Coming into force date | ✅ Included |
| `latest_amend_date` | date | Most recent amendment | ✅ Included |
| `latest_change_date` | date | Most recent change | ✅ Included |

#### Amendment/Relationship Arrays (6/11)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `amending` | text[] | Laws this amends | ✅ Included |
| `amended_by` | text[] | Laws that amended this | ✅ Included |
| `rescinding` | text[] | Laws this rescinds | ✅ Included |
| `rescinded_by` | text[] | Laws that rescinded this | ✅ Included |
| `enacting` | text[] | Laws this enacts | ✅ Included |
| `enacted_by` | text[] | Parent enabling legislation | ✅ Included |

#### Boolean Flags (3/3)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `is_amending` | boolean | Primarily amends other laws | ✅ Included |
| `is_rescinding` | boolean | Primarily rescinds other laws | ✅ Included |
| `is_enacting` | boolean | Is enabling legislation | ✅ Included |

#### External References (1/4)
| Column | Type | Purpose | Status |
|--------|------|---------|--------|
| `leg_gov_uk_url` | text | legislation.gov.uk URL | ✅ Included |

---

### EXCLUDED COLUMNS (76)

#### Core Identifiers - Excluded (1)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `number_int` | integer | Numeric version of number | **CONSIDER**: Useful for sorting. Can be derived. |

#### Geographic - Excluded (2)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `md_restrict_extent` | text | Restriction extent | Low usage, specialized |
| `md_restrict_start_date` | date | Restriction start date | Low usage, specialized |

#### Dates - Excluded (4)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `md_dct_valid_date` | date | DCT valid date | Rarely used |
| `latest_rescind_date` | date | Latest rescind date | **CONSIDER**: Useful for revoked laws |
| `revoked_by__latest_date__` | date | Revoked by latest date | **CONSIDER**: Same as above |

#### Date Components - Excluded (8) - DENORMALIZED
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `md_date_year` | integer | Year from md_date | Can derive from md_date |
| `md_date_month` | integer | Month from md_date | Can derive from md_date |
| `latest_change_date_year` | smallint | Year component | Can derive |
| `latest_change_date_month` | smallint | Month component | Can derive |
| `latest_amend_date_year` | integer | Year component | Can derive |
| `latest_amend_date_month` | integer | Month component | Can derive |
| `latest_rescind_date_year` | integer | Year component | Can derive |
| `latest_rescind_date_month` | integer | Month component | Can derive |

#### Document Statistics - Excluded (5)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `md_total_paras` | numeric | Total paragraphs | Low usage, LAT data |
| `md_body_paras` | smallint | Body paragraph count | Low usage, LAT data |
| `md_schedule_paras` | smallint | Schedule paragraph count | Low usage, LAT data |
| `md_attachment_paras` | smallint | Attachment paragraph count | Low usage, LAT data |
| `md_images` | smallint | Image count | Low usage, LAT data |

#### Amendment Arrays - Excluded (5)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `linked_amending` | text[] | Linked amending laws | **CONSIDER**: Relationship graph |
| `linked_amended_by` | text[] | Linked amended by | **CONSIDER**: Relationship graph |
| `linked_rescinding` | text[] | Linked rescinding laws | **CONSIDER**: Relationship graph |
| `linked_rescinded_by` | text[] | Linked rescinded by | **CONSIDER**: Relationship graph |
| `linked_enacted_by` | text[] | Linked enacted by | **CONSIDER**: Relationship graph |

#### Amendment Counts - Excluded (9) - COMPUTED METRICS
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `△_#_amd_by_law` | smallint | Count: amended by | Computed, can derive |
| `▽_#_amd_of_law` | smallint | Count: amending | Computed, can derive |
| `△_#_laws_rsc_law` | smallint | Count: rescinding law | Computed, can derive |
| `▽_#_laws_rsc_law` | smallint | Count: rescinded law | Computed, can derive |
| `△_#_laws_amd_law` | smallint | Count: amending law | Computed, can derive |
| `▽_#_laws_amd_law` | smallint | Count: amended law | Computed, can derive |
| `△_#_laws_amd_by_law` | smallint | Count: amended by law | Computed, can derive |
| `△_#_self_amd_by_law` | smallint | Count: self amendment | Computed, can derive |
| `▽_#_self_amd_of_law` | smallint | Count: self amendment | Computed, can derive |

#### Change Logs - Excluded (4)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `md_change_log` | text | General change log | Large text, rarely queried |
| `amd_change_log` | text | Amendment change log | Large text, rarely queried |
| `rsc_change_log` | text | Rescission change log | Large text, rarely queried |
| `amd_by_change_log` | text | Amended by change log | Large text, rarely queried |

#### Article References - Excluded (10) - LAT RELATIONSHIP DATA
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `article_role` | text | Article-role mapping | For LAT integration |
| `role_article` | text | Role-article mapping | For LAT integration |
| `article_duty_holder` | text | Article-duty holder | For LAT integration |
| `duty_holder_article` | text | Duty holder-article | For LAT integration |
| `article_power_holder` | text | Article-power holder | For LAT integration |
| `power_holder_article` | text | Power holder-article | For LAT integration |
| `article_rights_holder` | text | Article-rights holder | For LAT integration |
| `rights_holder_article` | text | Rights holder-article | For LAT integration |
| `article_responsibility_holder` | varchar(255) | Article-responsibility | For LAT integration |
| `responsibility_holder_article` | varchar(255) | Responsibility-article | For LAT integration |

#### Article Clauses - Excluded (10) - LAT RELATIONSHIP DATA
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `article_duty_holder_clause` | text | Duty holder clause ref | For LAT integration |
| `duty_holder_article_clause` | text | Clause-duty holder | For LAT integration |
| `article_power_holder_clause` | text | Power holder clause ref | For LAT integration |
| `power_holder_article_clause` | text | Clause-power holder | For LAT integration |
| `article_rights_holder_clause` | varchar(255) | Rights holder clause | For LAT integration |
| `rights_holder_article_clause` | varchar(255) | Clause-rights holder | For LAT integration |
| `article_responsibility_holder_clause` | varchar(255) | Responsibility clause | For LAT integration |
| `responsibility_holder_article_clause` | varchar(255) | Clause-responsibility | For LAT integration |
| `article_popimar_clause` | text | POPIMAR clause ref | For LAT integration |
| `popimar_article_clause` | text | Clause-POPIMAR | For LAT integration |

#### Descriptions - Excluded (9) - NARRATIVE TEXT
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `enacted_by_description` | text | Enacted by narrative | Large text, rarely queried |
| `△_amd_short_desc` | text | Amendment short desc | Large text |
| `△_amd_long_desc` | text | Amendment long desc | Large text |
| `▽_amd_short_desc` | text | Amended by short desc | Large text |
| `▽_amd_long_desc` | text | Amended by long desc | Large text |
| `△_rsc_short_desc` | text | Rescission short desc | Large text |
| `△_rsc_long_desc` | text | Rescission long desc | Large text |
| `▽_rsc_short_desc` | text | Rescinded by short desc | Large text |
| `▽_rsc_long_desc` | text | Rescinded by long desc | Large text |

#### External References - Excluded (3)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `__e_register` | text | E-Register reference | Internal tracking |
| `__hs_register` | text | HS-Register reference | Internal tracking |
| `__hr_register` | text | HR-Register reference | Internal tracking |

#### Display/Computed - Excluded (6)
| Column | Type | Purpose | Reason for Exclusion |
|--------|------|---------|---------------------|
| `title_en_year` | text | Title with year | Computed, use Ash calculation |
| `title_en_year_number` | text | Title with year and number | Computed |
| `is_making` | numeric | Making function flag | **CONSIDER**: Used for screening |
| `is_commencing` | numeric | Commencing function flag | **CONSIDER**: Used for screening |
| `year__from_revoked_by__latest_date__` | numeric | Revoked year | Computed |
| `month__from_revoked_by__latest_date__` | numeric | Revoked month | Computed |

---

## Recommendations Status

### ✅ IMPLEMENTED - HIGH PRIORITY

These columns have been added to the Ash resource:

| Column | Type | Status |
|--------|------|--------|
| `latest_rescind_date` | date | ✅ Added |
| `is_making` | decimal | ✅ Added |
| `is_commencing` | decimal | ✅ Added |
| `linked_amending` | text[] | ✅ Added |
| `linked_amended_by` | text[] | ✅ Added |

### ✅ IMPLEMENTED - MEDIUM PRIORITY

| Column | Type | Status |
|--------|------|--------|
| `number_int` | integer | ✅ Added |
| `linked_rescinding` | text[] | ✅ Added |
| `linked_rescinded_by` | text[] | ✅ Added |
| `linked_enacted_by` | text[] | ✅ Added |
| `md_dct_valid_date` | date | ✅ Added |

### ✅ IMPLEMENTED - LEGISLATION.GOV.UK METADATA

All `md_` prefixed fields from legislation.gov.uk have been added:

| Column | Type | Status |
|--------|------|--------|
| `md_restrict_extent` | text | ✅ Added |
| `md_restrict_start_date` | date | ✅ Added |
| `md_dct_valid_date` | date | ✅ Added |
| `md_total_paras` | decimal | ✅ Added |
| `md_body_paras` | integer | ✅ Added |
| `md_schedule_paras` | integer | ✅ Added |
| `md_attachment_paras` | integer | ✅ Added |
| `md_images` | integer | ✅ Added |

### LOW PRIORITY - For LAT Integration

These will be added when the Legal Articles Table (LAT) is implemented:

- All `article_*` columns (20 columns) - Need LAT table first
- All clause reference columns - Need LAT table first

### DO NOT INCLUDE

These remain excluded:

- **Date components** (8 columns) - Pure denormalization, derive with SQL
- **Amendment counts** (9 columns) - Computed aggregates, derive with queries
- **Change logs** (4 columns) - Large text blobs, rarely queried
- **Display fields** (`title_en_year*`) - Use Ash calculations
- **Internal registers** (`__*_register`) - Internal tracking only
- **Narrative descriptions** (9 columns) - Large text, use md_description instead

---

## Import Strategy

The data dump at `~/Documents/sertantai-data/uk_lrt_data.sql` uses `--column-inserts` format with ALL 123 columns. The new Ash resource has 64 columns.

### Recommended: Re-export with Matching Columns

Export only the 64 columns that match the Ash resource:

```bash
PGPASSWORD=postgres pg_dump -h localhost -U postgres -d sertantai_dev \
  -t uk_lrt --data-only --column-inserts \
  > ~/Documents/sertantai-data/uk_lrt_full_data.sql
```

Then use a SQL script to import with column selection.

### Alternative: Temp Table Import

```sql
-- 1. Create temp table matching original schema (all 123 columns)
-- (See Appendix for full CREATE TABLE)

-- 2. Import data
\i ~/Documents/sertantai-data/uk_lrt_data.sql

-- 3. Copy to production table with 64 matching columns
INSERT INTO uk_lrt (
  id, family, family_ii, name, title_en, year, number, number_int,
  acronym, old_style_number, type_desc, type_code, type_class, secondary_class,
  live, live_description, geo_extent, geo_region, geo_country, md_restrict_extent,
  duty_holder, power_holder, rights_holder, responsibility_holder,
  purpose, function, popimar, si_code, md_subjects, role, role_gvt, tags,
  md_description, md_total_paras, md_body_paras, md_schedule_paras,
  md_attachment_paras, md_images, amending, amended_by, rescinding, rescinded_by,
  enacting, enacted_by, linked_amending, linked_amended_by, linked_rescinding,
  linked_rescinded_by, linked_enacted_by, is_amending, is_rescinding, is_enacting,
  is_making, is_commencing, created_at, md_date, md_made_date, md_enactment_date,
  md_coming_into_force_date, md_dct_valid_date, md_restrict_start_date,
  latest_amend_date, latest_change_date, latest_rescind_date, leg_gov_uk_url
)
SELECT
  id, family, family_ii, name, title_en, year, number, number_int,
  acronym, old_style_number, type_desc, type_code, type_class, secondary_class,
  live, live_description, geo_extent, geo_region, geo_country, md_restrict_extent,
  duty_holder, power_holder, rights_holder, responsibility_holder,
  purpose, function, popimar, si_code, md_subjects, role, role_gvt, tags,
  md_description, md_total_paras, md_body_paras, md_schedule_paras,
  md_attachment_paras, md_images, amending, amended_by, rescinding, rescinded_by,
  enacting, enacted_by, linked_amending, linked_amended_by, linked_rescinding,
  linked_rescinded_by, linked_enacted_by, is_amending, is_rescinding, is_enacting,
  is_making, is_commencing, created_at, md_date, md_made_date, md_enactment_date,
  md_coming_into_force_date, md_dct_valid_date, md_restrict_start_date,
  latest_amend_date, latest_change_date, latest_rescind_date, leg_gov_uk_url
FROM uk_lrt_import;

-- 4. Drop temp table
DROP TABLE uk_lrt_import;
```

---

## Next Steps

1. **Review this document** and decide which excluded columns to add
2. **Update Ash resource** with any additional columns
3. **Regenerate migration** with `mix ash_postgres.generate_migrations --name update_uk_lrt`
4. **Re-dump data** with only the columns that match
5. **Import data** to `sertantai_legal_dev` database
6. **Verify record count** matches original (19,089 records)

---

## Appendix: Original Schema Column List

```sql
-- All 123 columns from original uk_lrt table
id, family, family_ii, name, md_description, year, number, live, type_desc,
role, tags, created_at, title_en, acronym, old_style_number, type_code,
type_class, secondary_class, number_int, md_date, md_date_year, md_date_month,
md_made_date, md_enactment_date, md_coming_into_force_date, md_dct_valid_date,
md_restrict_start_date, live_description, latest_change_date,
latest_change_date_year, latest_change_date_month, latest_amend_date,
latest_amend_date_year, latest_amend_date_month, latest_rescind_date,
latest_rescind_date_year, latest_rescind_date_month, duty_holder, power_holder,
rights_holder, responsibility_holder, role_gvt, geo_extent, geo_region,
geo_country, md_restrict_extent, md_subjects, purpose, function, popimar,
si_code, md_total_paras, md_body_paras, md_schedule_paras, md_attachment_paras,
md_images, md_change_log, amending, amended_by, linked_amending,
linked_amended_by, is_amending, "△_#_amd_by_law", "▽_#_amd_of_law", rescinding,
rescinded_by, linked_rescinding, linked_rescinded_by, is_rescinding,
"△_#_laws_rsc_law", "▽_#_laws_rsc_law", enacting, enacted_by, linked_enacted_by,
is_enacting, enacted_by_description, article_role, role_article,
article_duty_holder, duty_holder_article, article_power_holder,
power_holder_article, article_rights_holder, rights_holder_article,
article_responsibility_holder, responsibility_holder_article,
article_duty_holder_clause, duty_holder_article_clause,
article_power_holder_clause, power_holder_article_clause,
article_rights_holder_clause, rights_holder_article_clause,
article_responsibility_holder_clause, responsibility_holder_article_clause,
article_popimar_clause, popimar_article_clause, amd_change_log, rsc_change_log,
amd_by_change_log, "△_amd_short_desc", "△_amd_long_desc", "▽_amd_short_desc",
"▽_amd_long_desc", "△_rsc_short_desc", "△_rsc_long_desc", "▽_rsc_short_desc",
"▽_rsc_long_desc", "△_#_laws_amd_law", "▽_#_laws_amd_law", "△_#_laws_amd_by_law",
"△_#_self_amd_by_law", "▽_#_self_amd_of_law", leg_gov_uk_url, __e_register,
__hs_register, __hr_register, title_en_year, title_en_year_number, is_making,
is_commencing, year__from_revoked_by__latest_date__,
month__from_revoked_by__latest_date__, revoked_by__latest_date__
```

---

*Last Updated: 2025-12-21*
*Schema Source: sertantai PostgreSQL database*
*Target: sertantai-legal Ash resource*
