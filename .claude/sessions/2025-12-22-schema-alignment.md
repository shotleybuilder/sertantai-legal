# Schema Alignment

**Started**: 2025-12-22 ~15:45
**Status**: In Progress

## Objective

Align schema terminology between:
1. **Donor App** (`legl` LegalRegister struct) - field names with mixed case
2. **DB Schema** (`uk_lrt` table) - snake_case column names
3. **UI Display** - Friendly names for ParseReviewModal

Goal: ParseReviewModal displays "Friendly Name (db_column)" for each field.

## Todo

- [x] Create reference docs for multi-select values
- [x] Credentials: Wire type_desc/type_class enrichment from TypeClass module ✓ confirmed working
- [ ] Review and confirm field mappings below
- [ ] Identify mandatory vs optional fields for new records
- [ ] Update ParseReviewModal with aligned terminology
- [ ] Add field tooltips/descriptions where helpful

## Notes

### 2025-12-23: Partial Revocation Support Added

Added three-state live status detection in `staged_parser.ex`:
- `✔ In force` - no revocations detected
- `⭕ Part Revocation / Repeal` - has revoking laws but not fully revoked
- `❌ Revoked / Repealed / Abolished` - title says REVOKED/REPEALED or RepealedLaw element exists

Commit: `2ab2e02`

### 2025-12-23: Credentials Enrichment Fixed

Wired `TypeClass.set_type/1` and `TypeClass.set_type_class/1` into the enrichment pipeline:

**Files modified:**
- `backend/lib/sertantai_legal/scraper/new_laws.ex:165,185-226` - Added type enrichment during initial scrape
- `backend/lib/sertantai_legal/scraper/law_parser.ex:39,391-467` - Added type enrichment during persistence
- `backend/lib/sertantai_legal_web/controllers/scrape_controller.ex:19,550-607` - Added type enrichment when serving API responses (backfills existing sessions)

**What happens now:**
- `type_desc`: Derived from `type_code` (e.g., "uksi" → "UK Statutory Instrument")
- `type_class`: Derived from `Title_EN` (e.g., "...Regulations" → "Regulation")

## Reference Documents

- [Family Values](../docs/FAMILY_VALUES.md) - ~40 families with emoji prefixes
- [Function Values](../docs/FUNCTION_VALUES.md) - Making, Amending, Revoking, Commencing, Enacting

## Sources

- Donor: `/home/jason/Desktop/legl/legl/lib/legl/countries/uk/legl_register/legal_register.ex`
- Current: `docs/LRT_SCHEMA.md` (64 columns from 123 original)
- Ash Resource: `backend/lib/sertantai_legal/legal/uk_lrt.ex`

---

## Complete Field Mapping

Legend:
- **M** = Mandatory for new records
- **O** = Optional
- **✓** = In current DB
- **✗** = Not in current DB (future consideration)

### CREDENTIALS

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| Name | name | Name | ✓ | M | Short ref e.g. "uksi/2025/1227" | no |
| Title_EN | title_en | Title | ✓ | M | Full English title | yes - credentials |
| Year | year | Year | ✓ | M | Year of enactment | yes - credentials |
| Number | number | Number | ✓ | M | Legislation number | yes - credentials |
| (derived) | number_int | Number (sortable) | ✓ | O | Integer for sorting | no |
| type_code | type_code | Type Code | ✓ | M | ukpga, uksi, etc. | yes - credentials |
| Type | type_desc | Type Description | ✓ | O | "UK Public General Acts" | yes - credentials |
| type_class | type_class | Type Class | ✓ | O | Primary/Secondary | yes - credentials |
| (none) | secondary_class | Secondary Class | ✓ | O | Additional classification | no |
| Acronym | acronym | Acronym | ✓ | O | COSHH, RIDDOR, etc. | no |
| old_style_number | old_style_number | Old Style Number | ✓ | O | Historical numbering | no |
| record_id | - | Record ID | ✗ | - | Airtable ID (not needed) | n/a |

### DESCRIPTION

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| Family | family | Family | ✓ | M | See [FAMILY_VALUES.md](../docs/FAMILY_VALUES.md) | yes - description |
| family_ii | family_ii | Sub-Family | ✓ | O | Secondary classification | yes - description |
| SICode | si_code | SI Codes | ✓ | O | JSONB - SI code classification | yes - description |
| Tags | tags | Tags | ✓ | O | Array - searchable tags | yes - description |
| md_description | md_description | Description | ✓ | O | Markdown description | yes - description |
| md_subjects | md_subjects | Subjects | ✓ | O | JSONB - subject classification | yes - description |

### STATUS

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| Live? | live | Status | ✓ | O | Three states: "✔ In force", "⭕ Part Revocation", "❌ Revoked" | yes - status |
| Live?_description | live_description | Status Description | ✓ | O | Detailed status text | yes - status |

