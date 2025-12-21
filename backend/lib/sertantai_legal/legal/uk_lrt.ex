defmodule SertantaiLegal.Legal.UkLrt do
  @moduledoc """
  UK Legal Register Table (LRT) - Reference data for UK legislation.

  This resource stores metadata for UK laws, regulations, and statutory instruments.
  It is SHARED REFERENCE DATA - no organization_id (accessible to all tenants).

  ## Key Fields
  - `family` / `family_ii`: Primary/secondary classification (e.g., "Environment", "Health & Safety")
  - `function`: JSONB indicating law type - Making, Amending, Revoking, Commencing, Enacting
  - `duty_holder` / `power_holder` / `rights_holder`: JSONB fields for applicability screening
  - `geo_extent` / `geo_region`: Geographic scope of the law
  - `live` / `live_description`: Current enforcement status

  ## Data Source
  19,000+ records imported from legislation.gov.uk and enhanced with SertantAI metadata.

  ## Usage
  This data is used for:
  1. Legal applicability screening (matching laws to business activities)
  2. Compliance register generation
  3. Change tracking and amendment monitoring
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  postgres do
    table "uk_lrt"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id, writable?: true

    # Core Identifiers
    attribute :family, :string do
      allow_nil? true
      description "Primary family classification (e.g., Environment, Health & Safety)"
    end

    attribute :family_ii, :string do
      allow_nil? true
      description "Secondary family classification"
    end

    attribute :name, :string do
      allow_nil? true
      description "Short reference name"
    end

    attribute :title_en, :string do
      allow_nil? true
      description "Full English title of the legislation"
    end

    attribute :year, :integer do
      allow_nil? true
      description "Year of enactment"
    end

    attribute :number, :string do
      allow_nil? true
      description "Legislation number (e.g., 'SI 2024/123')"
    end

    attribute :number_int, :integer do
      allow_nil? true
      description "Numeric version of legislation number for sorting"
    end

    attribute :acronym, :string do
      allow_nil? true
      description "Common acronym (e.g., 'COSHH', 'RIDDOR')"
    end

    attribute :old_style_number, :string do
      allow_nil? true
      description "Historical numbering format"
    end

    # Type Classification
    attribute :type_desc, :string do
      allow_nil? true
      description "Full type description (e.g., 'UK Public General Acts')"
    end

    attribute :type_code, :string do
      allow_nil? true
      description "Type code (e.g., 'ukpga', 'uksi')"
    end

    attribute :type_class, :string do
      allow_nil? true
      description "Type class (Primary, Secondary)"
    end

    attribute :secondary_class, :string do
      allow_nil? true
      description "Secondary classification"
    end

    # Status
    attribute :live, :string do
      allow_nil? true
      description "Enforcement status (e.g., '✔ In force', '✗ Revoked')"
    end

    attribute :live_description, :string do
      allow_nil? true
      description "Detailed status description"
    end

    # Geographic Scope
    attribute :geo_extent, :string do
      allow_nil? true
      description "Geographic extent (e.g., 'E+W+S+NI', 'E+W')"
    end

    attribute :geo_region, :string do
      allow_nil? true
      description "Specific regions covered"
    end

    attribute :geo_country, :map do
      allow_nil? true
      description "Country-level geographic scope (JSONB)"
    end

    attribute :md_restrict_extent, :string do
      allow_nil? true
      description "Restriction extent from legislation.gov.uk"
    end

    # Holder Fields (for applicability screening)
    attribute :duty_holder, :map do
      allow_nil? true
      description "Entities with duties under this law (JSONB)"
    end

    attribute :power_holder, :map do
      allow_nil? true
      description "Entities granted powers by this law (JSONB)"
    end

    attribute :rights_holder, :map do
      allow_nil? true
      description "Entities granted rights by this law (JSONB)"
    end

    attribute :responsibility_holder, :map do
      allow_nil? true
      description "Entities with responsibilities under this law (JSONB)"
    end

    # Purpose and Function
    attribute :purpose, :map do
      allow_nil? true
      description "Legal purposes and objectives (JSONB)"
    end

    attribute :function, :map do
      allow_nil? true
      description "Function: Making, Amending, Revoking, Commencing, Enacting (JSONB)"
    end

    attribute :popimar, :map do
      allow_nil? true
      description "POPIMAR framework classification (JSONB)"
    end

    attribute :si_code, :map do
      allow_nil? true
      description "Statutory Instrument code classification (JSONB)"
    end

    attribute :md_subjects, :map do
      allow_nil? true
      description "Subject matter classification (JSONB)"
    end

    # Role and Government
    attribute :role, {:array, :string} do
      allow_nil? true
      description "Role classifications"
    end

    attribute :role_gvt, :map do
      allow_nil? true
      description "Government role classifications (JSONB)"
    end

    attribute :tags, {:array, :string} do
      allow_nil? true
      description "Searchable tags"
    end

    # Description
    attribute :md_description, :string do
      allow_nil? true
      description "Markdown description of the legislation"
    end

    # Document Statistics (from legislation.gov.uk)
    attribute :md_total_paras, :decimal do
      allow_nil? true
      description "Total paragraph count"
    end

    attribute :md_body_paras, :integer do
      allow_nil? true
      description "Body paragraph count"
    end

    attribute :md_schedule_paras, :integer do
      allow_nil? true
      description "Schedule paragraph count"
    end

    attribute :md_attachment_paras, :integer do
      allow_nil? true
      description "Attachment paragraph count"
    end

    attribute :md_images, :integer do
      allow_nil? true
      description "Image count in document"
    end

    # Amendment/Relationship Tracking
    attribute :amending, {:array, :string} do
      allow_nil? true
      description "Laws this legislation amends"
    end

    attribute :amended_by, {:array, :string} do
      allow_nil? true
      description "Laws that have amended this legislation"
    end

    attribute :rescinding, {:array, :string} do
      allow_nil? true
      description "Laws this legislation rescinds/revokes"
    end

    attribute :rescinded_by, {:array, :string} do
      allow_nil? true
      description "Laws that have rescinded this legislation"
    end

    attribute :enacting, {:array, :string} do
      allow_nil? true
      description "Laws this legislation enacts"
    end

    attribute :enacted_by, {:array, :string} do
      allow_nil? true
      description "Parent enabling legislation"
    end

    # Linked Relationship Arrays (for graph visualization)
    attribute :linked_amending, {:array, :string} do
      allow_nil? true
      description "Linked laws this legislation amends (graph edges)"
    end

    attribute :linked_amended_by, {:array, :string} do
      allow_nil? true
      description "Linked laws that amended this (graph edges)"
    end

    attribute :linked_rescinding, {:array, :string} do
      allow_nil? true
      description "Linked laws this rescinds/revokes (graph edges)"
    end

    attribute :linked_rescinded_by, {:array, :string} do
      allow_nil? true
      description "Linked laws that rescinded this (graph edges)"
    end

    attribute :linked_enacted_by, {:array, :string} do
      allow_nil? true
      description "Linked parent enabling legislation (graph edges)"
    end

    # Boolean Flags
    attribute :is_amending, :boolean do
      allow_nil? true
      description "Whether this primarily amends other laws"
    end

    attribute :is_rescinding, :boolean do
      allow_nil? true
      description "Whether this primarily rescinds other laws"
    end

    attribute :is_enacting, :boolean do
      allow_nil? true
      description "Whether this is enabling legislation"
    end

    attribute :is_making, :decimal do
      allow_nil? true
      description "Making function flag (1.0 = creates duties, used in screening)"
    end

    attribute :is_commencing, :decimal do
      allow_nil? true
      description "Commencing function flag (1.0 = brings other laws into force)"
    end

    # Key Dates
    attribute :created_at, :utc_datetime do
      allow_nil? true
      writable? false
      description "Record creation timestamp"
    end

    attribute :md_date, :date do
      allow_nil? true
      description "Primary date from legislation"
    end

    attribute :md_made_date, :date do
      allow_nil? true
      description "Date made (for SIs)"
    end

    attribute :md_enactment_date, :date do
      allow_nil? true
      description "Date of enactment"
    end

    attribute :md_coming_into_force_date, :date do
      allow_nil? true
      description "Coming into force date"
    end

    attribute :md_dct_valid_date, :date do
      allow_nil? true
      description "DCT valid date from legislation.gov.uk"
    end

    attribute :md_restrict_start_date, :date do
      allow_nil? true
      description "Restriction start date from legislation.gov.uk"
    end

    attribute :latest_amend_date, :date do
      allow_nil? true
      description "Date of most recent amendment"
    end

    attribute :latest_change_date, :date do
      allow_nil? true
      description "Date of most recent change"
    end

    attribute :latest_rescind_date, :date do
      allow_nil? true
      description "Date of most recent rescission/revocation"
    end

    # External Reference
    attribute :leg_gov_uk_url, :string do
      allow_nil? true
      description "legislation.gov.uk URL"
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Create a new UK LRT record"
      primary? true
      accept :*
    end

    update :update do
      description "Update an existing UK LRT record"
      accept :*
    end

    read :by_id do
      description "Get a single record by ID"
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :by_family do
      description "Filter records by family classification"
      argument :family, :string, allow_nil?: false
      filter expr(family == ^arg(:family))
      pagination offset?: true, keyset?: true, default_limit: 50
    end

    read :by_family_ii do
      description "Filter records by secondary family classification"
      argument :family_ii, :string, allow_nil?: false
      filter expr(family_ii == ^arg(:family_ii))
      pagination offset?: true, keyset?: true, default_limit: 50
    end

    read :by_families do
      description "Filter records by both family classifications"
      argument :family, :string, allow_nil?: true
      argument :family_ii, :string, allow_nil?: true

      filter expr(
               if is_nil(^arg(:family)) do
                 true
               else
                 family == ^arg(:family)
               end and
                 if is_nil(^arg(:family_ii)) do
                   true
                 else
                   family_ii == ^arg(:family_ii)
                 end
             )

      pagination offset?: true, keyset?: true, default_limit: 50
    end

    read :paginated do
      description "Paginated read with optional filtering and search"
      argument :family, :string, allow_nil?: true
      argument :year, :integer, allow_nil?: true
      argument :type_code, :string, allow_nil?: true
      argument :status, :string, allow_nil?: true
      argument :search, :string, allow_nil?: true

      filter expr(
               if is_nil(^arg(:family)) do
                 true
               else
                 family == ^arg(:family)
               end and
                 if is_nil(^arg(:year)) do
                   true
                 else
                   year == ^arg(:year)
                 end and
                 if is_nil(^arg(:type_code)) do
                   true
                 else
                   type_code == ^arg(:type_code)
                 end and
                 if is_nil(^arg(:status)) do
                   true
                 else
                   live == ^arg(:status)
                 end and
                 if is_nil(^arg(:search)) do
                   true
                 else
                   fragment("? ILIKE ?", title_en, fragment("'%' || ? || '%'", ^arg(:search))) or
                     fragment("? ILIKE ?", number, fragment("'%' || ? || '%'", ^arg(:search))) or
                     fragment("? ILIKE ?", name, fragment("'%' || ? || '%'", ^arg(:search)))
                 end
             )

      pagination offset?: true, keyset?: true, default_limit: 50
    end

    read :for_applicability_screening do
      description "Get duty-creating laws for applicability screening (Making function only)"
      argument :family, :string, allow_nil?: true
      argument :geo_extent, :string, allow_nil?: true
      argument :live_status, :string, default: "✔ In force"

      filter expr(
               fragment("? \\? ?", function, "Making") and
                 live == ^arg(:live_status) and
                 if is_nil(^arg(:family)) do
                   true
                 else
                   family == ^arg(:family)
                 end and
                 if is_nil(^arg(:geo_extent)) do
                   true
                 else
                   geo_extent == ^arg(:geo_extent)
                 end
             )

      prepare build(sort: [year: :desc, latest_amend_date: :desc])
      pagination offset?: true, default_limit: 100
    end

    read :distinct_families do
      description "Get distinct family values"
      prepare build(select: [:family], distinct: [:family])
    end

    read :distinct_family_ii do
      description "Get distinct family_ii values"
      prepare build(select: [:family_ii], distinct: [:family_ii])
      filter expr(not is_nil(family_ii))
    end

    read :distinct_years do
      description "Get distinct year values"
      prepare build(select: [:year], distinct: [:year])
      filter expr(not is_nil(year))
    end

    read :distinct_type_codes do
      description "Get distinct type_code values"
      prepare build(select: [:type_code], distinct: [:type_code])
      filter expr(not is_nil(type_code))
    end

    read :distinct_statuses do
      description "Get distinct live status values"
      prepare build(select: [:live], distinct: [:live])
      filter expr(not is_nil(live))
    end

    read :in_force do
      description "Get all currently in-force legislation"
      filter expr(live == "✔ In force")
      pagination offset?: true, keyset?: true, default_limit: 50
    end

    read :recently_amended do
      description "Get legislation amended in the last year"
      filter expr(
               not is_nil(latest_amend_date) and
                 fragment("? > CURRENT_DATE - INTERVAL '1 year'", latest_amend_date)
             )

      prepare build(sort: [latest_amend_date: :desc])
      pagination offset?: true, default_limit: 50
    end
  end

  calculations do
    calculate :display_name, :string, expr(coalesce(name, title_en, fragment("CONCAT('Record #', ?)", id))) do
      description "Best available display name"
    end

    calculate :title_with_year, :string, expr(fragment("CONCAT(?, ' (', ?, ')')", title_en, year)) do
      description "Title with year in parentheses"
    end
  end

  # JSON API configuration
  json_api do
    type "uk_lrt"

    routes do
      base "/api/uk-lrt"
      get :by_id, route: "/:id"
      index :read
      index :paginated, route: "/search"
      index :for_applicability_screening, route: "/screening"
      index :distinct_families, route: "/distinct/families"
      index :distinct_years, route: "/distinct/years"
      index :in_force, route: "/in-force"
      index :recently_amended, route: "/recently-amended"
    end
  end

  # Code interface for programmatic access
  code_interface do
    domain SertantaiLegal.Api
    define :read
    define :by_id, args: [:id]
    define :by_family, args: [:family]
    define :by_family_ii, args: [:family_ii]
    define :by_families, args: [:family, :family_ii]
    define :paginated, args: [:family, :year, :type_code, :status, :search]
    define :for_applicability_screening, args: [:family, :geo_extent, :live_status]
    define :distinct_families
    define :distinct_years
    define :in_force
    define :recently_amended
  end
end
