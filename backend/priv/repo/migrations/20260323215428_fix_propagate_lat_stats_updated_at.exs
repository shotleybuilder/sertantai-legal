defmodule SertantaiLegal.Repo.Migrations.FixPropagateLatStatsUpdatedAt do
  @moduledoc """
  Fix propagate_lat_stats trigger to also bump updated_at on uk_lrt.

  Without this, Electric doesn't detect lat_count/latest_lat_updated_at changes
  because it relies on updated_at to identify modified rows.
  """

  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION propagate_lat_stats()
    RETURNS TRIGGER AS $$
    DECLARE
        target_law_id uuid;
    BEGIN
        target_law_id := COALESCE(NEW.law_id, OLD.law_id);

        UPDATE uk_lrt
        SET lat_count = COALESCE((SELECT COUNT(*) FROM lat WHERE law_id = target_law_id), 0),
            latest_lat_updated_at = (SELECT MAX(updated_at) FROM lat WHERE law_id = target_law_id),
            updated_at = NOW()
        WHERE id = target_law_id;

        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    """)
  end

  def down do
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
  end
end