### GEOGRAPHIC EXTENT

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| Geo_Extent | geo_extent | Geographic Extent | ✓ | O | "E+W+S+NI", "E+W", etc. | yes - extent |
| Geo_Region | geo_region | Region | ✓ | O | Specific regions | yes - extent |
| Geo_Pan_Region | geo_detail | Detail | ✓ | O | JSONB - law breakdown by Extent | yes - extent |
| md_restrict_extent | md_restrict_extent | Restriction Extent | ✓ | O | From legislation.gov.uk | no |

### METADATA

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| md_date | md_date | Primary Date | ✓ | O | Main legislation date | yes - metadata |
| md_made_date | md_made_date | Made Date | ✓ | O | Date SI was made | yes - metadata |
| md_enactment_date | md_enactment_date | Enacted Date | ✓ | O | Royal Assent date | yes - metadata |
| md_coming_into_force_date | md_coming_into_force_date | In Force Date | ✓ | O | When law takes effect | yes - metadata |
| md_dct_valid_date | md_dct_valid_date | DCT Valid Date | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_restrict_start_date | md_restrict_start_date | Restriction Start | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_total_paras | md_total_paras | Total Paragraphs | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_body_paras | md_body_paras | Body Paragraphs | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_schedule_paras | md_schedule_paras | Schedule Paragraphs | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_attachment_paras | md_attachment_paras | Attachment Paragraphs | ✓ | O | From legislation.gov.uk | yes - metadata |
| md_images | md_images | Images | ✓ | O | From legislation.gov.uk | yes - metadata | no |
| (derived) | latest_amend_date | Latest Amendment | ✓ | O | Most recent amendment | no |
| (derived) | latest_change_date | Latest Change | ✓ | O | Most recent change | no |
| (derived) | latest_rescind_date | Latest Rescind | ✓ | O | Most recent revocation | no |
| md_date_year | - | - | ✗ | - | Denormalized, derive from md_date | n/a |
| md_date_month | - | - | ✗ | - | Denormalized, derive from md_date | n/a |

### FUNCTION (RELATIONSHIPS (Arrays))

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| Function | function | Function | ✓ | O | See [FUNCTION_VALUES.md](../docs/FUNCTION_VALUES.md) | yes - function |
| (derived) | is_making | Is Making | ✓ | O | 1.0 if contains "Making" | no |
| (derived) | is_commencing | Is Commencing | ✓ | O | 1.0 if contains "Commencing" | no |
| (derived) | is_amending | Is Amending | ✓ | O | Boolean flag | no |
| (derived) | is_rescinding | Is Rescinding | ✓ | O | Boolean flag | no |
| (derived) | is_enacting | Is Enacting | ✓ | O | Boolean flag | no |
| ENACT |
| Enacting (from LRT) | enacting | Enacts | ✓ | O | Laws this enables | yes - function |
| Enacted_by | enacted_by | Enacted By | ✓ | O | Parent enabling legislation | yes - function |
| SELF **Self-affects (shared)** |
| 🔺_stats_self_affects_count | 🔺🔻_stats_self_affects_count | Self Amendments | ✓ | O | Amendments to itself | yes - function |
| AMEND **Amending stats (🔺 this law affects others)** |
| Amending | amending | Amends | ✓ | O | Laws this amends | yes - function |
| 🔺_stats_affects_count | 🔺_stats_affects_count | Affects Count | ✓ | O | Total amendments made | yes - function |
| 🔺_stats_affected_laws_count | 🔺_stats_affected_laws_count | Affected Laws Count | ✓ | O | Distinct laws amended | yes - function |
| 🔺_stats_affects_count_per_law | 🔺_stats_affects_count_per_law | Affects Per Law | ✓ | O | Summary list | no |
| 🔺_stats_affects_count_per_law_detailed | 🔺_stats_affects_count_per_law_detailed | Affects Per Law (Detail) | ✓ | O | Detailed breakdown | yes - function |
| AMENDED BY **Amended_by stats (🔻 this law is affected by others)** |
| Amended_by | amended_by | Amended By | ✓ | O | Laws that amended this | yes - function |
| 🔻_stats_affected_by_count | 🔻_stats_affected_by_count | Affected By Count | ✓ | O | Total amendments received | yes - function |
| 🔻_stats_affected_by_laws_count | 🔻_stats_affected_by_laws_count | Amending Laws Count | ✓ | O | Distinct laws amending this | yes - function |
| 🔻_stats_affected_by_count_per_law | 🔻_stats_affected_by_count_per_law | Affected By Per Law | ✓ | O | Summary list | no |
| 🔻_stats_affected_by_count_per_law_detailed | 🔻_stats_affected_by_count_per_law_detailed | Affected By Per Law (Detail) | ✓ | O | Detailed breakdown | yes - function |
| RESCIND **Rescinding stats (🔺 this law rescinds others)** |
| Revoking | rescinding | Rescinds | ✓ | O | Laws this revokes | yes - function |
| 🔺_stats_revoking_laws_count | 🔺_stats_rescinding_laws_count | Rescinded Laws Count | ✓ | O | Distinct laws rescinded | yes - function |
| 🔺_stats_revoking_count_per_law | 🔺_stats_rescinding_count_per_law | Rescinding Per Law | ✓ | O | Summary list | no |
| 🔺_stats_revoking_count_per_law_detailed | 🔺_stats_rescinding_count_per_law_detailed | Rescinding Per Law (Detail) | ✓ | O | Detailed breakdown | yes - function |
| Revoked_by | rescinded_by | Rescinded By | ✓ | O | Laws that revoked this | yes - function |
| RESCINDED BY **Rescinded_by stats (🔻 this law is rescinded by others)** |
| 🔻_stats_revoked_by_laws_count | 🔻_stats_rescinded_by_laws_count | Rescinding Laws Count | ✓ | O | Distinct laws rescinding this | yes - function |
| 🔻_stats_revoked_by_count_per_law | 🔻_stats_rescinded_by_count_per_law | Rescinded By Per Law | ✓ | O | Summary list | no |
| 🔻_stats_revoked_by_count_per_law_detailed | 🔻_stats_rescinded_by_count_per_law_detailed | Rescinded By Per Law (Detail) | ✓ | O | Detailed breakdown | yes - function |
| LINKS |
| (linked_*) | linked_amending | Linked Amends | ✓ | O | Graph edges | no  |
| (linked_*) | linked_amended_by | Linked Amended By | ✓ | O | Graph edges | no |
| (linked_*) | linked_rescinding | Linked Rescinds | ✓ | O | Graph edges | no |
| (linked_*) | linked_rescinded_by | Linked Rescinded By | ✓ | O | Graph edges | no |
| (linked_*) | linked_enacted_by | Linked Enacted By | ✓ | O | Graph edges | no |

