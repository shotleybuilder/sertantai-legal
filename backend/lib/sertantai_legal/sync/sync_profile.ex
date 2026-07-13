defmodule SertantaiLegal.Sync.SyncProfile do
  @moduledoc """
  User-curated filter set that narrows within entitlement bounds.

  An org might have several profiles: "Construction H&S", "Environmental - England only", etc.
  Each profile defines which laws to sync by combining family, geo, function, and fitness filters.

  Fitness filter semantics: AND across categories, OR within a category.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("sync_profiles")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
    end

    attribute :name, :string do
      allow_nil?(false)
      description("Display name, e.g. 'Construction H&S', 'England Environmental'")
    end

    attribute :description, :string do
      allow_nil?(true)
    end

    # Family filter (must be subset of entitlement)
    attribute :families, {:array, :string} do
      allow_nil?(false)
      description("Selected families from entitlement")
    end

    # Geographic filter
    attribute :geo_regions, {:array, :string} do
      allow_nil?(true)
      description("NULL = all; e.g. ['England', 'Wales']")
    end

    # Function filter
    attribute :function_filter, :map do
      allow_nil?(true)
      description("e.g. {is_making: true} or NULL = all")
    end

    # Fitness filter — entity overlap
    attribute :fitness_entities, {:array, :string} do
      allow_nil?(true)
      description("Fitness entity filter terms (matched against fitness_entities column)")
    end

    # Status filter
    attribute :live_filter, {:array, :string} do
      allow_nil?(true)
      description("e.g. ['✔ In force'] or NULL = all")
    end

    # What to include
    attribute :include_lat, :boolean do
      allow_nil?(false)
      default(false)
      description("Include article text (requires data_tier >= lrt_lat)")
    end

    attribute :include_amendments, :boolean do
      allow_nil?(false)
      default(false)
      description("Include amendment annotations (requires data_tier >= lrt_lat_amendments)")
    end

    # Cached counts for UI
    attribute :matched_law_count, :integer do
      allow_nil?(true)
    end

    attribute :matched_lat_count, :integer do
      allow_nil?(true)
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    attribute :deactivation_reason, :string do
      allow_nil?(true)
      description("Set when profile is deactivated due to entitlement change")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :name,
        :description,
        :families,
        :geo_regions,
        :function_filter,
        :fitness_entities,
        :live_filter,
        :include_lat,
        :include_amendments
      ])
    end

    update :update do
      accept([
        :name,
        :description,
        :families,
        :geo_regions,
        :function_filter,
        :fitness_entities,
        :live_filter,
        :include_lat,
        :include_amendments,
        :is_active,
        :deactivation_reason,
        :matched_law_count,
        :matched_lat_count
      ])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
    end

    read :active_by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id) and is_active == true))
    end
  end

  relationships do
    has_many :sync_configurations, SertantaiLegal.Sync.SyncConfiguration do
      source_attribute(:id)
      destination_attribute(:sync_profile_id)
    end
  end
end
