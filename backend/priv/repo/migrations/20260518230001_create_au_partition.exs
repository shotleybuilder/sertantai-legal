defmodule SertantaiLegal.Repo.Migrations.CreateAuPartition do
  @moduledoc """
  Create Australian partitions for legal_register and legal_articles.

  Adding a new country is just CREATE TABLE ... PARTITION OF — no schema migration needed.
  """

  use Ecto.Migration

  def up do
    execute "CREATE TABLE legal_register_au PARTITION OF legal_register FOR VALUES IN ('au');"
    execute "CREATE TABLE legal_articles_au PARTITION OF legal_articles FOR VALUES IN ('au');"

    # Enable ElectricSQL sync
    execute "ALTER TABLE legal_register_au REPLICA IDENTITY FULL;"
    execute "ALTER TABLE legal_articles_au REPLICA IDENTITY FULL;"
  end

  def down do
    execute "DROP TABLE IF EXISTS legal_articles_au;"
    execute "DROP TABLE IF EXISTS legal_register_au;"
  end
end
