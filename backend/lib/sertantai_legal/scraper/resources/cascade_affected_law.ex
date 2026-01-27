defmodule SertantaiLegal.Scraper.CascadeAffectedLaw do
  @moduledoc """
  Tracks laws that need updating as part of cascade updates.

  When a new law is parsed and confirmed, it may reference other laws via:
  - `amending` / `rescinding` - these laws need re-parsing from legislation.gov.uk
  - `enacted_by` - parent laws need their `enacting` array updated

  This table deduplicates affected laws per session - if multiple source laws
  point to the same affected law, only one row exists with all sources tracked
  in the `source_laws` array.

  ## Update Types
  - `:reparse` - Law was amended/rescinded, needs full re-scrape
  - `:enacting_link` - Law is a parent, just needs enacting array updated

  ## Status Flow
  pending -> processed
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("cascade_affected_laws")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :session_id, :string do
      allow_nil?(false)
      description("Reference to scrape_sessions.session_id")
    end

    attribute :affected_law, :string do
      allow_nil?(false)
      description("Law that needs updating, e.g., 'UK_uksi_2025_622'")
    end

    attribute :update_type, :atom do
      constraints(one_of: [:reparse, :enacting_link])
      allow_nil?(false)
      description(":reparse for amended/rescinded, :enacting_link for parent laws")
    end

    attribute :status, :atom do
      constraints(one_of: [:pending, :processed])
      default(:pending)
      allow_nil?(false)
      description("Processing status")
    end

    attribute :source_laws, {:array, :string} do
      default([])
      description("List of laws that triggered this cascade entry (audit trail)")
    end

    attribute :metadata, :map do
      description(
        "Cached metadata from parse-metadata (title_en, type_code, year, number, si_code)"
      )
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_per_session, [:session_id, :affected_law])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new cascade entry")
      accept([:session_id, :affected_law, :update_type, :status, :source_laws])
    end

    create :upsert do
      description("Upsert a cascade entry - append source_law if exists")
      accept([:session_id, :affected_law, :update_type, :source_laws])
      upsert?(true)
      upsert_identity(:unique_per_session)
      # On conflict: merge source_laws and possibly upgrade update_type
      upsert_fields({:replace, [:updated_at]})
    end

    update :update do
      description("General update")
      accept([:status, :source_laws, :update_type])
    end

    update :mark_processed do
      description("Mark cascade entry as processed")
      change(set_attribute(:status, :processed))
    end

    update :update_metadata do
      description("Store fetched metadata on a cascade entry")
      accept([:metadata])
    end

    update :append_source_law do
      description("Append a source law to the source_laws array")
      argument(:source_law, :string, allow_nil?: false)
      require_atomic?(false)

      change(fn changeset, _context ->
        source_law = Ash.Changeset.get_argument(changeset, :source_law)
        current = Ash.Changeset.get_attribute(changeset, :source_laws) || []

        if source_law in current do
          changeset
        else
          Ash.Changeset.change_attribute(changeset, :source_laws, current ++ [source_law])
        end
      end)
    end

    update :upgrade_to_reparse do
      description("Upgrade update_type to :reparse (if was :enacting_link)")
      change(set_attribute(:update_type, :reparse))
    end

    read :by_session do
      description("Get all cascade entries for a session")
      argument(:session_id, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_status do
      description("Get cascade entries for a session with specific status")
      argument(:session_id, :string, allow_nil?: false)
      argument(:status, :atom, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and status == ^arg(:status)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_type do
      description("Get cascade entries for a session with specific update type")
      argument(:session_id, :string, allow_nil?: false)
      argument(:update_type, :atom, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and update_type == ^arg(:update_type)))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :pending_for_session do
      description("Get pending cascade entries for a session")
      argument(:session_id, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and status == :pending))
      prepare(build(sort: [inserted_at: :asc]))
    end

    read :by_session_and_law do
      description("Get a specific cascade entry")
      get?(true)
      argument(:session_id, :string, allow_nil?: false)
      argument(:affected_law, :string, allow_nil?: false)
      filter(expr(session_id == ^arg(:session_id) and affected_law == ^arg(:affected_law)))
    end

    read :all_pending do
      description("Get all pending cascade entries across all sessions")
      filter(expr(status == :pending))
      prepare(build(sort: [session_id: :desc, inserted_at: :asc]))
    end

    read :sessions_with_pending do
      description("Get distinct session IDs that have pending cascade entries")
      filter(expr(status == :pending))
      prepare(build(sort: [session_id: :desc]))
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:create)
    define(:upsert)
    define(:read)
    define(:update)
    define(:destroy)
    define(:by_session, args: [:session_id])
    define(:by_session_and_status, args: [:session_id, :status])
    define(:by_session_and_type, args: [:session_id, :update_type])
    define(:pending_for_session, args: [:session_id])
    define(:by_session_and_law, args: [:session_id, :affected_law])
    define(:all_pending)
    define(:sessions_with_pending)
    define(:mark_processed)
    define(:update_metadata)
    define(:append_source_law)
    define(:upgrade_to_reparse)
  end
end
