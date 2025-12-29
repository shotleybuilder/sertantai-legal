defmodule SertantaiLegal.Repo.Migrations.AddRoleArticleColumns do
  @moduledoc """
  Adds article/clause columns for DRRP model (Duty, Rights, Responsibility, Power holders).
  Uses conditional column addition to handle both fresh installs and existing databases.
  """

  use Ecto.Migration

  def up do
    # Role columns
    add_column_if_not_exists(:uk_lrt, :article_role, :text)
    add_column_if_not_exists(:uk_lrt, :role_article, :text)

    # Duty Holder columns
    add_column_if_not_exists(:uk_lrt, :duty_holder_article, :text)
    add_column_if_not_exists(:uk_lrt, :duty_holder_article_clause, :text)
    add_column_if_not_exists(:uk_lrt, :article_duty_holder, :text)
    add_column_if_not_exists(:uk_lrt, :article_duty_holder_clause, :text)

    # Power Holder columns
    add_column_if_not_exists(:uk_lrt, :power_holder_article, :text)
    add_column_if_not_exists(:uk_lrt, :power_holder_article_clause, :text)
    add_column_if_not_exists(:uk_lrt, :article_power_holder, :text)
    add_column_if_not_exists(:uk_lrt, :article_power_holder_clause, :text)

    # Rights Holder columns
    add_column_if_not_exists(:uk_lrt, :rights_holder_article, :text)
    add_column_if_not_exists(:uk_lrt, :rights_holder_article_clause, :text)
    add_column_if_not_exists(:uk_lrt, :article_rights_holder, :text)
    add_column_if_not_exists(:uk_lrt, :article_rights_holder_clause, :text)

    # Responsibility Holder columns
    add_column_if_not_exists(:uk_lrt, :responsibility_holder_article, :text)
    add_column_if_not_exists(:uk_lrt, :responsibility_holder_article_clause, :text)
    add_column_if_not_exists(:uk_lrt, :article_responsibility_holder, :text)
    add_column_if_not_exists(:uk_lrt, :article_responsibility_holder_clause, :text)

    # POPIMAR clause columns (article columns already exist)
    add_column_if_not_exists(:uk_lrt, :popimar_article_clause, :text)
    add_column_if_not_exists(:uk_lrt, :article_popimar_clause, :text)
  end

  def down do
    # No-op - we don't drop columns to preserve data
    # Columns will remain in database even after rollback
    :ok
  end

  defp add_column_if_not_exists(table, column, type) do
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = '#{table}' AND column_name = '#{column}'
      ) THEN
        ALTER TABLE #{table} ADD COLUMN #{column} #{type_to_sql(type)};
      END IF;
    END $$;
    """
  end

  defp type_to_sql(:text), do: "TEXT"
end
