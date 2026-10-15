defmodule SertantaiLegal.Repo.Migrations.AddLatLabelsTodayView do
  @moduledoc """
  LR-25: `lat_labels_today` — each provision's timeline period in force on
  the UK date (Europe/London), the "as at today" lookup every reader of
  today's labels joins (the LAT pull, the manifest's status_hash). A
  provision with no such period has no row: its labels are unknown. Built on
  `lat_label_timeline` (LR-24); dev-only.
  """
  use Ecto.Migration

  def up do
    execute("""
    CREATE VIEW lat_labels_today AS
    SELECT law_name, section_id, status, in_force_from, changed_by, territory
    FROM lat_label_timeline
    WHERE valid_from <= (now() AT TIME ZONE 'Europe/London')::date
      AND (valid_to IS NULL OR valid_to > (now() AT TIME ZONE 'Europe/London')::date)
    """)
  end

  def down do
    execute("DROP VIEW lat_labels_today")
  end
end
