defmodule SertantaiLegal.Sync.OrgSecondaryApplicability do
  @moduledoc """
  Per-secondary-source applicability selection for an organization.

  Parallels `OrgApplicability` (which tracks per-law applicability) but
  for second-tier requirements: ACoPs, standards, JSPs, guidance.

  ## Applicability granularity

  Applicability can be set at two levels:

  - **Parent level** (e.g. `JSP-375`): marks the whole JSP as applicable.
    All chapters are candidates, but the customer may only need specific ones.
  - **Chapter level** (e.g. `JSP-375-CH23`): marks a specific chapter as applicable.
    The parent JSP's applicability is the aggregation of its chapters'.

  The `source_id` field references `secondary_sources.source_id`, which can be
  either a parent (`JSP-375`) or a chapter (`JSP-375-CH23`).

  ## Population sources

  - **Inherited**: auto-populated from parent law applicability (if HSWA applies,
    ACoPs approved under HSWA are candidates)
  - **Screener**: sector/certification-based screening via `OrgScreeningProfile`
  - **Manual**: compliance officer marks specific sources as applicable
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("org_secondary_applicabilities")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_org_source, [:organization_id, :source_id])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
      description("Organization UUID from JWT")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("References secondary_sources.source_id (e.g. L8, JSP-375, ISO-45001)")
    end

    attribute :status, SertantaiLegal.Sync.ApplicabilityStatus do
      allow_nil?(false)
      default(:unreviewed)
      description("Applicability decision: yes, no, excluded, unreviewed")
    end

    attribute :source, SertantaiLegal.Sync.SecondaryApplicabilitySource do
      allow_nil?(false)
      description("How this decision was made: manual, inherited, screener")
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

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :source_id,
        :status,
        :source,
        :notes,
        :reviewed_at,
        :reviewed_by
      ])
    end

    create :upsert do
      description(
        "Create or update applicability for an org+source (used by inheritance and bulk ops)"
      )

      accept([
        :organization_id,
        :source_id,
        :status,
        :source,
        :notes,
        :reviewed_at,
        :reviewed_by
      ])

      upsert?(true)
      upsert_identity(:unique_org_source)

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
      description("Secondary sources marked as applicable (yes) for an org")
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
