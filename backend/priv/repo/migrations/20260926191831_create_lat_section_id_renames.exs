defmodule SertantaiLegal.Repo.Migrations.CreateLatSectionIdRenames do
  @moduledoc """
  Durable log of section_id changes made by LAT re-parses (Gemini review
  2026-09-26; fractalatai #62). Written by `LatPersister` in the same
  transaction as the re-parse; served to fractalaw as
  `lat-renames/{law}` / `lat-renames/*` so its hub can carry tier data across
  id changes using legal's map first, text matching only as a fallback.

  status: `renamed` (old → new, `match` = unique_text | ordered_text),
  `ambiguous` (text shared by unequal groups; new_section_id NULL — needs
  review), `dropped` (old id with no counterpart; new_section_id NULL).
  Kept indefinitely; consumers filter by `created_at`.
  """

  use Ecto.Migration

  def change do
    create table(:lat_section_id_renames) do
      add :law_name, :text, null: false
      add :old_section_id, :text, null: false
      add :new_section_id, :text
      add :status, :text, null: false
      add :match, :text
      add :reparse_id, :uuid, null: false
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:lat_section_id_renames, [:law_name, :created_at])
    create index(:lat_section_id_renames, [:created_at])
  end
end
