defmodule SertantaiLegal.Repo.Migrations.AddSignificanceParts do
  @moduledoc """
  Add significance_parts column to legal_register for Part-level
  significance breakdown in large Acts.
  """

  use Ecto.Migration

  def up do
    alter table(:legal_register) do
      add :significance_parts, :jsonb
    end
  end

  def down do
    alter table(:legal_register) do
      remove :significance_parts
    end
  end
end
