defmodule SertantaiLegal.Sync.Delta.Config do
  @moduledoc "Table configuration for delta sync."

  # Columns that exist only in dev (not in prod) — exclude from delta export.
  # Update this list as prod catches up with migrations.
  #
  # NOTE: the uk_lrt export reads LegalRegister (the legal_register table) but
  # writes `INSERT INTO uk_lrt` on prod, so every exported column must exist
  # in the uk_lrt view (guarded by test/sertantai_legal/sync/delta/config_test.exs).
  # Unmark a family once legal's prod migration (#133) adds it and compliance
  # asks for it (agreed with sertantai-compliance 2026-10-01; compliance's
  # Legal.* resources are read-only and tolerate extra columns).
  @dev_only_columns %{
    # fractalaw #73 R1a current view + #72 correlatives (2026-10-01): not in
    # compliance's prod schema yet.
    # is_making provenance and fractalaw making verdict
    # fractalaw v2.4 application (#163) — compliance's v0.1 jurisdiction gate
    # needs application_regions in prod if #163 ships: tell compliance
    # before leaving it dev-only past #133
    # LAT / live status
    "uk_lrt" =>
      ~w(current_verdict current_duty_type current_duty_holder current_rights_holder
                   current_responsibility_holder current_power_holder claim_holder
                   liability_holder protected_holder) ++
        ~w(is_making_reason is_making_source is_making_decided_at making_classification_source
           making_enriched_at making_enrichment_verdict) ++
        ~w(application_regions application_source application_evidence application_clause) ++
        ~w(lat_scope lat_hash struct_hash live_evidence document_status) ++
        ~w(definitions_parsed_at enabling_provisions geo_extent_source),
    "lat" => [],
    "amendment_annotations" => [],
    "legislative_definitions" => [],
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
      # set by the uk_lrt view triggers (not columns of the view)
      "country",
      "jurisdiction",
      "number_int",
      "has_fitness",
      "md_date_year",
      "md_date_month",
      "lat_count",
      "latest_lat_updated_at"
    ],
    "lat" => [],
    "amendment_annotations" => [],
    "legislative_definitions" => [],
    "scrape_sessions" => [],
    "scrape_session_records" => [],
    "cascade_affected_laws" => []
  }

  @tables [
    %{
      name: "uk_lrt",
      resource: SertantaiLegal.Legal.LegalRegister,
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
      name: "legislative_definitions",
      resource: SertantaiLegal.Legal.LegislativeDefinition,
      pk: "id",
      timestamp_col: "updated_at",
      order: 4
    },
    %{
      name: "scrape_sessions",
      resource: SertantaiLegal.Scraper.ScrapeSession,
      pk: "id",
      timestamp_col: "updated_at",
      order: 5
    },
    %{
      name: "scrape_session_records",
      resource: SertantaiLegal.Scraper.ScrapeSessionRecord,
      pk: "id",
      timestamp_col: "updated_at",
      order: 6
    },
    %{
      name: "cascade_affected_laws",
      resource: SertantaiLegal.Scraper.CascadeAffectedLaw,
      pk: "id",
      timestamp_col: "updated_at",
      order: 7
    }
  ]

  def tables, do: @tables |> Enum.sort_by(& &1.order)

  def excluded_columns(table_name) do
    dev_only = Map.get(@dev_only_columns, table_name, [])
    generated = Map.get(@generated_columns, table_name, [])
    dev_only ++ generated
  end
end