### AMENDMENT STATS (New columns added 2025-12-23)

**Change logs:**
| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|
| amending_change_log | amending_change_log | Amending Change Log | ✓ | O | History of amending changes |
| amended_by_change_log | amended_by_change_log | Amended By Change Log | ✓ | O | History of amended_by changes |

### Taxa Schema

| Donor Field | DB Column | Friendly Name | In DB | Has Data | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|----------|-------|--------------------|
| actor | role | Role | ✅ varchar[] | 4,705 | | Yes - Roles (DRRP Model) |
| actor_gvt | role_gvt | Role Gvt | ✅ jsonb | 0 | | Yes - Roles (DRRP Model) |
| DUTY TYPE |
| duty_type | duty_type | Duty Type | ❌ ADD | - | | Yes - Roles (DRRP Model) |
| duty_type_article | duty_type_article | Duty Type Article | ✅ text | 0 | | Yes - Roles (DRRP Model) |
| article_duty_type | article_duty_type | Article Duty Type | ✅ text | 0 | | no |
| **DUTY HOLDER** |
| duty_holder | duty_holder | Duty Holder | ✅ jsonb | 0 | | Yes - Roles (DRRP Model)|
| duty_holder_article | duty_holder_article | Duty Holder Article | ✅ text | 0 | | no |
| duty_holder_article_clause | duty_holder_article_clause | Duty Holder Article Clause | ✅ text | 0 | | Yes - Roles (DRRP Model) |
| article_duty_holder | article_duty_holder | Article Duty Holder | ✅ text | 0 | | no |
| article_duty_holder_clause | article_duty_holder_clause | Article Duty Holder Clause | ✅ text | 0 | | no |
| **RIGHTS HOLDER** |
| rights_holder | rights_holder | Rights Holder | ✅ jsonb | 0 | | Yes - Roles (DRRP Model) |
| rights_holder_article | rights_holder_article | Rights Holder Article | ✅ text | 0 | | no |
| rights_holder_article_clause | rights_holder_article_clause | Rights Holder Article Clause | ✅ varchar | 0 | | Yes - Roles (DRRP Model) |
| article_rights_holder | article_rights_holder | Article Rights Holder | ✅ text | 0 | | no |
| article_rights_holder_clause | article_rights_holder_clause | Article Rights Holder Clause | ✅ varchar | 0 | | no |
| **RESPONSIBILITY HOLDER** |
| responsibility_holder | responsibility_holder | Responsibility Holder | ✅ jsonb | 0 | | Yes - Roles (DRRP Model) |
| responsibility_holder_article | responsibility_holder_article | Responsibility Holder Article | ✅ varchar | 0 | | no |
| responsibility_holder_article_clause | responsibility_holder_article_clause | Responsibility Holder Article Clause | ✅ varchar | 0 | | Yes - Roles (DRRP Model) |
| article_responsibility_holder | article_responsibility_holder | Article Responsibility Holder | ✅ varchar | 0 | | no |
| article_responsibility_holder_clause | article_responsibility_holder_clause | Article Responsibility Holder Clause | ✅ varchar | 0 | | no |
| **POWER HOLDER** |
| power_holder | power_holder | Power Holder | ✅ jsonb | 0 | | Yes - Roles (DRRP Model) |
| power_holder_article | power_holder_article | Power Holder Article | ✅ text | 0 | | no |
| power_holder_article_clause | power_holder_article_clause | Power Holder Article Clause | ✅ text | 0 | | Yes - Roles (DRRP Model) |
| article_power_holder | article_power_holder | Article Power Holder | ✅ text | 0 | | no |
| article_power_holder_clause | article_power_holder_clause | Article Power Holder Clause | ✅ text | 0 | | no |
| **POPIMAR** |
| popimar | popimar | Popimar | ✅ jsonb | 0 | | Yes - Roles (DRRP Model) |
| popimar_article | popimar_article | Popimar Article | ❌ ADD | - | | no |
| popimar_article_clause | popimar_article_clause | Popimar Article Clause | ✅ text | 0 | | Yes - Roles (DRRP Model) |
| article_popimar | article_popimar | Article Popimar | ❌ ADD | - | | no |
| article_popimar_clause | article_popimar_clause | Article Popimar Clause | ✅ text | 0 | | no |
| (none) | purpose | Purpose | ✓ | O | Legal purposes/objectives | yes - role |

