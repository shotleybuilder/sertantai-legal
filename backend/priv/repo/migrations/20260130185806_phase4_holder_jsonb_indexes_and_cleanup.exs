defmodule SertantaiLegal.Repo.Migrations.Phase4HolderJsonbIndexesAndCleanup do
  @moduledoc """
  Phase 4 of Issue #14: JSONB holder column consolidation cleanup.

  1. Adds GIN indexes on new JSONB columns for efficient querying
  2. Drops 16 deprecated text columns that have been replaced by 4 JSONB columns

  Storage impact: 78 MB (16 text columns) → 5.6 MB (4 JSONB columns) = 93% reduction
  """

  use Ecto.Migration

  @deprecated_columns [
    # Duty holder text columns (4)
    :duty_holder_article,
    :duty_holder_article_clause,
    :article_duty_holder,
    :article_duty_holder_clause,
    # Power holder text columns (4)
    :power_holder_article,
    :power_holder_article_clause,
    :article_power_holder,
    :article_power_holder_clause,
    # Rights holder text columns (4)
    :rights_holder_article,
    :rights_holder_article_clause,
    :article_rights_holder,
    :article_rights_holder_clause,
    # Responsibility holder text columns (4)
    :responsibility_holder_article,
    :responsibility_holder_article_clause,
    :article_responsibility_holder,
    :article_responsibility_holder_clause
  ]

  def up do
    # Create GIN indexes on JSONB columns for efficient querying
    # GIN indexes support operators: @>, <@, ?, ?|, ?&
    # Useful for: searching by holder name, checking if holder exists, etc.

    # Index on the 'holders' array within each JSONB column
    create(index(:uk_lrt, ["(duties->'holders')"], name: :uk_lrt_duties_holders_gin, using: :gin))
    create(index(:uk_lrt, ["(rights->'holders')"], name: :uk_lrt_rights_holders_gin, using: :gin))

    create(
      index(:uk_lrt, ["(responsibilities->'holders')"],
        name: :uk_lrt_responsibilities_holders_gin,
        using: :gin
      )
    )

    create(index(:uk_lrt, ["(powers->'holders')"], name: :uk_lrt_powers_holders_gin, using: :gin))

    # Drop deprecated text columns
    alter table(:uk_lrt) do
      for col <- @deprecated_columns do
        remove(col)
      end
    end
  end

  def down do
    # Drop GIN indexes
    drop(index(:uk_lrt, [:duties], name: :uk_lrt_duties_holders_gin))
    drop(index(:uk_lrt, [:rights], name: :uk_lrt_rights_holders_gin))
    drop(index(:uk_lrt, [:responsibilities], name: :uk_lrt_responsibilities_holders_gin))
    drop(index(:uk_lrt, [:powers], name: :uk_lrt_powers_holders_gin))

    # Re-add deprecated text columns (data will be lost)
    alter table(:uk_lrt) do
      add(:duty_holder_article, :text)
      add(:duty_holder_article_clause, :text)
      add(:article_duty_holder, :text)
      add(:article_duty_holder_clause, :text)
      add(:power_holder_article, :text)
      add(:power_holder_article_clause, :text)
      add(:article_power_holder, :text)
      add(:article_power_holder_clause, :text)
      add(:rights_holder_article, :text)
      add(:rights_holder_article_clause, :text)
      add(:article_rights_holder, :text)
      add(:article_rights_holder_clause, :text)
      add(:responsibility_holder_article, :text)
      add(:responsibility_holder_article_clause, :text)
      add(:article_responsibility_holder, :text)
      add(:article_responsibility_holder_clause, :text)
    end
  end
end
