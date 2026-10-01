defmodule SertantaiLegal.Repo.Migrations.AddCauseToLatEvents do
  @moduledoc """
  Why a LAT parse changed the law (#167, L8.3), on `parsed` lat_events:
  `cause` (initial | legislative | parser | scope | correction | unattributed),
  `source_hash` (SHA-256 of the fetched CLML), `source_valid_date`
  (legislation.gov.uk `<dct:valid>`), `source_paths` (the fetched
  data.xml paths; a change means a scope change). Set by `LatCause.Apply`
  after the parse; NULL on events before L8.3.
  """

  use Ecto.Migration

  def change do
    alter table(:lat_events) do
      add :cause, :text
      add :source_hash, :text
      add :source_valid_date, :date
      add :source_paths, {:array, :text}
    end

    create constraint(:lat_events, :lat_events_cause_check,
             check:
               "cause IS NULL OR cause IN ('initial', 'legislative', 'parser', 'scope', 'correction', 'unattributed')"
           )

    create index(:lat_events, [:cause])
  end
end
