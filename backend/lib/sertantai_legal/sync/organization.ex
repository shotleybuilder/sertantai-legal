defmodule SertantaiLegal.Sync.Organization do
  @moduledoc """
  Local identity cache for customer organizations.

  This service does NOT own organizations — identity lives in sertantai-hub.
  This table is a lightweight local cache of org UUID + display name, populated
  during customer onboarding. Used for:

  - UI dropdowns (customer applicability selector)
  - Zenoh customer discovery queryable (fractalaw needs org names)
  - Display labels anywhere org_id appears
  """

  use Ash.Resource,
    domain: SertantaiLegal.Sync,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("organizations")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :name, :string do
      allow_nil?(false)
      description("Display name for the organization")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_id, [:id])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:id, :name])
    end

    update :update do
      accept([:name])
    end
  end
end
