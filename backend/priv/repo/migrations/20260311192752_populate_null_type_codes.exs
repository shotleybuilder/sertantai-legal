defmodule SertantaiLegal.Repo.Migrations.PopulateNullTypeCodes do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE uk_lrt
    SET type_code = SPLIT_PART(name, '_', 2)
    WHERE type_code IS NULL
      AND SPLIT_PART(name, '_', 2) != ''
    """)
  end

  def down do
    # Not reversible — we don't know which records had NULL before
    :ok
  end
end
