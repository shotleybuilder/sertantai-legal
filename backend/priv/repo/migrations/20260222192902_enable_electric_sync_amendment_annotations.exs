defmodule SertantaiLegal.Repo.Migrations.EnableElectricSyncAmendmentAnnotations do
  @moduledoc """
  Enable ElectricSQL sync for the amendment_annotations table.

  The LAT table already has REPLICA IDENTITY FULL (set in 20260222143742_add_lat.exs).
  This migration adds the same for amendment_annotations so both tables can be
  synced to the frontend via ElectricSQL.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE amendment_annotations REPLICA IDENTITY FULL")
  end

  def down do
    execute("ALTER TABLE amendment_annotations REPLICA IDENTITY DEFAULT")
  end
end
