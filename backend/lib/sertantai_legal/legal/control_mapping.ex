defmodule SertantaiLegal.Legal.ControlMapping do
  @moduledoc """
  Join table linking controls to provisions (LAT sections).

  Generated programmatically by the ControlsSubscriber when it receives
  control data from fractalaw. Each element in a control's `linked_provisions`
  becomes one ControlMapping row.

  The `section_id` is resolved from the short ref by prepending `law_name`:
  e.g. short ref `"reg.3(1)"` for law `"UK_uksi_1997_1713"` becomes
  section_id `"UK_uksi_1997_1713:reg.3(1)"`.

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("control_mappings")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_mapping, [:control_id, :section_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :control_id, :uuid do
      allow_nil?(false)
      description("FK to controls.id")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("Denormalized for query efficiency — matches parent control's law_name")
    end

    attribute :section_id, :string do
      allow_nil?(false)
      description("Full resolved section ID (e.g. UK_uksi_1997_1713:reg.3(1))")
    end

    attribute :short_ref, :string do
      allow_nil?(true)
      description("Original short ref from linked_provisions (e.g. reg.3(1))")
    end

    attribute :mapping_strength, :string do
      allow_nil?(true)
      description("Primary / Supporting / Ancillary — from parent control")
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :upsert do
      description("Upsert a control mapping — idempotent on (control_id, section_id)")

      accept([
        :control_id,
        :law_name,
        :section_id,
        :short_ref,
        :mapping_strength
      ])

      upsert?(true)
      upsert_identity(:unique_mapping)
      upsert_fields([:short_ref, :mapping_strength])
    end

    read :by_law_name do
      description("Mappings for a single law")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end

    read :by_law_names do
      description("Mappings for a list of laws (batch Baserow sync)")
      argument(:law_names, {:array, :string}, allow_nil?: false)
      filter(expr(law_name in ^arg(:law_names)))
    end

    read :by_control do
      description("Mappings for a specific control")
      argument(:control_id, :uuid, allow_nil?: false)
      filter(expr(control_id == ^arg(:control_id)))
    end
  end

  relationships do
    belongs_to :control, SertantaiLegal.Legal.Control do
      source_attribute(:control_id)
      destination_attribute(:id)
      define_attribute?(false)
      description("Parent control")
    end
  end
end
