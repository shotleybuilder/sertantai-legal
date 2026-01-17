# UK Legal Register Table (LRT) Schema

**Version**: 0.4
**Last Updated**: 2026-01-17

The `uk_lrt` table stores metadata for UK legislation including acts, statutory instruments, and regulations. This is shared reference data accessible to all tenants.

---

## Field Categories

1. [Credentials](#credentials) - Core identifiers (name, title, year, number, type)
2. [Description](#description) - Classification (family, si_code, tags, subjects)
3. [Status](#status) - Enforcement state
4. [Geographic Extent](#geographic-extent) - Territorial scope
5. [Metadata](#metadata) - Dates and document statistics
6. [Function](#function) - Relationships and amendment tracking
7. [Taxa](#taxa) - Role and holder classifications (DRRP model)
8. [Stats](#stats) - Amendment statistics
9. [External](#external) - URLs and references
10. [Timestamps](#timestamps) - Record tracking

---

## Credentials

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `id` | - | `uuid` | Yes | `550e8400-e29b-41d4-a716-446655440000` |
| `name` | `name` | `string` | Yes (19090) | `UK_nisro_1926_51` |
| `title_en` | `title_en` | `string` | Yes (14705) | `Wild Birds Protection Order (Northern Ireland)` |
| `year` | `year` | `integer` | Yes (19090) | `1926` |
| `number` | `number` | `string` | Yes (19089) | `51` |
| `number_int` | `number_int` | `integer` | No | |
| `type_code` | `type_code` | `string` | Yes (14166) | `nisro` |
| `type_desc` | `type_desc` | `string` | Yes (18562) | `Northern Ireland Statutory Rule or Order` |
| `type_class` | `type_class` | `string` | Yes (1995) | `Secondary` |
| `secondary_class` | `secondary_class` | `string` | Minimal (3) | |
| `acronym` | `acronym` | `string` | Yes (190) | `TSACNR` |
| `old_style_number` | `old_style_number` | `string` | No | |

---

## Description

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `family` | `family` | `string` | Yes (13094) | `💚 WILDLIFE & COUNTRYSIDE` |
| `family_ii` | `family_ii` | `string` | Yes (1408) | |
| `si_code` | `si_code` | `map` (JSONB) | Yes (16986) | `{"values": ["INFRASTRUCTURE PLANNING"]}` |
| `tags` | `tags` | `text[]` | Yes (17466) | `{Environmental,Noise,Regulations,Scotland}` |
| `md_description` | `md_description` | `string` | Yes (16277) | |
| `md_subjects` | `md_subjects` | `map` (JSONB) | Yes (7896) | `{"values": ["food safety", "food hygiene"]}` |

---

## Status

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `live` | `live` | `string` | Yes (16845) | `✔ In force` |
| `live_description` | `live_description` | `string` | Yes (686) | `Current legislation` |

---

## Geographic Extent

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `geo_extent` | `geo_extent` | `string` | Yes (13730) | `E+W+S+NI` |
| `geo_region` | `geo_region` | `text[]` | Yes (13738) | `{England,Wales,Scotland,"Northern Ireland"}` |
| `geo_detail` | `geo_detail` | `string` | Yes (13695) | `🇬🇧 E+W+S+NI\nAll provisions` |
| `md_restrict_extent` | `md_restrict_extent` | `string` | Yes (6098) | |

---

## Metadata

### Dates

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `md_date` | `md_date` | `date` | Yes (13610) | `2024-01-15` |
| `md_made_date` | `md_made_date` | `date` | Yes (14565) | `2024-01-10` |
| `md_enactment_date` | `md_enactment_date` | `date` | Yes (1581) | `2020-11-23` |
| `md_coming_into_force_date` | `md_coming_into_force_date` | `date` | Yes (11750) | `2024-02-01` |
| `md_dct_valid_date` | `md_dct_valid_date` | `date` | Yes (7538) | `2024-06-30` |
| `md_modified` | `md_modified` | `date` | Yes (17858) | `2024-06-01` |
| `md_restrict_start_date` | `md_restrict_start_date` | `date` | Yes (6287) | `2020-12-31` |
| `latest_amend_date` | `latest_amend_date` | `date` | Yes (5512) | |
| `latest_change_date` | `latest_change_date` | `date` | No | |
| `latest_rescind_date` | `latest_rescind_date` | `date` | Yes (4379) | |

### Document Statistics

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `md_total_paras` | `md_total_paras` | `integer` | Yes (17257) | `150` |
| `md_body_paras` | `md_body_paras` | `integer` | Yes (14197) | `120` |
| `md_schedule_paras` | `md_schedule_paras` | `integer` | Yes (17256) | `30` |
| `md_attachment_paras` | `md_attachment_paras` | `integer` | Yes (17256) | `0` |
| `md_images` | `md_images` | `integer` | Yes (17256) | `0` |

---

## Function

### Flags

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `function` | `function` | `map` (JSONB) | Yes (12858) | `{"Making": true, "Amending Maker": true}` |
| `is_making` | `is_making` | `boolean` | Yes (19089) | `true` |
| `is_commencing` | `is_commencing` | `boolean` | Yes (19089) | `false` |
| `is_amending` | `is_amending` | `boolean` | Yes (9866) | `true` |
| `is_rescinding` | `is_rescinding` | `boolean` | Yes (2462) | `false` |
| `is_enacting` | `is_enacting` | `boolean` | Yes (686) | `false` |

### Relationships

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `enacted_by` | `enacted_by` | `text[]` | Yes (8380) | `{ukpga/2000/5}` |
| `enacted_by_meta` | `enacted_by_meta` | `map[]` (JSONB) | No | `[{"name": "UK_ukpga_2008_29", "uri": "http://..."}]` |
| `enacting` | `enacting` | `text[]` | Yes (686) | |
| `amending` | `amending` | `text[]` | Yes (9866) | `{UK_ukpga_2000_5,UK_ukpga_1978_25}` |
| `amended_by` | `amended_by` | `text[]` | Yes (6338) | |
| `rescinding` | `rescinding` | `text[]` | Yes (2458) | |
| `rescinded_by` | `rescinded_by` | `text[]` | Yes (5789) | |

### Linked (Graph Edges)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `linked_enacted_by` | `linked_enacted_by` | `text[]` | No | |
| `linked_amending` | `linked_amending` | `text[]` | No | |
| `linked_amended_by` | `linked_amended_by` | `text[]` | No | |
| `linked_rescinding` | `linked_rescinding` | `text[]` | No | |
| `linked_rescinded_by` | `linked_rescinded_by` | `text[]` | No | |

---

## Taxa

### Roles (DRRP Model)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `role` | `role` | `text[]` | Yes (4986) | |
| `role_gvt` | `role_gvt` | `map` (JSONB) | Yes (4974) | `{"Gvt: Minister": true, "Gvt: Authority": true}` |
| `role_gvt_article` | `role_gvt_article` | `string` | Yes (4974) | |
| `article_role_gvt` | `article_role_gvt` | `string` | Yes (4974) | |
| `article_role` | `article_role` | `string` | Yes (4986) | |
| `role_article` | `role_article` | `string` | Yes (4986) | |

### Duty Type

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `duty_type` | `duty_type` | `map` (JSONB) | Yes (7775) | `{"values": ["Duty", "Responsibility", "Power", ...]}` |
| `duty_type_article` | `duty_type_article` | `string` | Yes (7775) | |
| `article_duty_type` | `article_duty_type` | `string` | Yes (7775) | |

### Duty Holder

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `duty_holder` | `duty_holder` | `map` (JSONB) | Yes (2450) | `{"Public": true, "Ind: Person": true}` |
| `duty_holder_article` | `duty_holder_article` | `string` | Yes (2430) | |
| `duty_holder_article_clause` | `duty_holder_article_clause` | `string` | Yes (2430) | |
| `article_duty_holder` | `article_duty_holder` | `string` | Yes (2430) | |
| `article_duty_holder_clause` | `article_duty_holder_clause` | `string` | Yes (2430) | |

### Rights Holder

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `rights_holder` | `rights_holder` | `map` (JSONB) | Yes (1812) | `{"key": true, ...}` |
| `rights_holder_article` | `rights_holder_article` | `string` | Yes (1812) | |
| `rights_holder_article_clause` | `rights_holder_article_clause` | `string` | Yes (1812) | |
| `article_rights_holder` | `article_rights_holder` | `string` | Yes (1812) | |
| `article_rights_holder_clause` | `article_rights_holder_clause` | `string` | Yes (1812) | |

### Responsibility Holder

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `responsibility_holder` | `responsibility_holder` | `map` (JSONB) | Yes (2513) | `{"key": true, ...}` |
| `responsibility_holder_article` | `responsibility_holder_article` | `string` | Yes (2513) | |
| `responsibility_holder_article_clause` | `responsibility_holder_article_clause` | `string` | Yes (2513) | |
| `article_responsibility_holder` | `article_responsibility_holder` | `string` | Yes (2513) | |
| `article_responsibility_holder_clause` | `article_responsibility_holder_clause` | `string` | Yes (2513) | |

### Power Holder

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `power_holder` | `power_holder` | `map` (JSONB) | Yes (2121) | `{"key": true, ...}` |
| `power_holder_article` | `power_holder_article` | `string` | Yes (2121) | |
| `power_holder_article_clause` | `power_holder_article_clause` | `string` | Yes (2121) | |
| `article_power_holder` | `article_power_holder` | `string` | Yes (2121) | |
| `article_power_holder_clause` | `article_power_holder_clause` | `string` | Yes (2121) | |

### POPIMAR

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `popimar` | `popimar` | `map` (JSONB) | Yes (4707) | `{"Policy": true, "Risk Control": true, ...}` |
| `popimar_article` | `popimar_article` | `string` | Yes (4707) | |
| `popimar_article_clause` | `popimar_article_clause` | `string` | Yes (67) | |
| `article_popimar` | `article_popimar` | `string` | Yes (4706) | |
| `article_popimar_clause` | `article_popimar_clause` | `string` | No | |

### Purpose

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `purpose` | `purpose` | `map` (JSONB) | No | |

---

## Stats

### Self-Affects

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `🔺🔻_stats_self_affects_count` | `stats_self_affects_count` | `integer` | ? | |

### Amending (this law affects others)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `🔺_stats_affects_count` | `amending_stats_affects_count` | `integer` | Yes | `2` |
| `🔺_stats_affected_laws_count` | `amending_stats_affected_laws_count` | `integer` | Yes | `2` |
| `🔺_stats_affects_count_per_law` | `amending_stats_affects_count_per_law` | `string` | ? | |
| `🔺_stats_affects_count_per_law_detailed` | `amending_stats_affects_count_per_law_detailed` | `string` | ? | |

### Amended By (this law is affected by others)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `🔻_stats_affected_by_count` | `amended_by_stats_affected_by_count` | `integer` | Yes | |
| `🔻_stats_affected_by_laws_count` | `amended_by_stats_affected_by_laws_count` | `integer` | Yes | |
| `🔻_stats_affected_by_count_per_law` | `amended_by_stats_affected_by_count_per_law` | `string` | ? | |
| `🔻_stats_affected_by_count_per_law_detailed` | `amended_by_stats_affected_by_count_per_law_detailed` | `string` | ? | |

### Rescinding (this law rescinds others)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `🔺_stats_rescinding_laws_count` | `rescinding_stats_rescinding_laws_count` | `integer` | ? | |
| `🔺_stats_rescinding_count_per_law` | `rescinding_stats_rescinding_count_per_law` | `string` | ? | |
| `🔺_stats_rescinding_count_per_law_detailed` | `rescinding_stats_rescinding_count_per_law_detailed` | `string` | ? | |

### Rescinded By (this law is rescinded by others)

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `🔻_stats_rescinded_by_laws_count` | `rescinded_by_stats_rescinded_by_laws_count` | `integer` | ? | |
| `🔻_stats_rescinded_by_count_per_law` | `rescinded_by_stats_rescinded_by_count_per_law` | `string` | ? | |
| `🔻_stats_rescinded_by_count_per_law_detailed` | `rescinded_by_stats_rescinded_by_count_per_law_detailed` | `string` | ? | |

### Change Logs

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `amending_change_log` | `amending_change_log` | `string` | ? | |
| `amended_by_change_log` | `amended_by_change_log` | `string` | ? | |
| `record_change_log` | `record_change_log` | `map[]` (JSONB) | No | |

---

## External

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `leg_gov_uk_url` | `leg_gov_uk_url` | `string` | Minimal (4) | `https://www.legislation.gov.uk/uksi/2024/123` |

---

## Timestamps

| Column | ParsedLaw Key | Type | Has Data | Example |
|--------|---------------|------|:--------:|---------|
| `created_at` | - | `utc_datetime` | Yes | `2024-01-15T10:30:00Z` |
| `updated_at` | - | `utc_datetime` | Yes | `2024-06-01T14:22:00Z` |

---

## Data Population Key

| Has Data | Meaning |
|----------|---------|
| **Yes (N)** | Column has N records with data (migrated from Airtable) |
| **Minimal (N)** | Column has few records (N < 10), likely from recent parsing |
| **No** | Column is empty (new or not yet populated) |
| **?** | Not checked |

---

## Related Documents

- [Family Values](./FAMILY_VALUES.md) - Valid family classifications
- [Function Values](./FUNCTION_VALUES.md) - Making, Amending, Revoking, Commencing, Enacting
