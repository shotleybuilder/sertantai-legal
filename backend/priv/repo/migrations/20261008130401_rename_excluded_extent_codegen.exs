defmodule SertantaiLegal.Repo.Migrations.RenameExcludedExtentCodegen do
  @moduledoc """
  No-op — the rename to excluded_extent (column and `lat` view) was done by
  manual migration 20261008130300. Keeps the Ash snapshots in sync.
  """

  use Ecto.Migration

  def up do
    # Renamed by manual migration 20261008130300
  end

  def down do
  end
end
