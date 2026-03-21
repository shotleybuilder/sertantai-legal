defmodule SertantaiLegal.Sync.SyncConfiguration do
  @moduledoc """
  Provider connection details. Links a sync profile to a target (e.g. Baserow table).

  Credentials are encrypted with AES-256-CBC (per-record random IV).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("sync_configurations")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :organization_id, :uuid do
      allow_nil?(false)
    end

    attribute :sync_profile_id, :uuid do
      allow_nil?(false)
    end

    attribute :name, :string do
      allow_nil?(false)
    end

    # Provider
    attribute :provider, SertantaiLegal.Sync.Provider do
      allow_nil?(false)
    end

    # Connection (encrypted)
    attribute :encrypted_credentials, :string do
      allow_nil?(false)
      sensitive?(true)
      description("AES-256-CBC encrypted JSON")
    end

    attribute :credentials_iv, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    # Target details (provider-specific, not encrypted)
    attribute :target_config, :map do
      allow_nil?(false)
      description("Baserow: {base_url, lrt_table_id, lat_table_id, database_token_name}")
    end

    # Field mapping: which entitled fields map to which target fields
    # NULL = auto-create fields in target matching the field_tier
    attribute :field_mapping, :map do
      allow_nil?(true)
    end

    # Schedule
    attribute :sync_frequency, SertantaiLegal.Sync.SyncFrequency do
      allow_nil?(false)
    end

    # Change behaviour
    attribute :on_filter_change, SertantaiLegal.Sync.ChangeBehaviour do
      allow_nil?(false)
      default(:delete)
      description("What to do when rows leave profile scope")
    end

    attribute :on_entitlement_change, SertantaiLegal.Sync.ChangeBehaviour do
      allow_nil?(false)
      default(:delete)
      description("What to do when entitlement shrinks")
    end

    # State
    attribute :sync_status, SertantaiLegal.Sync.SyncStatus do
      allow_nil?(false)
      default(:idle)
    end

    attribute :last_synced_at, :utc_datetime_usec do
      allow_nil?(true)
    end

    attribute :last_sync_summary, :map do
      allow_nil?(true)
      description("{rows_created, rows_updated, rows_deleted, errors}")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :organization_id,
        :sync_profile_id,
        :name,
        :provider,
        :encrypted_credentials,
        :credentials_iv,
        :target_config,
        :field_mapping,
        :sync_frequency,
        :on_filter_change,
        :on_entitlement_change
      ])
    end

    update :update do
      accept([
        :name,
        :sync_profile_id,
        :encrypted_credentials,
        :credentials_iv,
        :target_config,
        :field_mapping,
        :sync_frequency,
        :on_filter_change,
        :on_entitlement_change,
        :is_active
      ])
    end

    update :update_sync_status do
      accept([:sync_status, :last_synced_at, :last_sync_summary])
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
    belongs_to :sync_profile, SertantaiLegal.Sync.SyncProfile do
      source_attribute(:sync_profile_id)
      destination_attribute(:id)
      define_attribute?(false)
    end

    has_many :sync_jobs, SertantaiLegal.Sync.SyncJob do
      source_attribute(:id)
      destination_attribute(:sync_configuration_id)
    end

    has_many :sync_row_mappings, SertantaiLegal.Sync.SyncRowMapping do
      source_attribute(:id)
      destination_attribute(:sync_configuration_id)
    end
  end
end
