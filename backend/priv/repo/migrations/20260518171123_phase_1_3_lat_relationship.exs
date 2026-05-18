defmodule SertantaiLegal.Repo.Migrations.Phase13LatRelationship do
  @moduledoc """
  No-op migration for Ash snapshot tracking.

  The Lat resource's belongs_to now points to LegalRegister, but the underlying
  `lat` is a view backed by `legal_articles` which already has its FK to
  `legal_register`. This migration exists only for Ash codegen tracking.
  """

  use Ecto.Migration

  def up do
    :ok
  end

  def down do
    :ok
  end
end
