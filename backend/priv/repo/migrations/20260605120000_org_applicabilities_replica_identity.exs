defmodule SertantaiLegal.Repo.Migrations.OrgApplicabilitiesReplicaIdentity do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE org_applicabilities REPLICA IDENTITY FULL")
  end

  def down do
    execute("ALTER TABLE org_applicabilities REPLICA IDENTITY DEFAULT")
  end
end
