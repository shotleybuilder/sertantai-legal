defmodule SertantaiLegal.Repo.Migrations.FixTriggerPerformance do
  @moduledoc """
  Fix cascading trigger performance that caused 15s+ timeouts during record updates.

  Problems:
  1. No index on `name` column - trigger subqueries do sequential scans
  2. Propagation triggers use `= ANY()` which cannot use GIN indexes;
     rewrite to use `@>` operator which hits the existing GIN indexes
  """
  use Ecto.Migration

  def up do
    # 1. Add btree index on name (used by trigger subqueries)
    create_if_not_exists(index(:uk_lrt, [:name], name: :uk_lrt_name_index))

    # 2. Rewrite update_latest_amend_date to use name index
    execute("""
    CREATE OR REPLACE FUNCTION update_latest_amend_date()
    RETURNS TRIGGER AS $$
    BEGIN
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

    # 3. Rewrite propagate_amend_date_change to use @> for GIN index
    execute("""
    CREATE OR REPLACE FUNCTION propagate_amend_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
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
            WHERE target.amended_by @> ARRAY[NEW.name]::text[];
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # 4. Rewrite update_latest_rescind_date (uses name index via ANY lookup)
    execute("""
    CREATE OR REPLACE FUNCTION update_latest_rescind_date()
    RETURNS TRIGGER AS $$
    BEGIN
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

    # 5. Rewrite propagate_rescind_date_change to use @> for GIN index
    execute("""
    CREATE OR REPLACE FUNCTION propagate_rescind_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
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
            WHERE target.rescinded_by @> ARRAY[NEW.name]::text[];
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # 6. Add GIN index on rescinded_by if not already present (for the @> operator)
    create_if_not_exists(
      index(:uk_lrt, [:rescinded_by], name: :idx_uk_lrt_rescinded_by_gin, using: "GIN")
    )
  end

  def down do
    drop_if_exists(index(:uk_lrt, [:name], name: :uk_lrt_name_index))

    # Restore original trigger functions (with = ANY syntax)
    execute("""
    CREATE OR REPLACE FUNCTION update_latest_amend_date()
    RETURNS TRIGGER AS $$
    BEGIN
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
    CREATE OR REPLACE FUNCTION propagate_amend_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
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
    CREATE OR REPLACE FUNCTION update_latest_rescind_date()
    RETURNS TRIGGER AS $$
    BEGIN
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
    CREATE OR REPLACE FUNCTION propagate_rescind_date_change()
    RETURNS TRIGGER AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
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
  end
end
