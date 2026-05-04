defmodule SertantaiLegal.Repo.Migrations.DropLinkedColumns do
  use Ecto.Migration

  def up do
    alter table(:uk_lrt) do
      remove :linked_enacted_by
      remove :linked_amending
      remove :linked_amended_by
      remove :linked_rescinding
      remove :linked_rescinded_by
    end
  end

  def down do
    alter table(:uk_lrt) do
      add :linked_enacted_by, {:array, :string}
      add :linked_amending, {:array, :string}
      add :linked_amended_by, {:array, :string}
      add :linked_rescinding, {:array, :string}
      add :linked_rescinded_by, {:array, :string}
    end
  end
end
