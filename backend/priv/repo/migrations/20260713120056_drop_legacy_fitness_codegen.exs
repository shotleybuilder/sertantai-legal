defmodule SertantaiLegal.Repo.Migrations.DropLegacyFitnessCodegen do
  @moduledoc """
  Ash codegen for legacy fitness cleanup.
  legal_register + uk_lrt columns already dropped by manual migration 20260713140001.
  sync_profiles column swap is real (no view/trigger issues).
  """
  use Ecto.Migration

  def up do
    # legal_register + uk_lrt: columns already dropped by 20260713140001

    # sync_profiles: real schema change (no view/trigger dependency)
    alter table(:sync_profiles) do
      remove :fitness_sector
      remove :fitness_plant
      remove :fitness_place
      remove :fitness_process
      remove :fitness_person
      add :fitness_entities, {:array, :text}
    end
  end

  def down do
    alter table(:sync_profiles) do
      remove :fitness_entities
      add :fitness_person, {:array, :text}
      add :fitness_process, {:array, :text}
      add :fitness_place, {:array, :text}
      add :fitness_plant, {:array, :text}
      add :fitness_sector, {:array, :text}
    end
  end
end
