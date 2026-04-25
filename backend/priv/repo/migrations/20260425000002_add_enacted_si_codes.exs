defmodule SertantaiLegal.Repo.Migrations.AddEnactedSiCodes do
  use Ecto.Migration

  def up do
    alter table(:uk_lrt) do
      add :enacted_si_codes, :map
    end
  end

  def down do
    alter table(:uk_lrt) do
      remove :enacted_si_codes
    end
  end
end
