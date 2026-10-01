defmodule SertantaiLegal.Repo.Migrations.AddStatusToLegalArticlesCodegen do
  @moduledoc """
  No-op — `status` already added to legal_articles and the `lat` view by
  manual migration 20261001113358. Keeps the Ash snapshots in sync.
  """

  use Ecto.Migration

  def up do
    # Column already exists from manual migration 20261001113358
  end

  def down do
  end
end
