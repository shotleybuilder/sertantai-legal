defmodule SertantaiLegal.Sync.OrgApplicability do
  @moduledoc """
  Per-law applicability selection for an organization (L3).

  Sits between rule-based SyncProfile filtering (L2) and sync execution.
  Records whether a specific law applies to an org, with provenance tracking.

  Pre-populated from legacy vendor CSV imports (e.g. Enhesa Answer field),
  then refined by manual review or automated Fitness-based screening.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("org_applicabilities")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
      description("Organization UUID from JWT")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("References uk_lrt.name (canonical identifier, e.g. UK_uksi_2020_1234)")
    end

    attribute :status, SertantaiLegal.Sync.ApplicabilityStatus do
      allow_nil?(false)
      default(:unreviewed)
      description("Applicability decision: yes, no, excluded, unreviewed")
    end

    attribute :source, SertantaiLegal.Sync.ApplicabilitySource do
      allow_nil?(false)
      description("How this decision was made")
    end

    attribute :notes, :string do
      allow_nil?(true)
      description("Reviewer comments")
    end

    attribute :reviewed_at, :utc_datetime_usec do
      allow_nil?(true)
      description("When a human last reviewed this decision")
    end

    attribute :reviewed_by, :string do
      allow_nil?(true)
      description("User identifier (email or UUID) of reviewer")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_org_law, [:organization_id, :law_name])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :law_name,
        :status,
        :source,
        :notes,
        :reviewed_at,
        :reviewed_by
      ])
    end

    create :upsert do
      description("Create or update applicability for an org+law (used by import and bulk ops)")

      accept([
        :organization_id,
        :law_name,
        :status,
        :source,
        :notes,
        :reviewed_at,
        :reviewed_by
      ])

      upsert?(true)
      upsert_identity(:unique_org_law)

      upsert_fields([
        :status,
        :source,
        :notes,
        :reviewed_at,
        :reviewed_by
      ])
    end

    update :update do
      accept([:status, :source, :notes, :reviewed_at, :reviewed_by])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
    end

    read :by_organization_and_status do
      argument(:organization_id, :uuid, allow_nil?: false)
      argument(:status, SertantaiLegal.Sync.ApplicabilityStatus, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id) and status == ^arg(:status)))
    end

    read :applicable_for_organization do
      description("Laws marked as applicable (yes) for an org")
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id) and status == :yes))
    end
  end

  code_interface do
    define(:create)
    define(:upsert)
    define(:read)
    define(:update)
    define(:destroy)
    define(:by_organization, args: [:organization_id])
    define(:by_organization_and_status, args: [:organization_id, :status])
    define(:applicable_for_organization, args: [:organization_id])
  end
end
