defmodule SertantaiLegal.Sync.OrgScreeningProfile do
  @moduledoc """
  Organisation screening profile for deterministic applicability matching.

  Stores tag selections across fitness dimensions + geographic scope.
  Used by the auto-screener to match laws against the org's profile.
  Each org has exactly one profile (upsert on organization_id).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("org_screening_profiles")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
      description("Organization UUID from JWT — one profile per org")
    end

    # Geographic scope (primary filter — uses geo_region on laws)
    attribute :regions, {:array, :string} do
      default([])
      description("Geographic regions: England, Scotland, Wales, Northern Ireland, etc.")
    end

    # DRRP actor dimensions (matched against duty/rights/responsibility/power holders)
    attribute :governed_actors, {:array, :string} do
      default([])

      description(
        "Governed actors with duties/rights: Org: Employer, SC: Contractor, Ind: Employee, etc."
      )
    end

    attribute :government_actors, {:array, :string} do
      default([])

      description(
        "Government actors with responsibilities/powers: Gvt: Authority, Gvt: Minister, etc."
      )
    end

    # Fitness dimensions (secondary filter — matched against law fitness arrays)
    attribute :activities, {:array, :string} do
      default([])
      description("Legacy — use governed_actors/government_actors instead. Kept for migration.")
    end

    attribute :locations, {:array, :string} do
      default([])
      description("Physical site types: premises, offshore, ship, aircraft, mine, etc.")
    end

    attribute :materials, {:array, :string} do
      default([])

      description(
        "Substances/equipment: chemicals, explosives, asbestos, lead, pressure equipment, etc."
      )
    end

    attribute :processes, {:array, :string} do
      default([])
      description("Activities/operations: construction work, diving operations, gas work, etc.")
    end

    attribute :sector, {:array, :string} do
      default([])

      description(
        "Industry verticals: maritime, nuclear, water industry, offshore oil & gas, etc."
      )
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_org, [:organization_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector
      ])
    end

    update :update do
      accept([
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector
      ])
    end

    create :upsert do
      accept([
        :organization_id,
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector
      ])

      upsert?(true)
      upsert_identity(:unique_org)

      upsert_fields([
        :regions,
        :governed_actors,
        :government_actors,
        :activities,
        :locations,
        :materials,
        :processes,
        :sector
      ])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      get?(true)
      filter(expr(organization_id == ^arg(:organization_id)))
    end
  end

  code_interface do
    define(:create, args: [:organization_id])
    define(:upsert)
    define(:update)
    define(:by_organization, args: [:organization_id])
    define(:destroy)
  end
end
