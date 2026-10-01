defmodule SertantaiLegal.Repo.Migrations.AddCauseToLatEventsCodegen do
  @moduledoc """
  No-op — cause/source_hash/source_valid_date/source_paths (+ check, index)
  added by manual migration 20261001145350. Keeps the Ash snapshot in sync.
  """

  use Ecto.Migration

  def up do
    # Columns already exist from manual migration 20261001145350
  end

  def down do
  end
end
