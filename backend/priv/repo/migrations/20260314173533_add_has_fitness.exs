defmodule SertantaiLegal.Repo.Migrations.AddHasFitness do
  @moduledoc """
  Adds a generated boolean column `has_fitness` to uk_lrt.
  True when any fitness tag array (person/process/place/plant/property/sector)
  is non-null.
  """

  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE uk_lrt ADD COLUMN has_fitness BOOLEAN
      GENERATED ALWAYS AS (
        fitness_person IS NOT NULL OR
        fitness_process IS NOT NULL OR
        fitness_place IS NOT NULL OR
        fitness_plant IS NOT NULL OR
        fitness_property IS NOT NULL OR
        fitness_sector IS NOT NULL
      ) STORED
    """)
  end

  def down do
    alter table(:uk_lrt) do
      remove(:has_fitness)
    end
  end
end
