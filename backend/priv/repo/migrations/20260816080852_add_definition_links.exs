defmodule SertantaiLegal.Repo.Migrations.AddDefinitionLinks do
  @moduledoc """
  Replace root_definition_id (single FK) with a definition_links junction table.

  A child definition can link to multiple root definitions — e.g. Housing Act 2004
  defines "local housing authority" separately for England (s.261(2)) and Wales
  (s.261(4)). The junction table preserves FK integrity on both sides.

  Migrates existing root_definition_id data before dropping the column.
  """

  use Ecto.Migration

  def up do
    # 1. Create the junction table
    create table(:definition_links, primary_key: false) do
      add :child_definition_id,
          references(:legislative_definitions,
            column: :id,
            name: "definition_links_child_definition_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          primary_key: true,
          null: false

      add :root_definition_id,
          references(:legislative_definitions,
            column: :id,
            name: "definition_links_root_definition_id_fkey",
            type: :uuid,
            on_delete: :delete_all
          ),
          primary_key: true,
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    # Reverse lookup index: find all children of a root definition
    create index(:definition_links, [:root_definition_id],
             name: "definition_links_root_definition_id_index"
           )

    # 2. Migrate existing links into the junction table
    execute """
    INSERT INTO definition_links (child_definition_id, root_definition_id)
    SELECT id, root_definition_id
    FROM legislative_definitions
    WHERE root_definition_id IS NOT NULL
    ON CONFLICT DO NOTHING
    """

    # 3. Drop old FK column and its index
    drop_if_exists index(:legislative_definitions, [:root_definition_id],
                     name: "legislative_definitions_root_definition_id_index"
                   )

    alter table(:legislative_definitions) do
      remove :root_definition_id
    end
  end

  def down do
    # Restore the old column
    alter table(:legislative_definitions) do
      add :root_definition_id,
          references(:legislative_definitions,
            column: :id,
            name: "legislative_definitions_root_definition_id_fkey",
            type: :uuid,
            on_delete: :restrict
          )
    end

    create index(:legislative_definitions, [:root_definition_id],
             name: "legislative_definitions_root_definition_id_index"
           )

    # Migrate back: pick one link per child (arbitrary)
    execute """
    UPDATE legislative_definitions ld
    SET root_definition_id = dl.root_definition_id
    FROM (
      SELECT DISTINCT ON (child_definition_id) child_definition_id, root_definition_id
      FROM definition_links
      ORDER BY child_definition_id, inserted_at
    ) dl
    WHERE ld.id = dl.child_definition_id
    """

    drop constraint(:definition_links, "definition_links_child_definition_id_fkey")
    drop constraint(:definition_links, "definition_links_root_definition_id_fkey")
    drop table(:definition_links)
  end
end
