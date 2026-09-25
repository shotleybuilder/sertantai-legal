defmodule SertantaiLegal.Repo.Migrations.LatStatsStatementTriggers do
  @moduledoc """
  Replace the per-row `propagate_lat_stats` trigger on `legal_articles` with
  statement-level triggers (LAT parse API pilot, 2026-09-25).

  The row trigger recounted a law's provisions and rewrote its
  `legal_register` row for every provision inserted/updated/deleted: O(n^2)
  per law. A 10,900-row Act (Communications Act 2003) timed out on persist,
  and provision publishes from fractalaw crawled at ~30 rows/s.

  The statement triggers recount each affected law once per statement, using
  transition tables. They are attached to the partitioned parent (writes via
  Ash / `legal_articles`) and to each partition (writes via the `lat` view,
  which targets `legal_articles_uk` directly); statement triggers are not
  inherited, so each path fires exactly once. A new country partition needs
  the three triggers added too.
  """

  use Ecto.Migration

  @tables ["legal_articles", "legal_articles_uk", "legal_articles_au"]

  def up do
    execute("""
    CREATE OR REPLACE FUNCTION propagate_lat_stats_stmt() RETURNS trigger
    LANGUAGE plpgsql AS $function$
    BEGIN
      WITH affected AS (
        SELECT law_id, country FROM lat_stats_new
        UNION
        SELECT law_id, country FROM lat_stats_old
      )
      UPDATE legal_register r
      SET lat_count = COALESCE((SELECT COUNT(*) FROM legal_articles a
                                WHERE a.law_id = r.id AND a.country = r.country), 0),
          latest_lat_updated_at = (SELECT MAX(a.updated_at) FROM legal_articles a
                                   WHERE a.law_id = r.id AND a.country = r.country),
          updated_at = NOW()
      FROM affected
      WHERE r.id = affected.law_id AND r.country = affected.country;
      RETURN NULL;
    END;
    $function$
    """)

    # Transition tables can't be shared across events, so one trigger per event.
    # A missing side is supplied as an empty relation via wrapper functions.
    execute("""
    CREATE OR REPLACE FUNCTION propagate_lat_stats_ins() RETURNS trigger
    LANGUAGE plpgsql AS $function$
    BEGIN
      UPDATE legal_register r
      SET lat_count = COALESCE((SELECT COUNT(*) FROM legal_articles a
                                WHERE a.law_id = r.id AND a.country = r.country), 0),
          latest_lat_updated_at = (SELECT MAX(a.updated_at) FROM legal_articles a
                                   WHERE a.law_id = r.id AND a.country = r.country),
          updated_at = NOW()
      FROM (SELECT DISTINCT law_id, country FROM lat_stats_new) affected
      WHERE r.id = affected.law_id AND r.country = affected.country;
      RETURN NULL;
    END;
    $function$
    """)

    execute("""
    CREATE OR REPLACE FUNCTION propagate_lat_stats_del() RETURNS trigger
    LANGUAGE plpgsql AS $function$
    BEGIN
      UPDATE legal_register r
      SET lat_count = COALESCE((SELECT COUNT(*) FROM legal_articles a
                                WHERE a.law_id = r.id AND a.country = r.country), 0),
          latest_lat_updated_at = (SELECT MAX(a.updated_at) FROM legal_articles a
                                   WHERE a.law_id = r.id AND a.country = r.country),
          updated_at = NOW()
      FROM (SELECT DISTINCT law_id, country FROM lat_stats_old) affected
      WHERE r.id = affected.law_id AND r.country = affected.country;
      RETURN NULL;
    END;
    $function$
    """)

    # Row trigger on the parent (its partition clones go with it)
    execute("DROP TRIGGER IF EXISTS trg_propagate_lat_stats ON legal_articles")

    for t <- @tables do
      execute("""
      CREATE TRIGGER trg_lat_stats_ins AFTER INSERT ON #{t}
      REFERENCING NEW TABLE AS lat_stats_new
      FOR EACH STATEMENT EXECUTE FUNCTION propagate_lat_stats_ins()
      """)

      execute("""
      CREATE TRIGGER trg_lat_stats_upd AFTER UPDATE ON #{t}
      REFERENCING NEW TABLE AS lat_stats_new OLD TABLE AS lat_stats_old
      FOR EACH STATEMENT EXECUTE FUNCTION propagate_lat_stats_stmt()
      """)

      execute("""
      CREATE TRIGGER trg_lat_stats_del AFTER DELETE ON #{t}
      REFERENCING OLD TABLE AS lat_stats_old
      FOR EACH STATEMENT EXECUTE FUNCTION propagate_lat_stats_del()
      """)
    end
  end

  def down do
    for t <- @tables do
      execute("DROP TRIGGER IF EXISTS trg_lat_stats_ins ON #{t}")
      execute("DROP TRIGGER IF EXISTS trg_lat_stats_upd ON #{t}")
      execute("DROP TRIGGER IF EXISTS trg_lat_stats_del ON #{t}")
    end

    execute("DROP FUNCTION IF EXISTS propagate_lat_stats_stmt()")
    execute("DROP FUNCTION IF EXISTS propagate_lat_stats_ins()")
    execute("DROP FUNCTION IF EXISTS propagate_lat_stats_del()")

    execute("""
    CREATE OR REPLACE FUNCTION public.propagate_lat_stats()
     RETURNS trigger
     LANGUAGE plpgsql
    AS $function$
    DECLARE
        target_law_id uuid;
        target_country text;
    BEGIN
        target_law_id := COALESCE(NEW.law_id, OLD.law_id);
        target_country := COALESCE(NEW.country, OLD.country);

        UPDATE legal_register
        SET lat_count = COALESCE((SELECT COUNT(*) FROM legal_articles WHERE law_id = target_law_id AND country = target_country), 0),
            latest_lat_updated_at = (SELECT MAX(updated_at) FROM legal_articles WHERE law_id = target_law_id AND country = target_country),
            updated_at = NOW()
        WHERE id = target_law_id AND country = target_country;

        RETURN COALESCE(NEW, OLD);
    END;
    $function$
    """)

    execute("""
    CREATE TRIGGER trg_propagate_lat_stats AFTER INSERT OR DELETE OR UPDATE ON legal_articles
    FOR EACH ROW EXECUTE FUNCTION propagate_lat_stats()
    """)
  end
end
