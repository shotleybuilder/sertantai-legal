defmodule SertantaiLegal.Legal.SourceLink do
  @moduledoc """
  Many-to-many link between secondary sources and primary legislation.

  Captures the *regulatory authority* relationship — why a secondary source
  exists, not just what it operationally addresses. Controls provide the
  operational traceability; source links provide the statutory basis.

  Links can be at three levels of granularity:
  - Document-to-document: "JSP-375 supplements HSWA" (both section_ids null)
  - Document-to-provision: "L8 approved under HSWA s.16" (secondary_section_id null)
  - Provision-to-provision: "L8 para.29 implements HSWA reg 6(1)(a)" (both populated)

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("source_links")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_link, [
      :secondary_source_id,
      :secondary_section_id,
      :law_name,
      :section_id,
      :link_type
    ])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Secondary source side
    attribute :secondary_source_id, :uuid do
      allow_nil?(false)
      description("FK to secondary_sources")
    end

    attribute :secondary_section_id, :string do
      allow_nil?(true)

      description(
        "Optional provision within the secondary source (e.g. ACOP_hse_2013_L8:para.29)"
      )
    end

    # Primary legislation side
    attribute :law_name, :string do
      allow_nil?(false)
      description("Law identifier from legal_register (e.g. UK_ukpga_1974_37)")
    end

    attribute :section_id, :string do
      allow_nil?(true)
      description("Optional provision within the law (e.g. UK_ukpga_1974_37:s.2)")
    end

    # Link classification
    attribute :link_type, SertantaiLegal.Legal.SourceLink.LinkType do
      allow_nil?(false)
      description("approved_under / implements / references / supplements / superseded_by")
    end

    attribute :notes, :string do
      allow_nil?(true)
      description("Free-text explanation of the relationship")
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy, update: [:notes]])

    create :create do
      accept([
        :secondary_source_id,
        :secondary_section_id,
        :law_name,
        :section_id,
        :link_type,
        :notes
      ])
    end

    create :upsert do
      description("Create or update a source link (used by SecondaryTaxaSubscriber)")

      accept([
        :secondary_source_id,
        :secondary_section_id,
        :law_name,
        :section_id,
        :link_type,
        :notes
      ])

      upsert?(true)
      upsert_identity(:unique_link)
      upsert_fields([:notes])
    end

    read :by_secondary_source do
      description("All links for a given secondary source")
      argument(:secondary_source_id, :uuid, allow_nil?: false)
      filter(expr(secondary_source_id == ^arg(:secondary_source_id)))
    end

    read :by_law_name do
      description("All secondary sources linked to a given law")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end
  end

  relationships do
    belongs_to :secondary_source, SertantaiLegal.Legal.SecondarySource do
      source_attribute(:secondary_source_id)
      destination_attribute(:id)
      define_attribute?(false)
      allow_nil?(false)
    end
  end
end
