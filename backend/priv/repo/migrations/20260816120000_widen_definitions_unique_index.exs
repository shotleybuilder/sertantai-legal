defmodule SertantaiLegal.Repo.Migrations.WidenDefinitionsUniqueIndex do
  @moduledoc """
  Widen the unique constraint on legislative_definitions from (law_name, term)
  to (law_name, term, section_id).

  A law can define the same term in different sections — e.g. Housing Act 2004
  defines "local housing authority" separately for England (s.261(2)) and
  Wales (s.261(4)). The old constraint silently dropped one during upsert.
  """

  use Ecto.Migration

  def up do
    drop_if_exists unique_index(:legislative_definitions, [:law_name, :term],
                     name: "legislative_definitions_unique_law_term_index"
                   )

    create unique_index(:legislative_definitions, [:law_name, :term, :section_id],
             name: "legislative_definitions_unique_law_term_section_index"
           )
  end

  def down do
    drop_if_exists unique_index(:legislative_definitions, [:law_name, :term, :section_id],
                     name: "legislative_definitions_unique_law_term_section_index"
                   )

    create unique_index(:legislative_definitions, [:law_name, :term],
             name: "legislative_definitions_unique_law_term_index"
           )
  end
end
