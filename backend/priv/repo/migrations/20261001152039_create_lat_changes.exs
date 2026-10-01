defmodule SertantaiLegal.Repo.Migrations.CreateLatChanges do
  @moduledoc """
  Per-row LAT change log (#167, L8.5), beside `lat_section_id_renames`: one
  row per changed row per parse — `change` (text_changed | inserted | removed |
  renamed | status_changed), its `cause` (legislative | parser | scope |
  correction | unattributed; `LatChangeLog`), the evidencing note
  `change_ids`, and `op_key` linking to the parse's `parsed` lat_event (and
  its operation cause). Kept indefinitely; served as `lat-changes/{law}`.
  """

  use Ecto.Migration

  def change do
    create table(:lat_changes) do
      add :law_name, :text, null: false
      add :op_key, :text, null: false
      add :section_id, :text
      add :old_section_id, :text
      add :change, :text, null: false
      add :cause, :text, null: false
      add :change_ids, {:array, :text}, null: false, default: []
      add :created_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create constraint(:lat_changes, :lat_changes_change_check,
             check:
               "change IN ('text_changed', 'inserted', 'removed', 'renamed', 'status_changed')"
           )

    create constraint(:lat_changes, :lat_changes_cause_check,
             check: "cause IN ('legislative', 'parser', 'scope', 'correction', 'unattributed')"
           )

    create index(:lat_changes, [:law_name, :created_at])
    create index(:lat_changes, [:created_at])
    create index(:lat_changes, [:op_key])
  end
end
