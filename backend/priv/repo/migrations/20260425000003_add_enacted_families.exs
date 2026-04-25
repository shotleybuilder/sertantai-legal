defmodule SertantaiLegal.Repo.Migrations.AddEnactedFamilies do
  use Ecto.Migration

  def up do
    alter table(:uk_lrt) do
      add :enacted_families, :map
    end
  end

  def down do
    alter table(:uk_lrt) do
      remove :enacted_families
    end
  end
end
