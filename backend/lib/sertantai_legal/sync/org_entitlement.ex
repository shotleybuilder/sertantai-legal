defmodule SertantaiLegal.Sync.OrgEntitlement do
  @moduledoc """
  Defines what an organisation is entitled to sync.

  Pushed from sertantai-hub via webhook when subscription changes.
  Acts as the ceiling — sync profiles can only filter within these bounds.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("org_entitlements")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
      description("Organization UUID from JWT")
    end

    attribute :families, {:array, :string} do
      allow_nil?(false)
      description("Subscribed family names")
    end

    attribute :data_tier, SertantaiLegal.Sync.DataTier do
      allow_nil?(false)
      description("Which tables: lrt_only, lrt_lat, lrt_lat_amendments")
    end

    attribute :field_tier, SertantaiLegal.Sync.FieldTier do
      allow_nil?(false)
      description("Which columns: essential, standard, full")
    end

    attribute :source, SertantaiLegal.Sync.EntitlementSource do
      allow_nil?(false)
      description("How this entitlement was granted")
    end

    attribute :granted_at, :utc_datetime_usec do
      allow_nil?(false)
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil?(true)
      description("NULL means no expiry")
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
        :families,
        :data_tier,
        :field_tier,
        :source,
        :granted_at,
        :expires_at
      ])
    end

    update :update do
      accept([
        :families,
        :data_tier,
        :field_tier,
        :source,
        :granted_at,
        :expires_at
      ])
    end

    create :upsert do
      description("Create or update entitlement for an org (used by webhook)")

      accept([
        :organization_id,
        :families,
        :data_tier,
        :field_tier,
        :source,
        :granted_at,
        :expires_at
      ])

      upsert?(true)
      upsert_identity(:unique_org)

      upsert_fields([
        :families,
        :data_tier,
        :field_tier,
        :source,
        :granted_at,
        :expires_at
      ])
    end

    read :by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
    end
  end

  relationships do
    has_many :sync_profiles, SertantaiLegal.Sync.SyncProfile do
      source_attribute(:organization_id)
      destination_attribute(:organization_id)
      no_attributes?(true)
    end
  end
end
