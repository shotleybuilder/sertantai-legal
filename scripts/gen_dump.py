#!/usr/bin/env python3
"""Generate a targeted pg_dump that only includes columns present in prod."""
import subprocess
import os

os.environ["PGPASSWORD"] = "postgres"

# Get dev columns for uk_lrt in ordinal order
result = subprocess.run(
    ["psql", "-h", "localhost", "-p", "5436", "-U", "postgres",
     "-d", "sertantai_legal_dev", "-t", "-A", "-c",
     "SELECT column_name FROM information_schema.columns WHERE table_name = 'uk_lrt' ORDER BY ordinal_position;"],
    capture_output=True, text=True
)
dev_cols = [c.strip() for c in result.stdout.strip().split('\n') if c.strip()]

# Prod columns (from server output)
prod_cols_set = {
    "acronym","amended_by","amended_by_change_log","amending","amending_change_log",
    "article_duty_type","created_at","domain","duties","duty_holder","duty_type",
    "duty_type_article","enacted_by","enacted_by_meta","enacting","family","family_ii",
    "function","geo_detail","geo_extent","geo_region","id","is_amending","is_commencing",
    "is_enacting","is_making","is_rescinding","latest_amend_date","latest_amend_date_month",
    "latest_amend_date_year","latest_change_date","latest_rescind_date",
    "latest_rescind_date_month","latest_rescind_date_year","leg_gov_uk_url",
    "linked_amended_by","linked_amending","linked_enacted_by","linked_rescinded_by",
    "linked_rescinding","live","live_conflict","live_conflict_detail","live_description",
    "live_from_changes","live_from_metadata","live_source","md_attachment_paras",
    "md_body_paras","md_coming_into_force_date","md_date","md_dct_valid_date",
    "md_description","md_enactment_date","md_images","md_made_date","md_modified",
    "md_restrict_extent","md_restrict_start_date","md_schedule_paras","md_subjects",
    "md_total_paras","name","number","number_int","old_style_number","popimar",
    "popimar_details","power_holder","powers","purpose","record_change_log","rescinded_by",
    "rescinding","responsibilities","responsibility_holder","rights","rights_holder","role",
    "role_details","role_gvt","role_gvt_details","si_code","tags","title_en","type_class",
    "type_code","type_desc","updated_at","year",
    "\U0001f53a_affects_stats_per_law",
    "\U0001f53a_rescinding_stats_per_law",
    "\U0001f53a_stats_affected_laws_count",
    "\U0001f53a_stats_affects_count",
    "\U0001f53a_stats_rescinding_laws_count",
    "\U0001f53a\U0001f53b_stats_self_affects_count",
    "\U0001f53a\U0001f53b_stats_self_affects_count_per_law_detailed",
    "\U0001f53b_affected_by_stats_per_law",
    "\U0001f53b_rescinded_by_stats_per_law",
    "\U0001f53b_stats_affected_by_count",
    "\U0001f53b_stats_affected_by_laws_count",
    "\U0001f53b_stats_rescinded_by_laws_count",
}

# Filter dev columns to only those in prod, preserving dev ordinal order
common_cols = [c for c in dev_cols if c in prod_cols_set]

dev_only = [c for c in dev_cols if c not in prod_cols_set]
prod_only = [c for c in prod_cols_set if c not in set(dev_cols)]

print(f"Dev columns: {len(dev_cols)}")
print(f"Prod columns: {len(prod_cols_set)}")
print(f"Common columns: {len(common_cols)}")
print(f"Dev-only (skipped): {len(dev_only)}")
for c in dev_only:
    print(f"  - {c}")
if prod_only:
    print(f"Prod-only (not in dev): {len(prod_only)}")
    for c in prod_only:
        print(f"  - {c}")

# Build column list
quoted = ", ".join(f'"{c}"' for c in common_cols)

# Export uk_lrt data
print("\nExporting uk_lrt...")
export_sql = f"\\COPY (SELECT {quoted} FROM uk_lrt) TO '/tmp/uk_lrt_export.tsv' WITH (FORMAT text)"
result = subprocess.run(
    ["psql", "-h", "localhost", "-p", "5436", "-U", "postgres",
     "-d", "sertantai_legal_dev", "-c", export_sql],
    capture_output=True, text=True
)
print(result.stdout)
if result.stderr:
    print(f"STDERR: {result.stderr}")

# Build the import SQL file
with open("/tmp/uk_lrt_import.sql", "w") as f:
    f.write(f"COPY uk_lrt ({quoted}) FROM STDIN WITH (FORMAT text);\n")
print("Generated /tmp/uk_lrt_import.sql (header only)")

# Now export the other tables as full dumps (they have matching schemas)
for table in ["cascade_affected_laws", "scrape_sessions", "scrape_session_records"]:
    print(f"\nExporting {table}...")
    result = subprocess.run(
        ["psql", "-h", "localhost", "-p", "5436", "-U", "postgres",
         "-d", "sertantai_legal_dev", "-c",
         f"\\COPY {table} TO '/tmp/{table}_export.tsv' WITH (FORMAT text)"],
        capture_output=True, text=True
    )
    print(result.stdout)
    if result.stderr:
        print(f"STDERR: {result.stderr}")

print("\nDone! Files in /tmp/:")
print("  uk_lrt_export.tsv")
print("  cascade_affected_laws_export.tsv")
print("  scrape_sessions_export.tsv")
print("  scrape_session_records_export.tsv")
