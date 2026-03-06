defmodule SertantaiLegal.Repo.Migrations.AddLatStatsTriggers do
  @moduledoc """
  Materialise LAT statistics into uk_lrt for real-time Electric sync.

  Adds two trigger-maintained columns:
  - lat_count: number of LAT rows for this law
  - latest_lat_updated_at: most recent LAT updated_at timestamp

  These are kept in sync by two triggers:
  1. BEFORE INSERT/UPDATE on uk_lrt — recalculates from lat table
  2. AFTER INSERT/UPDATE/DELETE on lat — propagates changes to parent uk_lrt row

  Follows the same pattern as latest_amend_date/latest_rescind_date triggers
  (see 20260108074126_add_calculated_date_triggers.exs).
  """

  use Ecto.Migration

  def up do
    # ============================================
    # ADD COLUMNS
    # ============================================

    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'lat_count') THEN
            ALTER TABLE uk_lrt ADD COLUMN lat_count integer NOT NULL DEFAULT 0;
        END IF;
    END $$;
    """)

    execute("""
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_name = 'uk_lrt' AND column_name = 'latest_lat_updated_at') THEN
            ALTER TABLE uk_lrt ADD COLUMN latest_lat_updated_at timestamptz;
        END IF;
    END $$;
    """)

    # ============================================
    # TRIGGER A: Recalculate on uk_lrt INSERT/UPDATE
    # ============================================

    execute("""
    CREATE OR REPLACE FUNCTION update_lat_stats()
    RETURNS TRIGGER AS $$
    BEGIN
        SELECT COUNT(*), MAX(updated_at)
        INTO NEW.lat_count, NEW.latest_lat_updated_at
        FROM lat
        WHERE lat.law_id = NEW.id;

        -- Ensure non-null for lat_count
        IF NEW.lat_count IS NULL THEN
            NEW.lat_count := 0;
        END IF;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("DROP TRIGGER IF EXISTS trg_update_lat_stats ON uk_lrt;")

    execute("""
    CREATE TRIGGER trg_update_lat_stats
    BEFORE INSERT OR UPDATE ON uk_lrt
    FOR EACH ROW EXECUTE FUNCTION update_lat_stats();
    """)

    # ============================================
    # TRIGGER B: Propagate lat changes to uk_lrt
    # ============================================

    execute("""
    CREATE OR REPLACE FUNCTION propagate_lat_stats()
    RETURNS TRIGGER AS $$
    DECLARE
        target_law_id uuid;
    BEGIN
        target_law_id := COALESCE(NEW.law_id, OLD.law_id);

        UPDATE uk_lrt
        SET lat_count = COALESCE((SELECT COUNT(*) FROM lat WHERE law_id = target_law_id), 0),
            latest_lat_updated_at = (SELECT MAX(updated_at) FROM lat WHERE law_id = target_law_id)
        WHERE id = target_law_id;

        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    """)

    execute("DROP TRIGGER IF EXISTS trg_propagate_lat_stats ON lat;")

    execute("""
    CREATE TRIGGER trg_propagate_lat_stats
    AFTER INSERT OR UPDATE OR DELETE ON lat
    FOR EACH ROW EXECUTE FUNCTION propagate_lat_stats();
    """)

    # ============================================
    # BASELINE BACKFILL
    # ============================================

    execute("""
    UPDATE uk_lrt
    SET lat_count = sub.cnt,
        latest_lat_updated_at = sub.max_updated
    FROM (
        SELECT law_id, COUNT(*) as cnt, MAX(updated_at) as max_updated
        FROM lat
        GROUP BY law_id
    ) sub
    WHERE uk_lrt.id = sub.law_id;
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS trg_update_lat_stats ON uk_lrt;")
    execute("DROP TRIGGER IF EXISTS trg_propagate_lat_stats ON lat;")
    execute("DROP FUNCTION IF EXISTS update_lat_stats();")
    execute("DROP FUNCTION IF EXISTS propagate_lat_stats();")

    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS lat_count;")
    execute("ALTER TABLE uk_lrt DROP COLUMN IF EXISTS latest_lat_updated_at;")
  end
end
