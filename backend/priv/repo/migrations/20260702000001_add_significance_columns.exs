defmodule SertantaiLegal.Repo.Migrations.AddSignificanceColumns do
  @moduledoc """
  Add significance rating columns to legal_register (law-level) and
  legal_articles (provision-level) from fractalaw ZENOH-SPEC v2.0.

  Law-level: overall rating + score + K-profile distribution counts.
  Provision-level: 5 dimensions + confidence + weighted overall.

  Also recreates the `lat` view to pick up new columns.
  """

  use Ecto.Migration

  def up do
    # Law-level significance on legal_register
    alter table(:legal_register) do
      add :significance_rating, :text
      add :significance_score, :float
      add :significance_high_count, :integer
      add :significance_medium_count, :integer
      add :significance_low_count, :integer
      add :significance_total_obligations, :integer
    end

    # Provision-level significance on legal_articles
    alter table(:legal_articles) do
      add :significance_scope_duty_bearer, :text
      add :significance_scope_protected_class, :text
      add :significance_gravity, :text
      add :significance_strength, :text
      add :significance_hierarchy, :text
      add :significance_confidence, :float
      add :significance_overall, :text
    end

    # Recreate lat view to include new columns
    execute("DROP VIEW IF EXISTS lat")
    execute("CREATE VIEW lat AS SELECT * FROM legal_articles_uk")
  end

  def down do
    execute("DROP VIEW IF EXISTS lat")

    alter table(:legal_articles) do
      remove :significance_scope_duty_bearer
      remove :significance_scope_protected_class
      remove :significance_gravity
      remove :significance_strength
      remove :significance_hierarchy
      remove :significance_confidence
      remove :significance_overall
    end

    alter table(:legal_register) do
      remove :significance_rating
      remove :significance_score
      remove :significance_high_count
      remove :significance_medium_count
      remove :significance_low_count
      remove :significance_total_obligations
    end

    execute("CREATE VIEW lat AS SELECT * FROM legal_articles_uk")
  end
end
