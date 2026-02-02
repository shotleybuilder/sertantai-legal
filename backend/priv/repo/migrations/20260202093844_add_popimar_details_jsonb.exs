defmodule SertantaiLegal.Repo.Migrations.AddPopimarDetailsJsonb do
  @moduledoc """
  Phase 1 of Issue #15: Add consolidated POPIMAR JSONB column.

  This adds the popimar_details column which will consolidate:
  - popimar_article
  - popimar_article_clause
  - article_popimar
  - article_popimar_clause

  Structure:
  {
    "entries": [{"category": "Records", "article": "regulation/4"}],
    "categories": ["Records", ...],
    "articles": ["regulation/4", ...]
  }
  """

  use Ecto.Migration

  def up do
    alter table(:uk_lrt) do
      add(:popimar_details, :map)
    end
  end

  def down do
    alter table(:uk_lrt) do
      remove(:popimar_details)
    end
  end
end
