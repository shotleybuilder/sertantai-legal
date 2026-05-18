defmodule SertantaiLegal.Repo.Migrations.AddLegalRegisterResource do
  @moduledoc """
  No-op migration for Ash snapshot tracking.

  The legal_register and legal_articles tables were created by the partition
  migration (20260518000001_partition_legal_register.exs). This migration
  exists only to satisfy Ash's codegen check — the resource snapshots record
  the current schema state for future diff-based migrations.
  """

  use Ecto.Migration

  def up do
    # Tables already exist from partition migration. Nothing to do.
    :ok
  end

  def down do
    # Nothing was created, nothing to undo.
    :ok
  end
end