### EXTERNAL REFERENCES

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| (none) | leg_gov_uk_url | legislation.gov.uk URL | ✓ | O | Link to source | no |

### TIMESTAMPS

| Donor Field | DB Column | Friendly Name | In DB | Req | Notes | Parse Review Modal |
|-------------|-----------|---------------|-------|-----|-------|--------------------|
| (auto) | created_at | Created At | ✓ | O | Record creation | no |
| (auto) | updated_at | Updated At | ✓ | O | Last modification | no |

---

## NOT IN CURRENT DB (Excluded from migration)

### Change Logs (Large Text)
| Donor Field | Reason |
|-------------|--------|
| md_change_log | Rarely queried, large text (already in DB) |
| amd_change_log | Rarely queried, large text (already in DB) |
| rsc_change_log | Rarely queried, large text (already in DB) |
| amd_by_change_log | Rarely queried, large text (already in DB) |
| Live?_change_log | Rarely queried, large text |
| amending_change_log | ✓ Added 2025-12-23 |
| amended_by_change_log | ✓ Added 2025-12-23 |

### Descriptions (Narrative Text)
| Donor Field | Reason |
|-------------|--------|
| enacted_by_description | Large narrative text |
| 🔺_amd_short_desc | Amendment summary |
| 🔺_amd_long_desc | Amendment detail |
| 🔻_amd_short_desc | Amended by summary |
| 🔻_amd_long_desc | Amended by detail |
| 🔺_rsc_short_desc | Revocation summary |
| 🔺_rsc_long_desc | Revocation detail |
| 🔻_rsc_short_desc | Revoked by summary |
| 🔻_rsc_long_desc | Revoked by detail |

### Internal/Display (Not Needed)
| Donor Field | Reason |
|-------------|--------|
| __e_register | Internal Airtable tracking |
| __hs_register | Internal Airtable tracking |
| __hr_register | Internal Airtable tracking |
| title_en_year | Computed - use Ash calculation |
| title_en_year_number | Computed - use Ash calculation |
| publication_date | Covered by md_date |
| md_modified | From legislation.gov.uk |
| md_checked | Internal workflow flag |
| amendments_checked | Internal workflow flag |
| enact_error | Internal error tracking |

---

## Questions to Resolve

1. Which fields should display in Parse Review modal?
2. Which fields are editable vs read-only?
3. Should we show JSONB fields (duty_holder etc.) expanded or collapsed?
4. How to display array fields (amending, amended_by)?
5. What validation rules for mandatory fields?

## Notes

- Donor uses mixed naming (Title_EN, Live?, Geo_Extent)
- DB uses snake_case (title_en, live, geo_extent)
- @translator in donor maps donor → supabase/db format
- Function is law purpose (Making, Amending, etc.) NOT a role

**Ended**: 2025-12-23 ~18:30

## Summary
- Completed: 4 of 6 todos (partial revocation, extent fields, md_date, modal labels)
- Files touched: staged_parser.ex, extent.ex, metadata.ex, scrape_controller.ex, uk_lrt.ex, ParseReviewModal.svelte
- Outcome: Fixed Status (live), Geographic Extent (geo_extent/geo_region/geo_detail), and Primary Date (md_date) fields in ParseReviewModal
- Next: Function section fields not populating (shown in screenshot)
