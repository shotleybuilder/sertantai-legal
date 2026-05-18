defmodule SertantaiLegal.Sync.Delta.Config do
  @moduledoc "Table configuration for delta sync."

  # Columns that exist only in dev (not in prod) — exclude from delta export.
  # Update this list as prod catches up with migrations.
  #
  # NOTE: Delta export uses Ash resources which still point at the uk_lrt/lat views.
  # The views proxy to legal_register/legal_articles transparently.
  # The "country" and "jurisdiction" columns are set by the view triggers,
  # so they don't appear in the Ash resource and don't need excluding.
  @dev_only_columns %{
    "uk_lrt" => [],
    "lat" => [],
    "amendment_annotations" => [],
    "scrape_sessions" => [],
    "scrape_session_records" => [],
    "cascade_affected_laws" => []
  }

  # Columns auto-populated by triggers or GENERATED ALWAYS — never write.
  #
  # After the partition migration (legal_register):
  #   - number_int and has_fitness are GENERATED ALWAYS on the underlying table
  #   - leg_gov_uk_url is now a view alias for source_url (not generated)
  #   - md_date_year/month are populated by trigger
  #   - lat_count/latest_lat_updated_at are populated by trigger
  #   - source_url is a regular column written via the view as leg_gov_uk_url
  @generated_columns %{
    "uk_lrt" => [
      "number_int",
      "has_fitness",
      "md_date_year",
      "md_date_month",
      "lat_count",
      "latest_lat_updated_at"
    ],
    "lat" => [],
    "amendment_annotations" => [],
    "scrape_sessions" => [],
    "scrape_session_records" => [],
    "cascade_affected_laws" => []
  }

  @tables [
    %{
      name: "uk_lrt",
      resource: SertantaiLegal.Legal.UkLrt,
      pk: "id",
      timestamp_col: "updated_at",
      order: 1
    },
    %{
      name: "lat",
      resource: SertantaiLegal.Legal.Lat,
      pk: "section_id",
      timestamp_col: "updated_at",
      order: 2
    },
    %{
      name: "amendment_annotations",
      resource: SertantaiLegal.Legal.AmendmentAnnotation,
      pk: "id",
      timestamp_col: "updated_at",
      order: 3
    },
    %{
      name: "scrape_sessions",
      resource: SertantaiLegal.Scraper.ScrapeSession,
      pk: "id",
      timestamp_col: "updated_at",
      order: 4
    },
    %{
      name: "scrape_session_records",
      resource: SertantaiLegal.Scraper.ScrapeSessionRecord,
      pk: "id",
      timestamp_col: "updated_at",
      order: 5
    },
    %{
      name: "cascade_affected_laws",
      resource: SertantaiLegal.Scraper.CascadeAffectedLaw,
      pk: "id",
      timestamp_col: "updated_at",
      order: 6
    }
  ]

  def tables, do: @tables |> Enum.sort_by(& &1.order)

  def excluded_columns(table_name) do
    dev_only = Map.get(@dev_only_columns, table_name, [])
    generated = Map.get(@generated_columns, table_name, [])
    dev_only ++ generated
  end
end
