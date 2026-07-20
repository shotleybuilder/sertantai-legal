defmodule SertantaiLegal.Legal.SecondaryRaci do
  @moduledoc """
  RACI role assignment for a secondary source obligation.

  Links a canonical actor role to an obligation with an assignment type
  (Responsible / Accountable / Consulted / Informed).

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_raci")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :obligation_id, :string do
      allow_nil?(false)
      description("FK to secondary_obligations.obligation_id")
    end

    attribute :section_id, :string do
      allow_nil?(false)
      description("Denormalised from parent obligation")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("Denormalised for fast filtering")
    end

    attribute :role_label, :string do
      allow_nil?(false)
      description("Canonical actor label (e.g. 'MoD: Commanding Officer')")
    end

    attribute :assignment_type, :string do
      allow_nil?(false)
      description("R (Responsible) / A (Accountable) / C (Consulted) / I (Informed)")
    end

    attribute :obligation_index, :integer do
      allow_nil?(false)
      description("Links to obligation within provision (0-based)")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :obligation_id,
        :section_id,
        :source_id,
        :role_label,
        :assignment_type,
        :obligation_index
      ])
    end

    read :by_source_id do
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
    end

    read :by_obligation_id do
      argument(:obligation_id, :string, allow_nil?: false)
      filter(expr(obligation_id == ^arg(:obligation_id)))
    end

    read :by_role_label do
      argument(:role_label, :string, allow_nil?: false)
      filter(expr(role_label == ^arg(:role_label)))
    end
  end
end
