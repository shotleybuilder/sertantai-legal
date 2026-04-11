-- Delta Export: dev → prod
-- Generated: 2026-04-11T17:33:31.699410Z
-- Source: sertantai_legal_dev
--
-- This file is idempotent (INSERT ... ON CONFLICT DO UPDATE).
-- Apply with: TARGET_DATABASE_URL=... mix run ../scripts/sync/apply_delta.exs delta_2026-04-11T17-33-31.sql

BEGIN;

-- ══════════════════════════════════════════════════
-- uk_lrt (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "uk_lrt" ("id", "family", "family_ii", "name", "title_en", "year", "number", "acronym", "old_style_number", "type_desc", "type_code", "type_class", "domain", "live", "live_description", "live_from_changes", "geo_extent", "geo_region", "geo_detail", "md_restrict_extent", "duty_holder", "power_holder", "rights_holder", "responsibility_holder", "purpose", "function", "popimar", "popimar_details", "si_code", "md_subjects", "role", "role_gvt", "role_details", "role_gvt_details", "duty_type", "duty_type_article", "article_duty_type", "duties", "rights", "responsibilities", "powers", "fitness_person", "fitness_process", "fitness_place", "fitness_plant", "fitness_property", "fitness_sector", "fitness", "tags", "md_description", "md_total_paras", "md_body_paras", "md_schedule_paras", "md_attachment_paras", "md_images", "amending", "amended_by", "rescinding", "rescinded_by", "enacting", "enacted_by", "enacted_by_meta", "linked_amending", "linked_amended_by", "linked_rescinding", "linked_rescinded_by", "linked_enacted_by", "is_amending", "is_rescinding", "is_enacting", "is_making", "is_commencing", "making_confidence", "making_classification", "making_detection_tier", "making_detection_signals", "🔺🔻_stats_self_affects_count", "🔺🔻_stats_self_affects_count_per_law_detailed", "🔺_stats_affects_count", "🔺_stats_affected_laws_count", "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count", "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count", "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law", "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law", "amending_change_log", "amended_by_change_log", "record_change_log", "md_date", "md_made_date", "md_enactment_date", "md_coming_into_force_date", "md_dct_valid_date", "md_modified", "md_restrict_start_date", "latest_amend_date", "latest_change_date", "latest_rescind_date")
VALUES ('a4652be0-1747-4b86-9b25-8e58c998d50b', '💚 MARINE & RIVERINE', NULL, 'UK_wsi_2011_923', NULL, 2011, '923', NULL, NULL, 'Wales Statutory Instrument 2018-date', 'wsi', NULL, ARRAY['environment'], '✔ In force', NULL, NULL, NULL, NULL, NULL, NULL, NULL, '{"Gvt: Authority: Enforcement":true,"Gvt: Authority: Licensing":true,"Gvt: Judiciary":true}'::jsonb, '{"Ind: Person":true}'::jsonb, '{"EU: Commission":true,"Gvt: Authority":true,"Gvt: Authority: Enforcement":true,"Gvt: Authority: Licensing":true,"Gvt: Judiciary":true}'::jsonb, '{"values":["Enactment+Citation+Commencement","Interpretation+Definition","Application+Scope","Offence","Defence+Appeal"]}'::jsonb, '{"Making":true}'::jsonb, '{"\"Permit":true,"Authorisation":true,"License\"":true}'::jsonb, '{"articles":["regulation/3","regulation/5"],"categories":["Permit, Authorisation, License"],"entries":[{"article":"regulation/3","category":"Permit, Authorisation, License"},{"article":"regulation/5","category":"Permit, Authorisation, License"}]}'::jsonb, '{"values":["TRIBUNALS AND INQUIRIES"]}'::jsonb, NULL, ARRAY['Ind: Person'], '{"EU: Commission":true,"Gvt: Authority":true,"Gvt: Authority: Enforcement":true,"Gvt: Authority: Licensing":true,"Gvt: Judiciary":true,"Gvt: Minister":true}'::jsonb, '{"articles":["https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-enforcement-notices-stop-notices-and-emergency-safety-notices","https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-variation-suspension-or-revocation-of-marine-licence","https://legislation.gov.uk/wsi/2011/923/regulation/3","https://legislation.gov.uk/wsi/2011/923/regulation/4"],"entries":[{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-enforcement-notices-stop-notices-and-emergency-safety-notices","role":"Ind: Person"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-variation-suspension-or-revocation-of-marine-licence","role":"Ind: Person"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/3","role":"Ind: Person"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/4","role":"Ind: Person"}],"roles":["Ind: Person"]}'::jsonb, '{"articles":["https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-enforcement-notices-stop-notices-and-emergency-safety-notices","https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-variation-suspension-or-revocation-of-marine-licence","https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","https://legislation.gov.uk/wsi/2011/923/crossheading/application","https://legislation.gov.uk/wsi/2011/923/crossheading/recovery-of-sums-payable","https://legislation.gov.uk/wsi/2011/923/regulation/2","https://legislation.gov.uk/wsi/2011/923/regulation/3","https://legislation.gov.uk/wsi/2011/923/regulation/4","https://legislation.gov.uk/wsi/2011/923/regulation/5","https://legislation.gov.uk/wsi/2011/923/regulation/6"],"entries":[{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-enforcement-notices-stop-notices-and-emergency-safety-notices","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-variation-suspension-or-revocation-of-marine-licence","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","role":"EU: Commission"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","role":"Gvt: Authority"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","role":"Gvt: Authority: Enforcement"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","role":"Gvt: Authority: Licensing"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/application","role":"Gvt: Authority: Enforcement"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/application","role":"Gvt: Authority: Licensing"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/application","role":"Gvt: Minister"},{"article":"https://legislation.gov.uk/wsi/2011/923/crossheading/recovery-of-sums-payable","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/2","role":"Gvt: Authority: Enforcement"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/2","role":"Gvt: Authority: Licensing"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/2","role":"Gvt: Minister"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/3","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/4","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/5","role":"EU: Commission"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/5","role":"Gvt: Authority"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/5","role":"Gvt: Authority: Enforcement"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/5","role":"Gvt: Authority: Licensing"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/5","role":"Gvt: Judiciary"},{"article":"https://legislation.gov.uk/wsi/2011/923/regulation/6","role":"Gvt: Judiciary"}],"roles":["EU: Commission","Gvt: Authority","Gvt: Authority: Enforcement","Gvt: Authority: Licensing","Gvt: Judiciary","Gvt: Minister"]}'::jsonb, '{"values":["Right","Responsibility","Power"]}'::jsonb, '[Right]
https://legislation.gov.uk/wsi/2011/923/regulation/3
https://legislation.gov.uk/wsi/2011/923/regulation/4

[Responsibility]
https://legislation.gov.uk/wsi/2011/923/regulation/5
https://legislation.gov.uk/wsi/2011/923/regulation/6

[Power]
https://legislation.gov.uk/wsi/2011/923/regulation/3
https://legislation.gov.uk/wsi/2011/923/regulation/4
https://legislation.gov.uk/wsi/2011/923/regulation/5

[Enactment, Citation, Commencement]
https://legislation.gov.uk/wsi/2011/923/regulation/1

[Interpretation, Definition]
https://legislation.gov.uk/wsi/2011/923/regulation/1
https://legislation.gov.uk/wsi/2011/923/regulation/2

[Application, Scope]
https://legislation.gov.uk/wsi/2011/923/regulation/2

[Offence]
https://legislation.gov.uk/wsi/2011/923/regulation/5

[Defence, Appeal]
https://legislation.gov.uk/wsi/2011/923/regulation/3
https://legislation.gov.uk/wsi/2011/923/regulation/4
https://legislation.gov.uk/wsi/2011/923/regulation/5', 'https://legislation.gov.uk/wsi/2011/923/crossheading/title-commencement-and-interpretation
Enactment, Citation, Commencement; Interpretation, Definition

https://legislation.gov.uk/wsi/2011/923/regulation/1
Enactment, Citation, Commencement; Interpretation, Definition

https://legislation.gov.uk/wsi/2011/923/crossheading/application
Application, Scope; Interpretation, Definition

https://legislation.gov.uk/wsi/2011/923/regulation/2
Application, Scope; Interpretation, Definition

https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-variation-suspension-or-revocation-of-marine-licence
Defence, Appeal; Power; Right

https://legislation.gov.uk/wsi/2011/923/regulation/3
Defence, Appeal; Power; Right

https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-against-enforcement-notices-stop-notices-and-emergency-safety-notices
Defence, Appeal; Power; Right

https://legislation.gov.uk/wsi/2011/923/regulation/4
Defence, Appeal; Power; Right

https://legislation.gov.uk/wsi/2011/923/crossheading/appeals-—-further-provisions
Defence, Appeal; Offence; Power; Responsibility

https://legislation.gov.uk/wsi/2011/923/regulation/5
Defence, Appeal; Offence; Power; Responsibility

https://legislation.gov.uk/wsi/2011/923/crossheading/recovery-of-sums-payable
Responsibility

https://legislation.gov.uk/wsi/2011/923/regulation/6
Responsibility', NULL, '{"articles":["regulation/3","regulation/4"],"entries":[{"article":"regulation/3","clause":"A person to whom a notice under section 72 of the 2009 Act (notice varying, suspending or revoking a marine licence, or extending a period of suspension) has been issued may","duty_type":"RIGHT","holder":"Ind: Person"},{"article":"regulation/4","clause":"A person to whom any of the notices referred to in paragraph (2) has been issued may","duty_type":"RIGHT","holder":"Ind: Person"}],"holders":["Ind: Person"]}'::jsonb, '{"articles":["regulation/5","regulation/6"],"entries":[{"article":"regulation/5","clause":"commission of an offence the authority must","duty_type":"RESPONSIBILITY","holder":"EU: Commission"},{"article":"regulation/5","clause":"the authority must","duty_type":"RESPONSIBILITY","holder":"Gvt: Authority"},{"article":"regulation/5","clause":"enforcement authority (as appropriate), and—","duty_type":"RESPONSIBILITY","holder":"Gvt: Authority: Enforcement"},{"article":"regulation/5","clause":"licensing authority or enforcement authority (as appropriate), and—","duty_type":"RESPONSIBILITY","holder":"Gvt: Authority: Licensing"},{"article":"regulation/5","clause":"Tribunal must","duty_type":"RESPONSIBILITY","holder":"Gvt: Judiciary"},{"article":"regulation/6","clause":"Tribunal must","duty_type":"RESPONSIBILITY","holder":"Gvt: Judiciary"}],"holders":["EU: Commission","Gvt: Authority","Gvt: Authority: Enforcement","Gvt: Authority: Licensing","Gvt: Judiciary"]}'::jsonb, '{"articles":["regulation/3","regulation/4","regulation/5"],"entries":[{"article":"regulation/5","clause":"enforcement authority (as appropriate), and—","duty_type":"POWER","holder":"Gvt: Authority: Enforcement"},{"article":"regulation/5","clause":"licensing authority or enforcement authority (as appropriate), and—","duty_type":"POWER","holder":"Gvt: Authority: Licensing"},{"article":"regulation/3","clause":"Tribunal may","duty_type":"POWER","holder":"Gvt: Judiciary"},{"article":"regulation/4","clause":"Tribunal may","duty_type":"POWER","holder":"Gvt: Judiciary"},{"article":"regulation/5","clause":"Tribunal may","duty_type":"POWER","holder":"Gvt: Judiciary"}],"holders":["Gvt: Authority: Enforcement","Gvt: Authority: Licensing","Gvt: Judiciary"]}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ARRAY['Appeals', 'Licensing', 'Marine', 'Notices', 'Regulations', 'Wales'], NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, true, false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2011-04-06'::date, NULL, NULL, NULL, NULL, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "family" = EXCLUDED."family",
      "family_ii" = EXCLUDED."family_ii",
      "name" = EXCLUDED."name",
      "title_en" = EXCLUDED."title_en",
      "year" = EXCLUDED."year",
      "number" = EXCLUDED."number",
      "acronym" = EXCLUDED."acronym",
      "old_style_number" = EXCLUDED."old_style_number",
      "type_desc" = EXCLUDED."type_desc",
      "type_code" = EXCLUDED."type_code",
      "type_class" = EXCLUDED."type_class",
      "domain" = EXCLUDED."domain",
      "live" = EXCLUDED."live",
      "live_description" = EXCLUDED."live_description",
      "live_from_changes" = EXCLUDED."live_from_changes",
      "geo_extent" = EXCLUDED."geo_extent",
      "geo_region" = EXCLUDED."geo_region",
      "geo_detail" = EXCLUDED."geo_detail",
      "md_restrict_extent" = EXCLUDED."md_restrict_extent",
      "duty_holder" = EXCLUDED."duty_holder",
      "power_holder" = EXCLUDED."power_holder",
      "rights_holder" = EXCLUDED."rights_holder",
      "responsibility_holder" = EXCLUDED."responsibility_holder",
      "purpose" = EXCLUDED."purpose",
      "function" = EXCLUDED."function",
      "popimar" = EXCLUDED."popimar",
      "popimar_details" = EXCLUDED."popimar_details",
      "si_code" = EXCLUDED."si_code",
      "md_subjects" = EXCLUDED."md_subjects",
      "role" = EXCLUDED."role",
      "role_gvt" = EXCLUDED."role_gvt",
      "role_details" = EXCLUDED."role_details",
      "role_gvt_details" = EXCLUDED."role_gvt_details",
      "duty_type" = EXCLUDED."duty_type",
      "duty_type_article" = EXCLUDED."duty_type_article",
      "article_duty_type" = EXCLUDED."article_duty_type",
      "duties" = EXCLUDED."duties",
      "rights" = EXCLUDED."rights",
      "responsibilities" = EXCLUDED."responsibilities",
      "powers" = EXCLUDED."powers",
      "fitness_person" = EXCLUDED."fitness_person",
      "fitness_process" = EXCLUDED."fitness_process",
      "fitness_place" = EXCLUDED."fitness_place",
      "fitness_plant" = EXCLUDED."fitness_plant",
      "fitness_property" = EXCLUDED."fitness_property",
      "fitness_sector" = EXCLUDED."fitness_sector",
      "fitness" = EXCLUDED."fitness",
      "tags" = EXCLUDED."tags",
      "md_description" = EXCLUDED."md_description",
      "md_total_paras" = EXCLUDED."md_total_paras",
      "md_body_paras" = EXCLUDED."md_body_paras",
      "md_schedule_paras" = EXCLUDED."md_schedule_paras",
      "md_attachment_paras" = EXCLUDED."md_attachment_paras",
      "md_images" = EXCLUDED."md_images",
      "amending" = EXCLUDED."amending",
      "amended_by" = EXCLUDED."amended_by",
      "rescinding" = EXCLUDED."rescinding",
      "rescinded_by" = EXCLUDED."rescinded_by",
      "enacting" = EXCLUDED."enacting",
      "enacted_by" = EXCLUDED."enacted_by",
      "enacted_by_meta" = EXCLUDED."enacted_by_meta",
      "linked_amending" = EXCLUDED."linked_amending",
      "linked_amended_by" = EXCLUDED."linked_amended_by",
      "linked_rescinding" = EXCLUDED."linked_rescinding",
      "linked_rescinded_by" = EXCLUDED."linked_rescinded_by",
      "linked_enacted_by" = EXCLUDED."linked_enacted_by",
      "is_amending" = EXCLUDED."is_amending",
      "is_rescinding" = EXCLUDED."is_rescinding",
      "is_enacting" = EXCLUDED."is_enacting",
      "is_making" = EXCLUDED."is_making",
      "is_commencing" = EXCLUDED."is_commencing",
      "making_confidence" = EXCLUDED."making_confidence",
      "making_classification" = EXCLUDED."making_classification",
      "making_detection_tier" = EXCLUDED."making_detection_tier",
      "making_detection_signals" = EXCLUDED."making_detection_signals",
      "🔺🔻_stats_self_affects_count" = EXCLUDED."🔺🔻_stats_self_affects_count",
      "🔺🔻_stats_self_affects_count_per_law_detailed" = EXCLUDED."🔺🔻_stats_self_affects_count_per_law_detailed",
      "🔺_stats_affects_count" = EXCLUDED."🔺_stats_affects_count",
      "🔺_stats_affected_laws_count" = EXCLUDED."🔺_stats_affected_laws_count",
      "🔻_stats_affected_by_count" = EXCLUDED."🔻_stats_affected_by_count",
      "🔻_stats_affected_by_laws_count" = EXCLUDED."🔻_stats_affected_by_laws_count",
      "🔺_stats_rescinding_laws_count" = EXCLUDED."🔺_stats_rescinding_laws_count",
      "🔻_stats_rescinded_by_laws_count" = EXCLUDED."🔻_stats_rescinded_by_laws_count",
      "🔺_affects_stats_per_law" = EXCLUDED."🔺_affects_stats_per_law",
      "🔺_rescinding_stats_per_law" = EXCLUDED."🔺_rescinding_stats_per_law",
      "🔻_affected_by_stats_per_law" = EXCLUDED."🔻_affected_by_stats_per_law",
      "🔻_rescinded_by_stats_per_law" = EXCLUDED."🔻_rescinded_by_stats_per_law",
      "amending_change_log" = EXCLUDED."amending_change_log",
      "amended_by_change_log" = EXCLUDED."amended_by_change_log",
      "record_change_log" = EXCLUDED."record_change_log",
      "md_date" = EXCLUDED."md_date",
      "md_made_date" = EXCLUDED."md_made_date",
      "md_enactment_date" = EXCLUDED."md_enactment_date",
      "md_coming_into_force_date" = EXCLUDED."md_coming_into_force_date",
      "md_dct_valid_date" = EXCLUDED."md_dct_valid_date",
      "md_modified" = EXCLUDED."md_modified",
      "md_restrict_start_date" = EXCLUDED."md_restrict_start_date",
      "latest_amend_date" = EXCLUDED."latest_amend_date",
      "latest_change_date" = EXCLUDED."latest_change_date",
      "latest_rescind_date" = EXCLUDED."latest_rescind_date";

INSERT INTO "uk_lrt" ("id", "family", "family_ii", "name", "title_en", "year", "number", "acronym", "old_style_number", "type_desc", "type_code", "type_class", "domain", "live", "live_description", "live_from_changes", "geo_extent", "geo_region", "geo_detail", "md_restrict_extent", "duty_holder", "power_holder", "rights_holder", "responsibility_holder", "purpose", "function", "popimar", "popimar_details", "si_code", "md_subjects", "role", "role_gvt", "role_details", "role_gvt_details", "duty_type", "duty_type_article", "article_duty_type", "duties", "rights", "responsibilities", "powers", "fitness_person", "fitness_process", "fitness_place", "fitness_plant", "fitness_property", "fitness_sector", "fitness", "tags", "md_description", "md_total_paras", "md_body_paras", "md_schedule_paras", "md_attachment_paras", "md_images", "amending", "amended_by", "rescinding", "rescinded_by", "enacting", "enacted_by", "enacted_by_meta", "linked_amending", "linked_amended_by", "linked_rescinding", "linked_rescinded_by", "linked_enacted_by", "is_amending", "is_rescinding", "is_enacting", "is_making", "is_commencing", "making_confidence", "making_classification", "making_detection_tier", "making_detection_signals", "🔺🔻_stats_self_affects_count", "🔺🔻_stats_self_affects_count_per_law_detailed", "🔺_stats_affects_count", "🔺_stats_affected_laws_count", "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count", "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count", "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law", "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law", "amending_change_log", "amended_by_change_log", "record_change_log", "md_date", "md_made_date", "md_enactment_date", "md_coming_into_force_date", "md_dct_valid_date", "md_modified", "md_restrict_start_date", "latest_amend_date", "latest_change_date", "latest_rescind_date")
VALUES ('2135fe9f-4f02-4d08-a8f9-48d875f02f81', '💙 HEALTH: Coronavirus', '💙 HEALTH: Public', 'UK_ssi_2024_246', 'Coronavirus (Recovery and Reform) (Scotland) Act 2022 (Early Expiry of Provisions) Regulations', 2024, '246', 'CRRSAEEPR', NULL, 'Scottish Statutory Instrument', 'ssi', 'Regulation', ARRAY['health_safety'], '✔ In force', NULL, NULL, 'UK', ARRAY['England', 'Wales', 'Scotland', 'Northern Ireland'], '🇬🇧 E+W+S+NI
All provisions', NULL, NULL, NULL, NULL, NULL, '{"values":["Enactment+Citation+Commencement","Interpretation+Definition","Extent","Offence","Enforcement+Prosecution"]}'::jsonb, '{"Amending Maker":true}'::jsonb, NULL, NULL, '{"values":["CRIMINAL PROCEDURE","PRISONS"]}'::jsonb, NULL, '{}', NULL, NULL, NULL, NULL, '[Enactment, Citation, Commencement]
https://legislation.gov.uk/ssi/2024/246/regulation/1

[Interpretation, Definition]
https://legislation.gov.uk/ssi/2024/246/regulation/1

[Extent]
https://legislation.gov.uk/ssi/2024/246/regulation/2

[Offence]
https://legislation.gov.uk/ssi/2024/246/regulation/2
https://legislation.gov.uk/ssi/2024/246/regulation/3

[Enforcement, Prosecution]
https://legislation.gov.uk/ssi/2024/246/regulation/2', 'https://legislation.gov.uk/ssi/2024/246/crossheading/citation-commencement-and-interpretation
Enactment, Citation, Commencement; Interpretation, Definition

https://legislation.gov.uk/ssi/2024/246/regulation/1
Enactment, Citation, Commencement; Interpretation, Definition

https://legislation.gov.uk/ssi/2024/246/crossheading/expiry-of-provisions-of-the-2022-act
Enforcement, Prosecution; Extent; Offence

https://legislation.gov.uk/ssi/2024/246/regulation/2
Enforcement, Prosecution; Extent; Offence

https://legislation.gov.uk/ssi/2024/246/crossheading/saving-provision
Offence

https://legislation.gov.uk/ssi/2024/246/regulation/3
Offence', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, ARRAY['Coronavirus', 'Recovery', 'Reform', 'Scotland', 'Act', 'Early', 'Expiry', 'Provisions', 'Regulations'], 'These Regulations modify the expiry dates for certain temporary measures which are contained in the Coronavirus (Recovery and Reform) (Scotland) Act 2022 (“the 2022 Act”).', 3, 3, 0, 0, 0, ARRAY['UK_asp_2022_8'], NULL, NULL, NULL, NULL, ARRAY['UK_asp_2022_8'], NULL, ARRAY['UK_asp_2022_8'], NULL, NULL, NULL, ARRAY['UK_asp_2022_8'], true, NULL, NULL, false, false, NULL, NULL, NULL, NULL, 0, NULL, 3, 1, 0, 0, 0, 0, '{"UK_asp_2022_8":{"count":3,"details":[{"affect":null,"applied":"Not yet","target":"sch.  para. 21 expires"},{"affect":null,"applied":"Not yet","target":"sch.  para. 25 expires"},{"affect":null,"applied":"Not yet","target":"sch.  para. 26 expires"}],"name":"UK_asp_2022_8","title":"Coronavirus (Recovery and Reform) (Scotland) Act 2022","url":"https://legislation.gov.uk/id/asp/2022/8"}}'::jsonb, NULL, NULL, NULL, NULL, NULL, NULL, '2024-11-29'::date, '2024-09-17'::date, NULL, '2024-11-29'::date, NULL, '2024-09-19'::date, NULL, NULL, NULL, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "family" = EXCLUDED."family",
      "family_ii" = EXCLUDED."family_ii",
      "name" = EXCLUDED."name",
      "title_en" = EXCLUDED."title_en",
      "year" = EXCLUDED."year",
      "number" = EXCLUDED."number",
      "acronym" = EXCLUDED."acronym",
      "old_style_number" = EXCLUDED."old_style_number",
      "type_desc" = EXCLUDED."type_desc",
      "type_code" = EXCLUDED."type_code",
      "type_class" = EXCLUDED."type_class",
      "domain" = EXCLUDED."domain",
      "live" = EXCLUDED."live",
      "live_description" = EXCLUDED."live_description",
      "live_from_changes" = EXCLUDED."live_from_changes",
      "geo_extent" = EXCLUDED."geo_extent",
      "geo_region" = EXCLUDED."geo_region",
      "geo_detail" = EXCLUDED."geo_detail",
      "md_restrict_extent" = EXCLUDED."md_restrict_extent",
      "duty_holder" = EXCLUDED."duty_holder",
      "power_holder" = EXCLUDED."power_holder",
      "rights_holder" = EXCLUDED."rights_holder",
      "responsibility_holder" = EXCLUDED."responsibility_holder",
      "purpose" = EXCLUDED."purpose",
      "function" = EXCLUDED."function",
      "popimar" = EXCLUDED."popimar",
      "popimar_details" = EXCLUDED."popimar_details",
      "si_code" = EXCLUDED."si_code",
      "md_subjects" = EXCLUDED."md_subjects",
      "role" = EXCLUDED."role",
      "role_gvt" = EXCLUDED."role_gvt",
      "role_details" = EXCLUDED."role_details",
      "role_gvt_details" = EXCLUDED."role_gvt_details",
      "duty_type" = EXCLUDED."duty_type",
      "duty_type_article" = EXCLUDED."duty_type_article",
      "article_duty_type" = EXCLUDED."article_duty_type",
      "duties" = EXCLUDED."duties",
      "rights" = EXCLUDED."rights",
      "responsibilities" = EXCLUDED."responsibilities",
      "powers" = EXCLUDED."powers",
      "fitness_person" = EXCLUDED."fitness_person",
      "fitness_process" = EXCLUDED."fitness_process",
      "fitness_place" = EXCLUDED."fitness_place",
      "fitness_plant" = EXCLUDED."fitness_plant",
      "fitness_property" = EXCLUDED."fitness_property",
      "fitness_sector" = EXCLUDED."fitness_sector",
      "fitness" = EXCLUDED."fitness",
      "tags" = EXCLUDED."tags",
      "md_description" = EXCLUDED."md_description",
      "md_total_paras" = EXCLUDED."md_total_paras",
      "md_body_paras" = EXCLUDED."md_body_paras",
      "md_schedule_paras" = EXCLUDED."md_schedule_paras",
      "md_attachment_paras" = EXCLUDED."md_attachment_paras",
      "md_images" = EXCLUDED."md_images",
      "amending" = EXCLUDED."amending",
      "amended_by" = EXCLUDED."amended_by",
      "rescinding" = EXCLUDED."rescinding",
      "rescinded_by" = EXCLUDED."rescinded_by",
      "enacting" = EXCLUDED."enacting",
      "enacted_by" = EXCLUDED."enacted_by",
      "enacted_by_meta" = EXCLUDED."enacted_by_meta",
      "linked_amending" = EXCLUDED."linked_amending",
      "linked_amended_by" = EXCLUDED."linked_amended_by",
      "linked_rescinding" = EXCLUDED."linked_rescinding",
      "linked_rescinded_by" = EXCLUDED."linked_rescinded_by",
      "linked_enacted_by" = EXCLUDED."linked_enacted_by",
      "is_amending" = EXCLUDED."is_amending",
      "is_rescinding" = EXCLUDED."is_rescinding",
      "is_enacting" = EXCLUDED."is_enacting",
      "is_making" = EXCLUDED."is_making",
      "is_commencing" = EXCLUDED."is_commencing",
      "making_confidence" = EXCLUDED."making_confidence",
      "making_classification" = EXCLUDED."making_classification",
      "making_detection_tier" = EXCLUDED."making_detection_tier",
      "making_detection_signals" = EXCLUDED."making_detection_signals",
      "🔺🔻_stats_self_affects_count" = EXCLUDED."🔺🔻_stats_self_affects_count",
      "🔺🔻_stats_self_affects_count_per_law_detailed" = EXCLUDED."🔺🔻_stats_self_affects_count_per_law_detailed",
      "🔺_stats_affects_count" = EXCLUDED."🔺_stats_affects_count",
      "🔺_stats_affected_laws_count" = EXCLUDED."🔺_stats_affected_laws_count",
      "🔻_stats_affected_by_count" = EXCLUDED."🔻_stats_affected_by_count",
      "🔻_stats_affected_by_laws_count" = EXCLUDED."🔻_stats_affected_by_laws_count",
      "🔺_stats_rescinding_laws_count" = EXCLUDED."🔺_stats_rescinding_laws_count",
      "🔻_stats_rescinded_by_laws_count" = EXCLUDED."🔻_stats_rescinded_by_laws_count",
      "🔺_affects_stats_per_law" = EXCLUDED."🔺_affects_stats_per_law",
      "🔺_rescinding_stats_per_law" = EXCLUDED."🔺_rescinding_stats_per_law",
      "🔻_affected_by_stats_per_law" = EXCLUDED."🔻_affected_by_stats_per_law",
      "🔻_rescinded_by_stats_per_law" = EXCLUDED."🔻_rescinded_by_stats_per_law",
      "amending_change_log" = EXCLUDED."amending_change_log",
      "amended_by_change_log" = EXCLUDED."amended_by_change_log",
      "record_change_log" = EXCLUDED."record_change_log",
      "md_date" = EXCLUDED."md_date",
      "md_made_date" = EXCLUDED."md_made_date",
      "md_enactment_date" = EXCLUDED."md_enactment_date",
      "md_coming_into_force_date" = EXCLUDED."md_coming_into_force_date",
      "md_dct_valid_date" = EXCLUDED."md_dct_valid_date",
      "md_modified" = EXCLUDED."md_modified",
      "md_restrict_start_date" = EXCLUDED."md_restrict_start_date",
      "latest_amend_date" = EXCLUDED."latest_amend_date",
      "latest_change_date" = EXCLUDED."latest_change_date",
      "latest_rescind_date" = EXCLUDED."latest_rescind_date";


-- ══════════════════════════════════════════════════
-- lat (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "lat" ("section_id", "law_name", "sort_key", "position", "section_type", "hierarchy_path", "depth", "part", "chapter", "heading_group", "provision", "paragraph", "sub_paragraph", "schedule", "text", "language", "extent_code", "amendment_count", "modification_count", "commencement_count", "extent_count", "editorial_count", "embedding", "embedding_model", "embedded_at", "token_ids", "tokenizer_model", "legacy_id", "law_id")
VALUES ('UK_apni_1969_6:pt.1', 'UK_apni_1969_6', '000.000.000~', 2, 'part', 'part.1', 1, '1', NULL, NULL, NULL, NULL, NULL, NULL, 'PART I GENERAL DUTIES OF MINE OWNERS', 'en', 'NI', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'UK_MANI_apni_1969_6_1______NI', '80de9a23-6a92-446a-8297-917357eb8663')
ON CONFLICT ("section_id") DO UPDATE SET
  "law_name" = EXCLUDED."law_name",
      "sort_key" = EXCLUDED."sort_key",
      "position" = EXCLUDED."position",
      "section_type" = EXCLUDED."section_type",
      "hierarchy_path" = EXCLUDED."hierarchy_path",
      "depth" = EXCLUDED."depth",
      "part" = EXCLUDED."part",
      "chapter" = EXCLUDED."chapter",
      "heading_group" = EXCLUDED."heading_group",
      "provision" = EXCLUDED."provision",
      "paragraph" = EXCLUDED."paragraph",
      "sub_paragraph" = EXCLUDED."sub_paragraph",
      "schedule" = EXCLUDED."schedule",
      "text" = EXCLUDED."text",
      "language" = EXCLUDED."language",
      "extent_code" = EXCLUDED."extent_code",
      "amendment_count" = EXCLUDED."amendment_count",
      "modification_count" = EXCLUDED."modification_count",
      "commencement_count" = EXCLUDED."commencement_count",
      "extent_count" = EXCLUDED."extent_count",
      "editorial_count" = EXCLUDED."editorial_count",
      "embedding" = EXCLUDED."embedding",
      "embedding_model" = EXCLUDED."embedding_model",
      "embedded_at" = EXCLUDED."embedded_at",
      "token_ids" = EXCLUDED."token_ids",
      "tokenizer_model" = EXCLUDED."tokenizer_model",
      "legacy_id" = EXCLUDED."legacy_id",
      "law_id" = EXCLUDED."law_id";

INSERT INTO "lat" ("section_id", "law_name", "sort_key", "position", "section_type", "hierarchy_path", "depth", "part", "chapter", "heading_group", "provision", "paragraph", "sub_paragraph", "schedule", "text", "language", "extent_code", "amendment_count", "modification_count", "commencement_count", "extent_count", "editorial_count", "embedding", "embedding_model", "embedded_at", "token_ids", "tokenizer_model", "legacy_id", "law_id")
VALUES ('UK_apni_1969_6:title.1', 'UK_apni_1969_6', '000.000.000~', 1, 'title', NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'Mines Act (Northern Ireland) 1969
1969 CHAPTER 6
An Act to make fresh provision with respect to the management and control of mines and for securing the safety, health and welfare of persons employed thereat; to regulate the employment thereat of women and of young persons and certain other persons under the age of twenty-one years; to enable certain tips to be regulated and to require the fencing of abandoned and disused mines; to amend the Quarries Act (Northern Ireland) 1927; and for purposes connected with the matters aforesaid.
[24th June 1969]', 'en', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'UK_MANI_apni_1969_6_____', '80de9a23-6a92-446a-8297-917357eb8663')
ON CONFLICT ("section_id") DO UPDATE SET
  "law_name" = EXCLUDED."law_name",
      "sort_key" = EXCLUDED."sort_key",
      "position" = EXCLUDED."position",
      "section_type" = EXCLUDED."section_type",
      "hierarchy_path" = EXCLUDED."hierarchy_path",
      "depth" = EXCLUDED."depth",
      "part" = EXCLUDED."part",
      "chapter" = EXCLUDED."chapter",
      "heading_group" = EXCLUDED."heading_group",
      "provision" = EXCLUDED."provision",
      "paragraph" = EXCLUDED."paragraph",
      "sub_paragraph" = EXCLUDED."sub_paragraph",
      "schedule" = EXCLUDED."schedule",
      "text" = EXCLUDED."text",
      "language" = EXCLUDED."language",
      "extent_code" = EXCLUDED."extent_code",
      "amendment_count" = EXCLUDED."amendment_count",
      "modification_count" = EXCLUDED."modification_count",
      "commencement_count" = EXCLUDED."commencement_count",
      "extent_count" = EXCLUDED."extent_count",
      "editorial_count" = EXCLUDED."editorial_count",
      "embedding" = EXCLUDED."embedding",
      "embedding_model" = EXCLUDED."embedding_model",
      "embedded_at" = EXCLUDED."embedded_at",
      "token_ids" = EXCLUDED."token_ids",
      "tokenizer_model" = EXCLUDED."tokenizer_model",
      "legacy_id" = EXCLUDED."legacy_id",
      "law_id" = EXCLUDED."law_id";


-- ══════════════════════════════════════════════════
-- amendment_annotations (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "amendment_annotations" ("id", "law_name", "code", "code_type", "source", "text", "affected_sections", "law_id")
VALUES ('UK_apni_1969_6:amendment:2', 'UK_apni_1969_6', 'F2', 'amendment', 'csv_import', 'F2 F2 S. 28 repealed (1.2.2017) by The Mines Regulations (Northern Ireland) 2016 (S.R. 2016/427)', ARRAY['UK_apni_1969_6:s.28'], '80de9a23-6a92-446a-8297-917357eb8663')
ON CONFLICT ("id") DO UPDATE SET
  "law_name" = EXCLUDED."law_name",
      "code" = EXCLUDED."code",
      "code_type" = EXCLUDED."code_type",
      "source" = EXCLUDED."source",
      "text" = EXCLUDED."text",
      "affected_sections" = EXCLUDED."affected_sections",
      "law_id" = EXCLUDED."law_id";

INSERT INTO "amendment_annotations" ("id", "law_name", "code", "code_type", "source", "text", "affected_sections", "law_id")
VALUES ('UK_apni_1969_6:amendment:1', 'UK_apni_1969_6', 'F1', 'amendment', 'csv_import', 'F1 F1 Ss. 1-20 repealed (1.2.2017) by The Mines Regulations (Northern Ireland) 2016 (S.R. 2016/427)', ARRAY['UK_apni_1969_6:s.1', 'UK_apni_1969_6:s.2', 'UK_apni_1969_6:s.3', 'UK_apni_1969_6:s.4', 'UK_apni_1969_6:s.5', 'UK_apni_1969_6:s.6', 'UK_apni_1969_6:s.7', 'UK_apni_1969_6:s.8', 'UK_apni_1969_6:s.9', 'UK_apni_1969_6:s.10', 'UK_apni_1969_6:s.11', 'UK_apni_1969_6:s.12', 'UK_apni_1969_6:s.13', 'UK_apni_1969_6:s.14', 'UK_apni_1969_6:s.15', 'UK_apni_1969_6:s.16', 'UK_apni_1969_6:s.17', 'UK_apni_1969_6:s.18', 'UK_apni_1969_6:s.19', 'UK_apni_1969_6:s.20'], '80de9a23-6a92-446a-8297-917357eb8663')
ON CONFLICT ("id") DO UPDATE SET
  "law_name" = EXCLUDED."law_name",
      "code" = EXCLUDED."code",
      "code_type" = EXCLUDED."code_type",
      "source" = EXCLUDED."source",
      "text" = EXCLUDED."text",
      "affected_sections" = EXCLUDED."affected_sections",
      "law_id" = EXCLUDED."law_id";


-- ══════════════════════════════════════════════════
-- scrape_sessions (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "scrape_sessions" ("id", "session_id", "year", "month", "day_from", "day_to", "type_code", "session_type", "status", "error_message", "total_fetched", "title_excluded_count", "group1_count", "group2_count", "group3_count", "persisted_count", "lat_total_inserted", "lat_total_annotations", "raw_file", "group1_file", "group2_file", "group3_file")
VALUES ('b773cbe1-b2cc-4226-93b9-3c1fc580de55', '2025-11-01-to-30', 2025, 11, 1, 30, NULL, 'scrape', 'categorized', NULL, 177, 54, 36, 85, 56, 0, 0, 0, '2025-11-01-to-30/raw.json', '2025-11-01-to-30/inc_w_si.json', '2025-11-01-to-30/inc_wo_si.json', '2025-11-01-to-30/exc.json')
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "year" = EXCLUDED."year",
      "month" = EXCLUDED."month",
      "day_from" = EXCLUDED."day_from",
      "day_to" = EXCLUDED."day_to",
      "type_code" = EXCLUDED."type_code",
      "session_type" = EXCLUDED."session_type",
      "status" = EXCLUDED."status",
      "error_message" = EXCLUDED."error_message",
      "total_fetched" = EXCLUDED."total_fetched",
      "title_excluded_count" = EXCLUDED."title_excluded_count",
      "group1_count" = EXCLUDED."group1_count",
      "group2_count" = EXCLUDED."group2_count",
      "group3_count" = EXCLUDED."group3_count",
      "persisted_count" = EXCLUDED."persisted_count",
      "lat_total_inserted" = EXCLUDED."lat_total_inserted",
      "lat_total_annotations" = EXCLUDED."lat_total_annotations",
      "raw_file" = EXCLUDED."raw_file",
      "group1_file" = EXCLUDED."group1_file",
      "group2_file" = EXCLUDED."group2_file",
      "group3_file" = EXCLUDED."group3_file";

INSERT INTO "scrape_sessions" ("id", "session_id", "year", "month", "day_from", "day_to", "type_code", "session_type", "status", "error_message", "total_fetched", "title_excluded_count", "group1_count", "group2_count", "group3_count", "persisted_count", "lat_total_inserted", "lat_total_annotations", "raw_file", "group1_file", "group2_file", "group3_file")
VALUES ('4180d58d-9b51-4d5c-8df6-e5922ccda69b', '2025-12-01-to-31', 2025, 12, 1, 31, NULL, 'scrape', 'categorized', NULL, 193, 28, 49, 112, 32, 0, 0, 0, '2025-12-01-to-31/raw.json', '2025-12-01-to-31/inc_w_si.json', '2025-12-01-to-31/inc_wo_si.json', '2025-12-01-to-31/exc.json')
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "year" = EXCLUDED."year",
      "month" = EXCLUDED."month",
      "day_from" = EXCLUDED."day_from",
      "day_to" = EXCLUDED."day_to",
      "type_code" = EXCLUDED."type_code",
      "session_type" = EXCLUDED."session_type",
      "status" = EXCLUDED."status",
      "error_message" = EXCLUDED."error_message",
      "total_fetched" = EXCLUDED."total_fetched",
      "title_excluded_count" = EXCLUDED."title_excluded_count",
      "group1_count" = EXCLUDED."group1_count",
      "group2_count" = EXCLUDED."group2_count",
      "group3_count" = EXCLUDED."group3_count",
      "persisted_count" = EXCLUDED."persisted_count",
      "lat_total_inserted" = EXCLUDED."lat_total_inserted",
      "lat_total_annotations" = EXCLUDED."lat_total_annotations",
      "raw_file" = EXCLUDED."raw_file",
      "group1_file" = EXCLUDED."group1_file",
      "group2_file" = EXCLUDED."group2_file",
      "group3_file" = EXCLUDED."group3_file";


-- ══════════════════════════════════════════════════
-- scrape_session_records (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "scrape_session_records" ("id", "session_id", "law_name", "group", "status", "selected", "parsed_data", "parse_count", "lat_inserted", "lat_deleted", "annotations_inserted", "parse_duration_ms", "parse_error")
VALUES ('00660082-3935-464f-a655-6355703e0fcc', '2025-05-01-to-31', 'UK_uksi_2025_622', 'group1', 'confirmed', false, '{"Family":"💚 PLANNING & INFRASTRUCTURE","Number":"622","SICode":["INFRASTRUCTURE PLANNING"],"Tags":["Immingham","Open","Cycle","Gas","Turbine","Amendment","Order"],"Title_EN":"Immingham Open Cycle Gas Turbine (Amendment) (No. 3) Order","Year":2025,"document_status":"final","leg_gov_uk_url":"https://www.legislation.gov.uk/uksi/2025/622","live":"✔ In force","live_description":"Current legislation","md_attachment_paras":0,"md_body_paras":9,"md_coming_into_force_date":"2025-05-23","md_date":"2025-05-23","md_description":"This Order amends the Immingham Open Cycle Gas Turbine Order 2020, a development consent order made under the Planning Act 2008, following an application made in accordance with the Infrastructure Planning (Changes to, and Revocation of, Development Consent Orders) Regulations 2011 for a non-material change under paragraph 2 of Schedule 6 to the Planning Act 2008.","md_images":0,"md_made_date":"2025-05-22","md_modified":"2025-05-29","md_schedule_paras":0,"md_total_paras":9,"name":"UK_uksi_2025_622","pdf_href":"http://www.legislation.gov.uk/uksi/2025/622/introduction/made/data.pdf","publication_date":"2025-05-29","reviewed":true,"si_code":"INFRASTRUCTURE PLANNING","type_class":"Order","type_code":"uksi","type_desc":"UK Statutory Instrument"}'::jsonb, 0, NULL, NULL, NULL, NULL, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "law_name" = EXCLUDED."law_name",
      "group" = EXCLUDED."group",
      "status" = EXCLUDED."status",
      "selected" = EXCLUDED."selected",
      "parsed_data" = EXCLUDED."parsed_data",
      "parse_count" = EXCLUDED."parse_count",
      "lat_inserted" = EXCLUDED."lat_inserted",
      "lat_deleted" = EXCLUDED."lat_deleted",
      "annotations_inserted" = EXCLUDED."annotations_inserted",
      "parse_duration_ms" = EXCLUDED."parse_duration_ms",
      "parse_error" = EXCLUDED."parse_error";

INSERT INTO "scrape_session_records" ("id", "session_id", "law_name", "group", "status", "selected", "parsed_data", "parse_count", "lat_inserted", "lat_deleted", "annotations_inserted", "parse_duration_ms", "parse_error")
VALUES ('469c503a-94d1-486b-9169-1003ae28a046', '2025-05-01-to-31', 'UK_ssi_2025_166', 'group1', 'confirmed', false, '{"Family":"💚 TOWN & COUNTRY PLANNING","Number":"166","SICode":["TOWN AND COUNTRY PLANNING"],"Tags":["Town","Country","Planning","Fees","Appeals","Scotland","Amendment","Regulations"],"Title_EN":"Town and Country Planning (Fees for Appeals) (Scotland) Amendment Regulations","Year":2025,"document_status":"final","leg_gov_uk_url":"https://www.legislation.gov.uk/ssi/2025/166","live":"✔ In force","live_description":"Current legislation","md_attachment_paras":0,"md_body_paras":2,"md_coming_into_force_date":"2025-06-08","md_date":"2025-06-08","md_description":"These Regulations amend the Town and Country Planning (Fees for Appeals) (Scotland) Regulations 2025 (“the principal instrument”).","md_images":0,"md_made_date":"2025-05-29","md_modified":"2025-05-29","md_schedule_paras":0,"md_total_paras":2,"name":"UK_ssi_2025_166","pdf_href":"http://www.legislation.gov.uk/ssi/2025/166/introduction/made/data.pdf","publication_date":"2025-05-29","reviewed":true,"si_code":"TOWN AND COUNTRY PLANNING","type_class":"Regulation","type_code":"ssi","type_desc":"Scottish Statutory Instrument"}'::jsonb, 0, NULL, NULL, NULL, NULL, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "law_name" = EXCLUDED."law_name",
      "group" = EXCLUDED."group",
      "status" = EXCLUDED."status",
      "selected" = EXCLUDED."selected",
      "parsed_data" = EXCLUDED."parsed_data",
      "parse_count" = EXCLUDED."parse_count",
      "lat_inserted" = EXCLUDED."lat_inserted",
      "lat_deleted" = EXCLUDED."lat_deleted",
      "annotations_inserted" = EXCLUDED."annotations_inserted",
      "parse_duration_ms" = EXCLUDED."parse_duration_ms",
      "parse_error" = EXCLUDED."parse_error";


-- ══════════════════════════════════════════════════
-- cascade_affected_laws (2 rows)
-- ══════════════════════════════════════════════════

INSERT INTO "cascade_affected_laws" ("id", "session_id", "affected_law", "update_type", "status", "source_laws", "layer", "metadata")
VALUES ('7d6af013-f5e6-4cba-8b12-d589fecfda2a', '2025-05-01-to-31', 'UK_eur_2016_2031', 'enacting_link', 'pending', ARRAY['UK_uksi_2025_559'], 1, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "affected_law" = EXCLUDED."affected_law",
      "update_type" = EXCLUDED."update_type",
      "status" = EXCLUDED."status",
      "source_laws" = EXCLUDED."source_laws",
      "layer" = EXCLUDED."layer",
      "metadata" = EXCLUDED."metadata";

INSERT INTO "cascade_affected_laws" ("id", "session_id", "affected_law", "update_type", "status", "source_laws", "layer", "metadata")
VALUES ('dbc7759b-a6a8-41ab-b6d9-d5903c510696', '2025-05-01-to-31', 'UK_eur_2019_2072', 'reparse', 'processed', ARRAY['UK_uksi_2025_559'], 1, NULL)
ON CONFLICT ("id") DO UPDATE SET
  "session_id" = EXCLUDED."session_id",
      "affected_law" = EXCLUDED."affected_law",
      "update_type" = EXCLUDED."update_type",
      "status" = EXCLUDED."status",
      "source_laws" = EXCLUDED."source_laws",
      "layer" = EXCLUDED."layer",
      "metadata" = EXCLUDED."metadata";


COMMIT;
