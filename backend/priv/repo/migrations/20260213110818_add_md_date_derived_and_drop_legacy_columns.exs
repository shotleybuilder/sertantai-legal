defmodule SertantaiLegal.Repo.Migrations.AddMdDateDerivedAndDropLegacyColumns do
  @moduledoc """
  Formalizes md_date_year and md_date_month columns with auto-populate trigger,
  and drops 32 legacy columns that were carried over from the Airtable-era schema
  but never used by the application.

  Background: The dev database was originally populated from a full pg_dump of the
  legacy sertantai database, which included all 123 columns. The Ash migrations only
  create the 102 columns actually used. The 2025-12-22 schema alignment session
  deliberately excluded these 32 columns. md_date_year and md_date_month were the
  only 2 of 34 orphan columns with data and active frontend usage (browse page grouping).
  """

  use Ecto.Migration

  def up do
    # =====================================================================
    # Part 1: Add md_date_year and md_date_month (used by frontend browse)
    # =====================================================================

    alter table(:uk_lrt) do
      add_if_not_exists(:md_date_year, :integer)
      add_if_not_exists(:md_date_month, :integer)
    end

    # Create trigger function to auto-populate from md_date
    execute("""
    CREATE OR REPLACE FUNCTION populate_md_date_derived()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $function$
    BEGIN
        IF NEW.md_date IS NOT NULL THEN
            NEW.md_date_year := EXTRACT(YEAR FROM NEW.md_date)::integer;
            NEW.md_date_month := EXTRACT(MONTH FROM NEW.md_date)::integer;
        ELSE
            NEW.md_date_year := NULL;
            NEW.md_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $function$
    """)

    execute("DROP TRIGGER IF EXISTS trg_populate_md_date_derived ON uk_lrt")

    execute("""
    CREATE TRIGGER trg_populate_md_date_derived
    BEFORE INSERT OR UPDATE OF md_date ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION populate_md_date_derived()
    """)

    # Backfill existing rows
    execute("""
    UPDATE uk_lrt
    SET md_date_year = EXTRACT(YEAR FROM md_date)::integer,
        md_date_month = EXTRACT(MONTH FROM md_date)::integer
    WHERE md_date IS NOT NULL
      AND (md_date_year IS NULL OR md_date_month IS NULL)
    """)

    # =====================================================================
    # Part 2: Drop 32 legacy columns (all have zero data, no app usage)
    # =====================================================================

    # Group 1: Unused denormalized date components
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS latest_change_date_year")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS latest_change_date_month")

    # Group 2: Legacy change logs (empty, excluded by design in schema alignment)
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS md_change_log")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS amd_change_log")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS rsc_change_log")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS amd_by_change_log")

    # Group 3: Legacy narrative description
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS enacted_by_description")

    # Group 4: Legacy amendment/rescind count columns (replaced by Ash stats)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_#_amd_by_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_#_amd_of_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_#_laws_rsc_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_#_laws_rsc_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_#_laws_amd_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_#_laws_amd_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_#_laws_amd_by_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_#_self_amd_by_law"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_#_self_amd_of_law"|)

    # Group 5: Legacy amendment/rescind description columns
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_amd_short_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_amd_long_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_amd_short_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_amd_long_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_rsc_short_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "△_rsc_long_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_rsc_short_desc"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "▽_rsc_long_desc"|)

    # Group 6: Internal Airtable tracking fields
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS __e_register")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS __hs_register")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS __hr_register")

    # Group 7: Computed/display fields (derivable from other columns)
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS title_en_year")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS title_en_year_number")

    # Group 8: Revocation date fields (empty, latest_rescind_date exists in Ash)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "year__from_revoked_by__latest_date__"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "month__from_revoked_by__latest_date__"|)
    execute(~s|ALTER TABLE uk_lrt DROP COLUMN IF EXISTS "revoked_by__latest_date__"|)
  end

  def down do
    # Drop trigger and function
    execute("DROP TRIGGER IF EXISTS trg_populate_md_date_derived ON uk_lrt")
    execute("DROP FUNCTION IF EXISTS populate_md_date_derived()")

    alter table(:uk_lrt) do
      remove(:md_date_year)
      remove(:md_date_month)
    end

    # Note: Legacy columns are NOT recreated on rollback — they were empty and unused.
    # If needed, restore from a database backup.
  end
end
