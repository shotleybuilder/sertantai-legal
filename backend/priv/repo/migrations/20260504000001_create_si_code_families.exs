defmodule SertantaiLegal.Repo.Migrations.CreateSiCodeFamilies do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE si_code_families (
      si_code TEXT NOT NULL,
      family TEXT NOT NULL,
      law_count INTEGER NOT NULL DEFAULT 0,
      pct NUMERIC(5,1) NOT NULL DEFAULT 0.0,
      PRIMARY KEY (si_code, family)
    )
    """

    execute "CREATE INDEX idx_si_code_families_family ON si_code_families(family)"
  end

  def down do
    execute "DROP TABLE IF EXISTS si_code_families"
  end
end
