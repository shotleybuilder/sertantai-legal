defmodule SertantaiLegal.Repo.Migrations.RecreateUkLrtView do
  @moduledoc """
  Recreate uk_lrt backwards-compat view to include significance columns
  added to legal_register in migration 20260702000001.
  """

  use Ecto.Migration

  def up do
    execute("DROP VIEW IF EXISTS uk_lrt")
    execute("CREATE VIEW uk_lrt AS SELECT * FROM legal_register_uk")
  end

  def down do
    :ok
  end
end
