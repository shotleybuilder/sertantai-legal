defmodule SertantaiLegal.Repo.Migrations.AddActorInferenceColumns do
  @moduledoc """
  Add holder_inferred_from and ancestor_distance columns to legal_articles.

  These new fields come from the fractalaw provision taxa payload restructure
  (2026-06-21). They indicate how actors were inferred for each provision:
  - holder_inferred_from: "self", "parent", or comma-separated ancestor sources
  - ancestor_distance: clause distance when actors inherited from a parent

  Also recreates the `lat` view to pick up the new columns.
  """

  use Ecto.Migration

  def up do
    alter table(:legal_articles) do
      add :holder_inferred_from, :text
      add :ancestor_distance, :integer
    end

    # Recreate lat view to include new columns
    execute("DROP VIEW IF EXISTS lat")
    execute("CREATE VIEW lat AS SELECT * FROM legal_articles_uk")
  end

  def down do
    execute("DROP VIEW IF EXISTS lat")

    alter table(:legal_articles) do
      remove :holder_inferred_from
      remove :ancestor_distance
    end

    execute("CREATE VIEW lat AS SELECT * FROM legal_articles_uk")
  end
end
