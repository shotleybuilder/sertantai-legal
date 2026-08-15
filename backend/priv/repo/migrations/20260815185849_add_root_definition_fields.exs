defmodule SertantaiLegal.Repo.Migrations.AddRootDefinitionFields do
  @moduledoc """
  Adds root definition linking: a self-referential FK to identify the originating
  definition that cross-references point to, plus a text column to store the
  extracted citation even when the root row doesn't exist yet.
  """

  use Ecto.Migration

  def up do
    alter table(:legislative_definitions) do
      add :root_definition_id,
          references(:legislative_definitions, type: :uuid, on_delete: :restrict), null: true

      add :referenced_law_citation, :text, null: true
    end

    create index(:legislative_definitions, [:root_definition_id])
  end

  def down do
    drop_if_exists index(:legislative_definitions, [:root_definition_id])

    alter table(:legislative_definitions) do
      remove :referenced_law_citation
      remove :root_definition_id
    end
  end
end
