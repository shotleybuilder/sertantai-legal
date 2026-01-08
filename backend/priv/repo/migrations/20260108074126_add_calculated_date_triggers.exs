defmodule SertantaiLegal.Repo.Migrations.AddCalculatedDateTriggers do
  @moduledoc """
  Adds PostgreSQL triggers and indexes for calculated date fields:
  - latest_amend_date: MAX(md_date) of all laws in amended_by array
  - latest_rescind_date: MAX(md_date) of all laws in rescinded_by array

  These triggers automatically maintain the calculated fields when:
  1. The amended_by/rescinded_by arrays change on a law
  2. The md_date changes on an amending/rescinding law (propagates to affected laws)
  """

  use Ecto.Migration

  def up do
    # ============================================
    # ADD COLUMNS (if not exist)
    # These columns may have been added manually during development
    # ============================================

    # Add year/month columns for latest_amend_date
    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'latest_amend_date_year') THEN
            ALTER TABLE uk_lrt ADD COLUMN latest_amend_date_year integer;
        END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'latest_amend_date_month') THEN
            ALTER TABLE uk_lrt ADD COLUMN latest_amend_date_month integer;
        END IF;
    END $$;
    """)

    # Add year/month columns for latest_rescind_date
    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'latest_rescind_date_year') THEN
            ALTER TABLE uk_lrt ADD COLUMN latest_rescind_date_year integer;
        END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'latest_rescind_date_month') THEN
            ALTER TABLE uk_lrt ADD COLUMN latest_rescind_date_month integer;
        END IF;
    END $$;
    """)

    # ============================================
    # GIN INDEXES for fast array containment lookups
    # ============================================

    execute("""
    CREATE INDEX IF NOT EXISTS idx_uk_lrt_amended_by_gin ON uk_lrt USING GIN (amended_by);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS idx_uk_lrt_rescinded_by_gin ON uk_lrt USING GIN (rescinded_by);
    """)

    # ============================================
    # AMENDMENT TRIGGERS
    # ============================================

    # Trigger function 1: Recalculate latest_amend_date when amended_by changes
    execute("""
    CREATE OR REPLACE FUNCTION update_latest_amend_date()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Only recalculate if amended_by has values
        IF NEW.amended_by IS NOT NULL AND array_length(NEW.amended_by, 1) > 0 THEN
            NEW.latest_amend_date := (
                SELECT MAX(amender.md_date)
                FROM uk_lrt amender
                WHERE amender.name = ANY(NEW.amended_by)
            );
            NEW.latest_amend_date_year := EXTRACT(YEAR FROM NEW.latest_amend_date)::integer;
            NEW.latest_amend_date_month := EXTRACT(MONTH FROM NEW.latest_amend_date)::integer;
        ELSE
            NEW.latest_amend_date := NULL;
            NEW.latest_amend_date_year := NULL;
            NEW.latest_amend_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    DROP TRIGGER IF EXISTS trg_update_latest_amend_date ON uk_lrt;
    """)

    execute("""
    CREATE TRIGGER trg_update_latest_amend_date
    BEFORE INSERT OR UPDATE OF amended_by ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION update_latest_amend_date();
    """)

    # Trigger function 2: Propagate md_date changes to amended laws
    execute("""
    CREATE OR REPLACE FUNCTION propagate_amend_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Only propagate if md_date actually changed
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            -- Update all laws that are amended by this law
            UPDATE uk_lrt target
            SET
                latest_amend_date = (
                    SELECT MAX(amender.md_date)
                    FROM uk_lrt amender
                    WHERE amender.name = ANY(target.amended_by)
                ),
                latest_amend_date_year = EXTRACT(YEAR FROM (
                    SELECT MAX(amender.md_date)
                    FROM uk_lrt amender
                    WHERE amender.name = ANY(target.amended_by)
                ))::integer,
                latest_amend_date_month = EXTRACT(MONTH FROM (
                    SELECT MAX(amender.md_date)
                    FROM uk_lrt amender
                    WHERE amender.name = ANY(target.amended_by)
                ))::integer
            WHERE NEW.name = ANY(target.amended_by);
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    DROP TRIGGER IF EXISTS trg_propagate_amend_date ON uk_lrt;
    """)

    execute("""
    CREATE TRIGGER trg_propagate_amend_date
    AFTER UPDATE OF md_date ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION propagate_amend_date_change();
    """)

    # ============================================
    # RESCIND TRIGGERS
    # ============================================

    # Trigger function 1: Recalculate latest_rescind_date when rescinded_by changes
    execute("""
    CREATE OR REPLACE FUNCTION update_latest_rescind_date()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Only recalculate if rescinded_by has values
        IF NEW.rescinded_by IS NOT NULL AND array_length(NEW.rescinded_by, 1) > 0 THEN
            NEW.latest_rescind_date := (
                SELECT MAX(rescinder.md_date)
                FROM uk_lrt rescinder
                WHERE rescinder.name = ANY(NEW.rescinded_by)
            );
            NEW.latest_rescind_date_year := EXTRACT(YEAR FROM NEW.latest_rescind_date)::integer;
            NEW.latest_rescind_date_month := EXTRACT(MONTH FROM NEW.latest_rescind_date)::integer;
        ELSE
            NEW.latest_rescind_date := NULL;
            NEW.latest_rescind_date_year := NULL;
            NEW.latest_rescind_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    DROP TRIGGER IF EXISTS trg_update_latest_rescind_date ON uk_lrt;
    """)

    execute("""
    CREATE TRIGGER trg_update_latest_rescind_date
    BEFORE INSERT OR UPDATE OF rescinded_by ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION update_latest_rescind_date();
    """)

    # Trigger function 2: Propagate md_date changes to rescinded laws
    execute("""
    CREATE OR REPLACE FUNCTION propagate_rescind_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        -- Only propagate if md_date actually changed
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            -- Update all laws that are rescinded by this law
            UPDATE uk_lrt target
            SET
                latest_rescind_date = (
                    SELECT MAX(rescinder.md_date)
                    FROM uk_lrt rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                ),
                latest_rescind_date_year = EXTRACT(YEAR FROM (
                    SELECT MAX(rescinder.md_date)
                    FROM uk_lrt rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                ))::integer,
                latest_rescind_date_month = EXTRACT(MONTH FROM (
                    SELECT MAX(rescinder.md_date)
                    FROM uk_lrt rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                ))::integer
            WHERE NEW.name = ANY(target.rescinded_by);
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("""
    DROP TRIGGER IF EXISTS trg_propagate_rescind_date ON uk_lrt;
    """)

    execute("""
    CREATE TRIGGER trg_propagate_rescind_date
    AFTER UPDATE OF md_date ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION propagate_rescind_date_change();
    """)

    # ============================================
    # BASELINE CALCULATIONS
    # Populate existing records (runs once on migration)
    # ============================================

    # Populate latest_amend_date for existing records
    execute("""
    WITH latest_amend_dates AS (
        SELECT
            target.id,
            MAX(amender.md_date) as max_amend_date
        FROM uk_lrt target
        CROSS JOIN LATERAL unnest(target.amended_by) as amender_name
        JOIN uk_lrt amender ON amender.name = amender_name
        WHERE target.amended_by IS NOT NULL
        GROUP BY target.id
    )
    UPDATE uk_lrt
    SET
        latest_amend_date = latest_amend_dates.max_amend_date,
        latest_amend_date_year = EXTRACT(YEAR FROM latest_amend_dates.max_amend_date)::integer,
        latest_amend_date_month = EXTRACT(MONTH FROM latest_amend_dates.max_amend_date)::integer
    FROM latest_amend_dates
    WHERE uk_lrt.id = latest_amend_dates.id;
    """)

    # Populate latest_rescind_date for existing records
    execute("""
    WITH latest_rescind_dates AS (
        SELECT
            target.id,
            MAX(rescinder.md_date) as max_rescind_date
        FROM uk_lrt target
        CROSS JOIN LATERAL unnest(target.rescinded_by) as rescinder_name
        JOIN uk_lrt rescinder ON rescinder.name = rescinder_name
        WHERE target.rescinded_by IS NOT NULL
        GROUP BY target.id
    )
    UPDATE uk_lrt
    SET
        latest_rescind_date = latest_rescind_dates.max_rescind_date,
        latest_rescind_date_year = EXTRACT(YEAR FROM latest_rescind_dates.max_rescind_date)::integer,
        latest_rescind_date_month = EXTRACT(MONTH FROM latest_rescind_dates.max_rescind_date)::integer
    FROM latest_rescind_dates
    WHERE uk_lrt.id = latest_rescind_dates.id;
    """)
  end

  def down do
    # Drop triggers
    execute("DROP TRIGGER IF EXISTS trg_update_latest_amend_date ON uk_lrt;")
    execute("DROP TRIGGER IF EXISTS trg_propagate_amend_date ON uk_lrt;")
    execute("DROP TRIGGER IF EXISTS trg_update_latest_rescind_date ON uk_lrt;")
    execute("DROP TRIGGER IF EXISTS trg_propagate_rescind_date ON uk_lrt;")

    # Drop functions
    execute("DROP FUNCTION IF EXISTS update_latest_amend_date();")
    execute("DROP FUNCTION IF EXISTS propagate_amend_date_change();")
    execute("DROP FUNCTION IF EXISTS update_latest_rescind_date();")
    execute("DROP FUNCTION IF EXISTS propagate_rescind_date_change();")

    # Drop indexes
    execute("DROP INDEX IF EXISTS idx_uk_lrt_amended_by_gin;")
    execute("DROP INDEX IF EXISTS idx_uk_lrt_rescinded_by_gin;")

    # Clear calculated fields
    execute("""
    UPDATE uk_lrt SET
        latest_amend_date = NULL,
        latest_amend_date_year = NULL,
        latest_amend_date_month = NULL,
        latest_rescind_date = NULL,
        latest_rescind_date_year = NULL,
        latest_rescind_date_month = NULL;
    """)
  end
end
