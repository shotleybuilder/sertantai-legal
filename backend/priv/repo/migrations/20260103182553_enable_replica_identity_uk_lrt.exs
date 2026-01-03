defmodule SertantaiLegal.Repo.Migrations.EnableReplicaIdentityUkLrt do
  use Ecto.Migration

  @doc """
  Enable REPLICA IDENTITY FULL on uk_lrt table for ElectricSQL sync.
  This is required for ElectricSQL to properly track changes via logical replication.
  """
  def up do
    execute("ALTER TABLE uk_lrt REPLICA IDENTITY FULL")
  end

  def down do
    execute("ALTER TABLE uk_lrt REPLICA IDENTITY DEFAULT")
  end
end
