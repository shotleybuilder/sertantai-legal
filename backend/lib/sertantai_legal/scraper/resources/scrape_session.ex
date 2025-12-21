defmodule SertantaiLegal.Scraper.ScrapeSession do
  @moduledoc """
  Tracks scraping sessions for legislation.gov.uk new laws.

  A session represents a single scraping run for a date range.
  Results are stored as JSON files for user review before persistence.

  ## Status Flow
  pending -> scraping -> categorized -> reviewing -> completed
                    \\-> failed

  ## File Storage
  JSON files are stored in priv/scraper/{session_id}/:
  - raw.json: All fetched records
  - inc_w_si.json: Group 1 - SI code match (highest priority)
  - inc_wo_si.json: Group 2 - Term match only (medium priority)
  - exc.json: Group 3 - Excluded (review needed)
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "scrape_sessions"
    repo SertantaiLegal.Repo
  end

  attributes do
    uuid_primary_key :id

    # Session identification
    attribute :session_id, :string do
      allow_nil? false
      description "Unique session identifier, e.g., '2024-12-02-to-05'"
    end

    # Parameters
    attribute :year, :integer do
      allow_nil? false
      description "Year to scrape"
    end

    attribute :month, :integer do
      allow_nil? false
      constraints min: 1, max: 12
      description "Month to scrape (1-12)"
    end

    attribute :day_from, :integer do
      allow_nil? false
      constraints min: 1, max: 31
      description "Start day of range"
    end

    attribute :day_to, :integer do
      allow_nil? false
      constraints min: 1, max: 31
      description "End day of range"
    end

    attribute :type_code, :string do
      allow_nil? true
      description "Optional type code filter (uksi, ukpga, etc). Nil = all"
    end

    # Status
    attribute :status, :atom do
      constraints one_of: [:pending, :scraping, :categorized, :reviewing, :completed, :failed]
      default :pending
      allow_nil? false
      description "Current session status"
    end

    attribute :error_message, :string do
      allow_nil? true
      description "Error message if status is :failed"
    end

    # Counts
    attribute :total_fetched, :integer do
      default 0
      description "Total records fetched from legislation.gov.uk"
    end

    attribute :title_excluded_count, :integer do
      default 0
      description "Records excluded by title filter"
    end

    attribute :group1_count, :integer do
      default 0
      description "Group 1: Records with SI code match"
    end

    attribute :group2_count, :integer do
      default 0
      description "Group 2: Records with term match only"
    end

    attribute :group3_count, :integer do
      default 0
      description "Group 3: Records excluded (no match)"
    end

    attribute :persisted_count, :integer do
      default 0
      description "Records persisted to uk_lrt table"
    end

    # File paths (relative to priv/scraper/)
    attribute :raw_file, :string do
      allow_nil? true
      description "Path to raw.json"
    end

    attribute :group1_file, :string do
      allow_nil? true
      description "Path to inc_w_si.json (Group 1)"
    end

    attribute :group2_file, :string do
      allow_nil? true
      description "Path to inc_wo_si.json (Group 2)"
    end

    attribute :group3_file, :string do
      allow_nil? true
      description "Path to exc.json (Group 3)"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_session_id, [:session_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      description "Create a new scrape session"
      accept [:session_id, :year, :month, :day_from, :day_to, :type_code]
    end

    update :update do
      description "General update"
      accept :*
    end

    update :mark_scraping do
      description "Mark session as actively scraping"
      change set_attribute(:status, :scraping)
    end

    update :mark_scraped do
      description "Mark session as scraped with raw file"
      accept [:total_fetched, :raw_file]
      change set_attribute(:status, :scraping)
    end

    update :mark_categorized do
      description "Mark session as categorized with group files and counts"
      accept [
        :title_excluded_count,
        :group1_count,
        :group2_count,
        :group3_count,
        :group1_file,
        :group2_file,
        :group3_file
      ]

      change set_attribute(:status, :categorized)
    end

    update :mark_reviewing do
      description "Mark session as under user review"
      change set_attribute(:status, :reviewing)
    end

    update :mark_completed do
      description "Mark session as completed with persistence count"
      accept [:persisted_count]
      change set_attribute(:status, :completed)
    end

    update :mark_failed do
      description "Mark session as failed with error message"
      accept [:error_message]
      change set_attribute(:status, :failed)
    end

    read :by_id do
      description "Get session by ID"
      get? true
      argument :id, :uuid, allow_nil?: false
      filter expr(id == ^arg(:id))
    end

    read :by_session_id do
      description "Get session by session_id string"
      get? true
      argument :session_id, :string, allow_nil?: false
      filter expr(session_id == ^arg(:session_id))
    end

    read :active do
      description "Get all active (non-completed, non-failed) sessions"
      filter expr(status in [:pending, :scraping, :categorized, :reviewing])
      prepare build(sort: [inserted_at: :desc])
    end

    read :recent do
      description "Get recent sessions"
      prepare build(sort: [inserted_at: :desc], limit: 10)
    end

    read :by_status do
      description "Get sessions by status"
      argument :status, :atom, allow_nil?: false
      filter expr(status == ^arg(:status))
      prepare build(sort: [inserted_at: :desc])
    end
  end

  code_interface do
    domain SertantaiLegal.Api
    define :create
    define :read
    define :update
    define :by_id, args: [:id]
    define :by_session_id, args: [:session_id]
    define :active
    define :recent
    define :by_status, args: [:status]
    define :mark_scraping
    define :mark_scraped
    define :mark_categorized
    define :mark_reviewing
    define :mark_completed
    define :mark_failed
    define :destroy
  end
end
