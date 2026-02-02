defmodule SertantaiLegal.Repo.Migrations.DropPopimarTextColumnsPhase4 do
  @moduledoc """
  Phase 4 Issue #15: Drop deprecated POPIMAR text columns and add GIN indexes.

  This migration:
  1. Drops the 4 deprecated text columns (replaced by popimar_details JSONB)
  2. Adds GIN indexes for efficient JSONB queries on popimar_details

  The popimar_details JSONB field was added in Phase 1 and contains:
  - entries: [{category, article}, ...]
  - categories: [unique category names]
  - articles: [unique article refs]
  """

  use Ecto.Migration

  def up do
    # Drop deprecated text columns (data migrated to popimar_details in Phase 1)
    alter table(:uk_lrt) do
      remove(:article_popimar_clause)
      remove(:article_popimar)
      remove(:popimar_article_clause)
      remove(:popimar_article)
    end

    # Add GIN indexes for efficient JSONB queries
    # Index on categories array for "has category X?" queries
    create(
      index(:uk_lrt, ["(popimar_details->'categories')"],
        name: :idx_uk_lrt_popimar_categories,
        using: "GIN",
        where: "popimar_details IS NOT NULL"
      )
    )

    # Index on entries array for category+article combination searches
    create(
      index(:uk_lrt, ["(popimar_details->'entries') jsonb_path_ops"],
        name: :idx_uk_lrt_popimar_entries,
        using: "GIN",
        where: "popimar_details IS NOT NULL"
      )
    )
  end

  def down do
    # Drop indexes
    drop_if_exists(index(:uk_lrt, [], name: :idx_uk_lrt_popimar_entries))
    drop_if_exists(index(:uk_lrt, [], name: :idx_uk_lrt_popimar_categories))

    # Restore columns (data will be lost)
    alter table(:uk_lrt) do
      add(:popimar_article, :text)
      add(:popimar_article_clause, :text)
      add(:article_popimar, :text)
      add(:article_popimar_clause, :text)
    end
  end
end
