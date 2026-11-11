defmodule SertantaiLegal.Repo.Migrations.RestoreSchema do
  @moduledoc """
  The `restore` schema for in-database restore copies, and its registry
  `restore.points` (`SertantaiLegal.Restore`; DATA-ARCHITECTURE (f)). Not an
  Ash resource: written by raw SQL only.
  """

  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS restore"

    execute """
    CREATE TABLE restore.points (
      id bigserial PRIMARY KEY,
      tag text NOT NULL,
      copy text NOT NULL UNIQUE,
      source text NOT NULL,
      rows bigint NOT NULL,
      taken_at timestamptz NOT NULL DEFAULT now(),
      session text,
      nas_path text,
      dropped_at timestamptz
    )
    """
  end

  def down do
    execute "DROP TABLE restore.points"
    execute "DROP SCHEMA restore RESTRICT"
  end
end
