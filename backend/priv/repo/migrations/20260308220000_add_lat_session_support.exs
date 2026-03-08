defmodule SertantaiLegal.Repo.Migrations.AddLatSessionSupport do
  @moduledoc """
  Extend scrape_sessions and scrape_session_records for LAT parse sessions.

  Adds a session_type discriminator and LAT-specific result fields so the
  existing session infrastructure can be reused for batch LAT parsing.
  """
  use Ecto.Migration

  def up do
    # Add session type discriminator and LAT aggregate fields to scrape_sessions
    alter table(:scrape_sessions) do
      add(:session_type, :text, null: true)
      add(:lat_total_inserted, :integer, default: 0)
      add(:lat_total_annotations, :integer, default: 0)
    end

    # Add per-record LAT result fields to scrape_session_records
    alter table(:scrape_session_records) do
      add(:lat_inserted, :integer, null: true)
      add(:lat_deleted, :integer, null: true)
      add(:annotations_inserted, :integer, null: true)
      add(:parse_duration_ms, :integer, null: true)
      add(:parse_error, :text, null: true)
    end

    # Backfill session_type for existing sessions
    execute(
      "UPDATE scrape_sessions SET session_type = 'reparse' WHERE session_id LIKE 'reparse-%'"
    )

    execute("UPDATE scrape_sessions SET session_type = 'scrape' WHERE session_type IS NULL")

    # Index for filtering by session_type
    create(index(:scrape_sessions, [:session_type]))
  end

  def down do
    drop(index(:scrape_sessions, [:session_type]))

    alter table(:scrape_session_records) do
      remove(:lat_inserted)
      remove(:lat_deleted)
      remove(:annotations_inserted)
      remove(:parse_duration_ms)
      remove(:parse_error)
    end

    alter table(:scrape_sessions) do
      remove(:session_type)
      remove(:lat_total_inserted)
      remove(:lat_total_annotations)
    end
  end
end
