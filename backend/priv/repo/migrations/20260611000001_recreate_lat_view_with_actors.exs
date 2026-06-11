defmodule SertantaiLegal.Repo.Migrations.RecreatLatViewWithActors do
  @moduledoc """
  Recreate the `lat` backwards-compat view to include actors + extraction_method.

  These columns were added to legal_articles in migration 20260606212436 but
  the lat view (SELECT * FROM legal_articles_uk) wasn't updated — it kept
  the old column set. This caused "column does not exist" errors when
  queries referenced actors via the lat view.
  """

  use Ecto.Migration

  def up do
    execute("DROP VIEW IF EXISTS lat")
    execute("CREATE VIEW lat AS SELECT * FROM legal_articles_uk")
  end

  def down do
    # Reverting would lose the actors column from the view, which breaks queries.
    # No-op — the view should always include all columns.
    :ok
  end
end
