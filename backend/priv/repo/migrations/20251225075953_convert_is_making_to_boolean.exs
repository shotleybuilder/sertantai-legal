defmodule SertantaiLegal.Repo.Migrations.ConvertIsMakingToBoolean do
  @moduledoc """
  Convert is_making and is_commencing from decimal to boolean.

  These fields were imported from Airtable as decimal (1.0/0.0) but should be boolean.
  Migration is idempotent - only converts if columns are currently numeric.
  """

  use Ecto.Migration

  def up do
    # Only convert if column is currently numeric (not already boolean)
    # Must drop/recreate indexes that have WHERE clauses referencing these columns
    # Uses EXECUTE for dynamic SQL to prevent type-checking at parse time
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'uk_lrt' AND column_name = 'is_making' AND data_type = 'numeric'
      ) THEN
        -- Drop the partial index that references is_making
        EXECUTE 'DROP INDEX IF EXISTS uk_lrt_is_making_index';
        -- Convert the column type
        EXECUTE 'ALTER TABLE uk_lrt ALTER COLUMN is_making TYPE boolean USING CASE WHEN is_making > 0 THEN true ELSE false END';
        -- Recreate the index with boolean comparison
        EXECUTE 'CREATE INDEX uk_lrt_is_making_index ON uk_lrt (is_making) WHERE is_making = true';
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'uk_lrt' AND column_name = 'is_commencing' AND data_type = 'numeric'
      ) THEN
        EXECUTE 'ALTER TABLE uk_lrt ALTER COLUMN is_commencing TYPE boolean USING CASE WHEN is_commencing > 0 THEN true ELSE false END';
      END IF;
    END $$;
    """
  end

  def down do
    # Convert boolean back to decimal
    # Must drop/recreate indexes that have WHERE clauses referencing these columns
    # Uses EXECUTE for dynamic SQL to prevent type-checking at parse time
    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'uk_lrt' AND column_name = 'is_making' AND data_type = 'boolean'
      ) THEN
        -- Drop the partial index that references is_making
        EXECUTE 'DROP INDEX IF EXISTS uk_lrt_is_making_index';
        -- Convert the column type
        EXECUTE 'ALTER TABLE uk_lrt ALTER COLUMN is_making TYPE numeric(38,9) USING CASE WHEN is_making THEN 1.0 ELSE 0.0 END';
        -- Recreate the index with numeric comparison
        EXECUTE 'CREATE INDEX uk_lrt_is_making_index ON uk_lrt (is_making) WHERE is_making = 1::numeric';
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'uk_lrt' AND column_name = 'is_commencing' AND data_type = 'boolean'
      ) THEN
        EXECUTE 'ALTER TABLE uk_lrt ALTER COLUMN is_commencing TYPE numeric(38,9) USING CASE WHEN is_commencing THEN 1.0 ELSE 0.0 END';
      END IF;
    END $$;
    """
  end
end
