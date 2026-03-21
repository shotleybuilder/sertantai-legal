defmodule SertantaiLegal.Sync.SyncRowMapping do
  @moduledoc """
  Tracks which source records (LRT/LAT) have been synced to which
  external row IDs in the target provider. Used for delta sync
  (update/delete existing rows instead of re-creating).
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("sync_row_mappings")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :sync_configuration_id, :uuid do
      allow_nil?(false)
    end

    attribute :source_type, SertantaiLegal.Sync.SourceType do
      allow_nil?(false)
      description("lrt or lat")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("uk_lrt.id (UUID string) or lat.section_id")
    end

    attribute :external_row_id, :integer do
      allow_nil?(false)
      description("Row ID in the target provider (e.g. Baserow row ID)")
    end

    attribute :last_synced_at, :utc_datetime_usec do
      allow_nil?(false)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_mapping, [:sync_configuration_id, :source_type, :source_id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :sync_configuration_id,
        :source_type,
        :source_id,
        :external_row_id,
        :last_synced_at
      ])
    end

    create :upsert do
      accept([
        :sync_configuration_id,
        :source_type,
        :source_id,
        :external_row_id,
        :last_synced_at
      ])

      upsert?(true)
      upsert_identity(:unique_mapping)
      upsert_fields([:external_row_id, :last_synced_at])
    end

    update :update_synced do
      accept([:last_synced_at])
    end

    read :by_configuration do
      argument(:sync_configuration_id, :uuid, allow_nil?: false)
      filter(expr(sync_configuration_id == ^arg(:sync_configuration_id)))
    end

    read :by_configuration_and_type do
      argument(:sync_configuration_id, :uuid, allow_nil?: false)
      argument(:source_type, SertantaiLegal.Sync.SourceType, allow_nil?: false)

      filter(
        expr(
          sync_configuration_id == ^arg(:sync_configuration_id) and
            source_type == ^arg(:source_type)
        )
      )
    end
  end

  relationships do
    belongs_to :sync_configuration, SertantaiLegal.Sync.SyncConfiguration do
      source_attribute(:sync_configuration_id)
      destination_attribute(:id)
      define_attribute?(false)
    end
  end
end
