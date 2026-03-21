defmodule SertantaiLegal.Sync.SyncJob do
  @moduledoc """
  Immutable log of sync executions for audit and debugging.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("sync_jobs")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :sync_configuration_id, :uuid do
      allow_nil?(false)
    end

    attribute :organization_id, :uuid do
      allow_nil?(false)
    end

    attribute :status, SertantaiLegal.Sync.JobStatus do
      allow_nil?(false)
      default(:queued)
    end

    attribute :started_at, :utc_datetime_usec do
      allow_nil?(true)
    end

    attribute :completed_at, :utc_datetime_usec do
      allow_nil?(true)
    end

    # Scope snapshot
    attribute :law_count, :integer do
      allow_nil?(true)
      description("LRT rows matched")
    end

    attribute :lat_count, :integer do
      allow_nil?(true)
      description("LAT rows matched (if applicable)")
    end

    # Results
    attribute :rows_created, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :rows_updated, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :rows_deleted, :integer do
      allow_nil?(false)
      default(0)
    end

    attribute :rows_failed, :integer do
      allow_nil?(false)
      default(0)
    end

    # Error tracking
    attribute :error_message, :string do
      allow_nil?(true)
    end

    attribute :error_details, :map do
      allow_nil?(true)
      description("Per-row errors if partial failure")
    end

    # Delta tracking
    attribute :sync_checkpoint, :utc_datetime_usec do
      allow_nil?(true)
      description("uk_lrt.updated_at watermark for next delta")
    end

    create_timestamp(:inserted_at)
  end

  actions do
    defaults([:read])

    create :create do
      accept([
        :sync_configuration_id,
        :organization_id,
        :status
      ])
    end

    update :start do
      accept([])

      change(set_attribute(:status, :running))
      change(set_attribute(:started_at, &DateTime.utc_now/0))
    end

    update :complete do
      accept([
        :law_count,
        :lat_count,
        :rows_created,
        :rows_updated,
        :rows_deleted,
        :rows_failed,
        :sync_checkpoint
      ])

      change(set_attribute(:status, :completed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
    end

    update :fail do
      accept([:error_message, :error_details])

      change(set_attribute(:status, :failed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))
    end

    read :by_configuration do
      argument(:sync_configuration_id, :uuid, allow_nil?: false)
      filter(expr(sync_configuration_id == ^arg(:sync_configuration_id)))
    end

    read :recent_by_organization do
      argument(:organization_id, :uuid, allow_nil?: false)
      filter(expr(organization_id == ^arg(:organization_id)))
      prepare(build(sort: [inserted_at: :desc], limit: 50))
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
