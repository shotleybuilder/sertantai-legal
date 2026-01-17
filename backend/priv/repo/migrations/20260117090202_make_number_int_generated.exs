defmodule SertantaiLegal.Repo.Migrations.MakeNumberIntGenerated do
  @moduledoc """
  Convert number_int to a PostgreSQL generated column computed from number.

  The number field is text but 19,088 of 19,089 records contain pure integers.
  The one exception is "Eliz2/9-10/62" (regnal year format) which will yield NULL.
  """
  use Ecto.Migration

  def up do
    # Drop the existing column
    alter table(:uk_lrt) do
      remove(:number_int)
    end

    # Re-add as generated column
    # Uses regexp to extract only if the number is purely numeric
    execute("""
    ALTER TABLE uk_lrt
    ADD COLUMN number_int integer
    GENERATED ALWAYS AS (
      CASE
        WHEN number ~ '^[0-9]+$' THEN number::integer
        ELSE NULL
      END
    ) STORED
    """)
  end

  def down do
    # Remove generated column
    alter table(:uk_lrt) do
      remove(:number_int)
    end

    # Re-add as regular column
    alter table(:uk_lrt) do
      add(:number_int, :integer)
    end
  end
end
