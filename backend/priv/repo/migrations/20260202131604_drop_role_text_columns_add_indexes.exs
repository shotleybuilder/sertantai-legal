defmodule SertantaiLegal.Repo.Migrations.DropRoleTextColumnsAddIndexes do
  @moduledoc """
  Phase 4 Issue #16: Drop deprecated role text columns and add GIN indexes.

  Drops:
  - role_article
  - article_role
  - article_role_gvt
  - role_gvt_article

  Adds GIN indexes for efficient JSONB queries on:
  - role_details
  - role_gvt_details
  """

  use Ecto.Migration

  def up do
    # Drop deprecated text columns
    alter table(:uk_lrt) do
      remove(:role_article)
      remove(:article_role)
      remove(:article_role_gvt)
      remove(:role_gvt_article)
    end

    # Add GIN indexes for efficient JSONB queries
    # Using jsonb_path_ops for better performance on containment queries
    create(index(:uk_lrt, [:role_details], using: "GIN", name: "uk_lrt_role_details_gin_idx"))

    create(
      index(:uk_lrt, [:role_gvt_details],
        using: "GIN",
        name: "uk_lrt_role_gvt_details_gin_idx"
      )
    )
  end

  def down do
    # Remove GIN indexes
    drop_if_exists(index(:uk_lrt, [:role_details], name: "uk_lrt_role_details_gin_idx"))
    drop_if_exists(index(:uk_lrt, [:role_gvt_details], name: "uk_lrt_role_gvt_details_gin_idx"))

    # Restore deprecated text columns
    alter table(:uk_lrt) do
      add(:role_gvt_article, :text)
      add(:article_role_gvt, :text)
      add(:article_role, :text)
      add(:role_article, :text)
    end
  end
end
