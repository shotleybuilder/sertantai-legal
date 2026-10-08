defmodule SertantaiLegal.Repo.Migrations.AddRepealedExtentCodegen do
  @moduledoc """
  No-op — legal_articles.repealed_extent and the `lat` view column were added
  by manual migration 20261008110200. Keeps the Ash snapshots in sync.
  """

  use Ecto.Migration

  def up do
    # Column already exists from manual migration 20261008110200
  end

  def down do
  end
end
