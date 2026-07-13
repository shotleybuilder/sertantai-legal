defmodule SertantaiLegal.Repo.Migrations.AddFitnessEntitiesGinIndex do
  @moduledoc """
  GIN index on fitness_entities for fast array overlap queries.
  Serves as the inverted entity index for applicability matching.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE INDEX idx_legal_register_fitness_entities_gin
    ON legal_register USING GIN (fitness_entities)
    WHERE fitness_entities IS NOT NULL
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS idx_legal_register_fitness_entities_gin")
  end
end
