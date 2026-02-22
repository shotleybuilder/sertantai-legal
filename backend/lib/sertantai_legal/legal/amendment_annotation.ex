defmodule SertantaiLegal.Legal.AmendmentAnnotation do
  @moduledoc """
  Amendment Annotations — one row per legislative change annotation.

  Links amendment footnotes (F-codes, C-codes, I-codes, E-codes) from
  legislation.gov.uk to the LAT sections they affect.

  This is SHARED REFERENCE DATA — no organization_id (accessible to all tenants).

  ## Primary Key
  Synthetic key: `{law_name}:{code_type}:{seq}` — per-law, per-code_type counter.
  Example: `UK_ukpga_1974_37:amendment:1`

  ## Relationship
  Many annotations belong to one LRT record (uk_lrt) via `law_id`.
  The `affected_sections` array references LAT `section_id` values.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("amendment_annotations")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    attribute :id, :string do
      allow_nil?(false)
      primary_key?(true)
      writable?(true)
      description("Synthetic key: {law_name}:{code_type}:{seq}")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier, e.g. UK_ukpga_1974_37")
    end

    attribute :code, :string do
      allow_nil?(false)
      description("Annotation code from legislation.gov.uk: F1, F123, C42, I7, E3")
    end

    attribute :code_type, SertantaiLegal.Legal.AmendmentAnnotation.CodeType do
      allow_nil?(false)
      description("amendment (F), modification (C), commencement (I), extent_editorial (E)")
    end

    attribute :source, :string do
      allow_nil?(false)
      description("Data provenance: csv_import, lat_parser, etc.")
    end

    attribute :text, :string do
      allow_nil?(false)
      description("The annotation text describing the change")
    end

    attribute :affected_sections, {:array, :string} do
      allow_nil?(true)
      description("Array of section_id values from LAT that this annotation applies to")
    end

    create_timestamp :created_at do
      description("Record creation timestamp")
    end

    update_timestamp :updated_at do
      description("Record update timestamp")
    end
  end

  relationships do
    belongs_to :uk_lrt, SertantaiLegal.Legal.UkLrt do
      source_attribute(:law_id)
      destination_attribute(:id)
      allow_nil?(false)
      attribute_type(:uuid)
      description("Parent law in the Legal Register Table")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new amendment annotation")
      primary?(true)

      accept([
        :id,
        :law_name,
        :law_id,
        :code,
        :code_type,
        :source,
        :text,
        :affected_sections
      ])
    end

    read :by_law do
      description("Get all annotations for a law by law_id")
      argument(:law_id, :uuid, allow_nil?: false)
      filter(expr(law_id == ^arg(:law_id)))
    end

    read :by_law_name do
      description("Get all annotations for a law by law_name")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end

    read :by_code_type do
      description("Get annotations filtered by code_type")
      argument(:code_type, SertantaiLegal.Legal.AmendmentAnnotation.CodeType, allow_nil?: false)
      filter(expr(code_type == ^arg(:code_type)))
      pagination(offset?: true, default_limit: 50)
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:read)
    define(:by_law, args: [:law_id])
    define(:by_law_name, args: [:law_name])
    define(:by_code_type, args: [:code_type])
    define(:create)
    define(:destroy)
  end
end
