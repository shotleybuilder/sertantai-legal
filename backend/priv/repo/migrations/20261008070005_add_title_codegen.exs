defmodule SertantaiLegal.Repo.Migrations.AddTitleCodegen do
  @moduledoc """
  No-op — legal_articles.title and the `lat` view column were added by manual
  migration 20261008070000. Keeps the Ash snapshots in sync.
  """

  use Ecto.Migration

  def up do
    # Column already exists from manual migration 20261008070000
  end

  def down do
  end
end
