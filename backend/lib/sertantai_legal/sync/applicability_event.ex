defmodule SertantaiLegal.Sync.ApplicabilityEvent do
  @moduledoc """
  Insert-only audit log for applicability screening changes.

  One row per change — tracks when laws are added, removed, seeded,
  confirmed, or excluded from an org's legal register. Powers the
  activity feed, undo, and regulatory defensibility trail.

  "SertantAI recommends; the duty holder decides."
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("applicability_events")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
    end

    attribute :law_name, :string do
      allow_nil?(false)
    end

    attribute :event, :string do
      allow_nil?(false)

      description(
        "Event type: added, removed, excluded, seeded, confirmed, restored, bulk_seeded"
      )
    end

    attribute :actor, :string do
      allow_nil?(false)
      description("User email or 'sertantai' for automated actions")
    end

    attribute :status_before, :string do
      description("Previous status (null for first event on a law)")
    end

    attribute :status_after, :string do
      allow_nil?(false)
      description("New status after this event")
    end

    attribute :source, :string do
      allow_nil?(false)
      description("manual, screener, or enhesa_import")
    end

    attribute :metadata, :map do
      description("Extensible JSONB: match_reason, notes, profile_snapshot, undone_event_id")
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :log do
      accept([
        :organization_id,
        :law_name,
        :event,
        :actor,
        :status_before,
        :status_after,
        :source,
        :metadata
      ])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
      prepare(build(sort: [inserted_at: :desc]))
    end

    read :by_law do
      argument(:organization_id, :uuid, allow_nil?: false)
      argument(:law_name, :string, allow_nil?: false)

      filter(expr(organization_id == ^arg(:organization_id) and law_name == ^arg(:law_name)))

      prepare(build(sort: [inserted_at: :desc]))
    end

    read :most_recent do
      argument(:organization_id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(organization_id == ^arg(:organization_id)))
      prepare(build(sort: [inserted_at: :desc], limit: 1))
    end
  end

  code_interface do
    define(:log)
    define(:by_organization, args: [:organization_id])
    define(:by_law, args: [:organization_id, :law_name])
    define(:most_recent, args: [:organization_id])
  end
end
