defmodule SertantaiLegal.Scraper.ScrapeSessionRecord do
  @moduledoc """
  Tracks individual law records within a scrape session.

  Each record represents a single law being processed during a scrape session.
  This replaces the JSON file storage (inc_w_si.json, inc_wo_si.json, exc.json)
  with database-backed storage for better deduplication and querying.

  ## Status Flow
  pending -> parsed -> confirmed (persisted to uk_lrt)
      |         |
      |         └-> skipped (user chose not to persist)
      |
      └-> skipped (user excluded before parsing)

  ## Groups
  - :group1 - SI code match (highest priority)
  - :group2 - Term match only (medium priority)
  - :group3 - Excluded (review needed)
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("scrape_session_records")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :session_id, :string do
      allow_nil?(false)
      description("Reference to scrape_sessions.session_id")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("Law identifier, e.g., 'UK_uksi_2025_622'")
    end

    attribute :group, :atom do
      constraints(one_of: [:group1, :group2, :group3])
      allow_nil?(false)
      description("Categorization group")
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :parsed, :confirmed, :skipped])
      default(:pending)
      allow_nil?(false)
      description("Processing status")
    end

    attribute :selected, :boolean do
      default(false)
      description("Whether record is selected for bulk operations")
    end

    attribute :parsed_data, :map do
      allow_nil?(true)
      description("Full ParsedLaw output as JSONB")
    end

    attribute :parse_count, :integer do
      default(0)
      description("Number of times this record has been parsed")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_per_session, [:session_id, :law_name])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new session record")
      accept([:session_id, :law_name, :group, :status, :selected, :parsed_data])
      upsert?(true)
      upsert_identity(:unique_per_session)
      upsert_fields([:group, :status, :selected, :parsed_data, :updated_at])
    end

    update :update do
      description("General update")
      accept([:status, :selected, :parsed_data, :parse_count])
    end

    update :mark_parsed do
      description("Mark record as parsed with data")
      accept([:parsed_data])

      change(set_attribute(:status, :parsed))
      change(atomic_update(:parse_count, expr(parse_count + 1)))
    end

    update :mark_confirmed do
      description("Mark record as confirmed (persisted to uk_lrt)")
      change(set_attribute(:status, :confirmed))
    end

    update :mark_skipped do
      description("Mark record as skipped")
      change(set_attribute(:status, :skipped))
    end

    update :set_selected do
      description("Update selection state")
      accept([:selected])
    end

    read :by_session do
      description("Get all records for a session")
      argument(:session_id, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_group do
      description("Get records for a session and group")
      argument(:session_id, :string, allow_nil?: false)
      argument(:group, :atom, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and group == ^arg(:group)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_status do
      description("Get records for a session with specific status")
      argument(:session_id, :string, allow_nil?: false)
      argument(:status, :atom, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and status == ^arg(:status)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_name do
      description("Get a specific record by session and law name")
      get?(true)
      argument(:session_id, :string, allow_nil?: false)
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and law_name == ^arg(:law_name)))
    end

    read :selected_in_session do
      description("Get selected records for a session")
      argument(:session_id, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and selected == true))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :selected_in_group do
      description("Get selected records for a session and group")
      argument(:session_id, :string, allow_nil?: false)
      argument(:group, :atom, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and group == ^arg(:group) and selected == true))
      prepare(build(sort: [inserted_at: :asc]))
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:create)
    define(:read)
    define(:update)
    define(:destroy)
    define(:by_session, args: [:session_id])
    define(:by_session_and_group, args: [:session_id, :group])
    define(:by_session_and_status, args: [:session_id, :status])
    define(:by_session_and_name, args: [:session_id, :law_name])
    define(:selected_in_session, args: [:session_id])
    define(:selected_in_group, args: [:session_id, :group])
    define(:mark_parsed)
    define(:mark_confirmed)
    define(:mark_skipped)
    define(:set_selected)
  end
end
