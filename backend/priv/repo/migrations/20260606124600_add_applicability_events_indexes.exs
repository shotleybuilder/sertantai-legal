defmodule SertantaiLegal.Repo.Migrations.AddApplicabilityEventsIndexes do
  use Ecto.Migration

  def up do
    create index(:applicability_events, [:organization_id])
    create index(:applicability_events, [:organization_id, :law_name])
    create index(:applicability_events, [:organization_id, :inserted_at])
  end

  def down do
    drop index(:applicability_events, [:organization_id])
    drop index(:applicability_events, [:organization_id, :law_name])
    drop index(:applicability_events, [:organization_id, :inserted_at])
  end
end
