defmodule SertantaiLegal.Repo.Migrations.AddChangeFieldsCodegen do
  @moduledoc """
  No-op — the note fields, row fields, change_id index and `lat` view column
  were added by manual migration 20261001123705. Keeps the Ash snapshots in sync.
  """

  use Ecto.Migration

  def up do
    # Columns already exist from manual migration 20261001123705
  end

  def down do
  end
end
