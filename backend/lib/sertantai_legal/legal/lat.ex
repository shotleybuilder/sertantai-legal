defmodule SertantaiLegal.Legal.Lat do
  @moduledoc """
  Legal Articles Table (LAT) — one row per structural unit of legal text.

  Each row represents an addressable unit of legislation: a title, part, chapter,
  heading, section, sub-section, article, paragraph, schedule entry, etc.

  This is SHARED REFERENCE DATA — no organization_id (accessible to all tenants).

  ## Relationship
  Many LAT records belong to one LRT record (uk_lrt) via `law_id`.
  The `law_name` column is denormalised for query convenience.

  ## Primary Key
  `section_id` is a citation-based structural address, e.g. `UK_ukpga_1974_37:s.25A(1)`.
  Stable across amendments — parliament assigns citations that never change.

  ## Data Source
  ~97,500 rows from 452 UK laws, parsed from legislation.gov.uk.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("lat")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    # ── Identity & Position ──────────────────────────────────────────

    attribute :section_id, :string do
      allow_nil?(false)
      primary_key?(true)
      writable?(true)
      description("Structural citation PK, e.g. UK_ukpga_1974_37:s.25A(1)")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier, e.g. UK_ukpga_1974_37. Denormalised from uk_lrt.name.")
    end

    attribute :sort_key, :string do
      allow_nil?(false)
      description("Normalised sort encoding. ORDER BY sort_key recovers document order.")
    end

    attribute :position, :integer do
      allow_nil?(false)
      description("Snapshot document-order index (1-based) within the law at export time.")
    end

    attribute :section_type, SertantaiLegal.Legal.Lat.SectionType do
      allow_nil?(false)
      description("Structural type: title, part, chapter, heading, section, article, etc.")
    end

    attribute :hierarchy_path, :string do
      allow_nil?(true)
      description("Slash-separated path, e.g. part.1/heading.2/provision.3. NULL for root.")
    end

    attribute :depth, :integer do
      allow_nil?(false)
      description("Count of populated hierarchy levels. 0 = title/root.")
    end

    # ── Structural Hierarchy ─────────────────────────────────────────

    attribute :part, :string do
      allow_nil?(true)
      description("Part number/letter")
    end

    attribute :chapter, :string do
      allow_nil?(true)
      description("Chapter number")
    end

    attribute :heading_group, :string do
      allow_nil?(true)
      description("Cross-heading group label — lead section number under parent heading.")
    end

    attribute :provision, :string do
      allow_nil?(true)

      description(
        "Section (Acts) or article/regulation (SIs) number. section_type distinguishes."
      )
    end

    attribute :paragraph, :string do
      allow_nil?(true)
      description("Paragraph number")
    end

    attribute :sub_paragraph, :string do
      allow_nil?(true)
      description("Sub-paragraph number")
    end

    attribute :schedule, :string do
      allow_nil?(true)
      description("Schedule/annex number")
    end

    # ── Content ──────────────────────────────────────────────────────

    attribute :text, :string do
      allow_nil?(false)
      description("The legal text content of this structural unit.")
    end

    attribute :language, :string do
      allow_nil?(false)
      default("en")
      description("Language code: en, de, fr, no, sv, fi, tr, ru")
    end

    attribute :extent_code, :string do
      allow_nil?(true)
      description("Territorial extent, e.g. E+W, E+W+S+NI, S. NULL if matches parent default.")
    end

    # ── Amendment Annotation Counts ──────────────────────────────────

    attribute :amendment_count, :integer do
      allow_nil?(true)
      description("F-codes: textual amendments")
    end

    attribute :modification_count, :integer do
      allow_nil?(true)
      description("C-codes: modifications to how provisions apply")
    end

    attribute :commencement_count, :integer do
      allow_nil?(true)
      description("I-codes: commencement (bringing into force)")
    end

    attribute :extent_count, :integer do
      allow_nil?(true)
      description("E-codes: extent/territorial annotations")
    end

    attribute :editorial_count, :integer do
      allow_nil?(true)
      description("Editorial notes")
    end

    # ── Embeddings (populated later) ─────────────────────────────────

    attribute :embedding, {:array, :float} do
      allow_nil?(true)
      description("Semantic embedding vector (384 dimensions). NULL until AI pipeline runs.")
    end

    attribute :embedding_model, :string do
      allow_nil?(true)
      description("Model used: all-MiniLM-L6-v2, etc.")
    end

    attribute :embedded_at, :utc_datetime_usec do
      allow_nil?(true)
      description("When embedding was generated")
    end

    # ── Pre-tokenized Text (populated later) ─────────────────────────

    attribute :token_ids, {:array, :integer} do
      allow_nil?(true)
      description("Pre-tokenized token IDs for the text column")
    end

    attribute :tokenizer_model, :string do
      allow_nil?(true)
      description("Tokenizer model used")
    end

    # ── Migration ────────────────────────────────────────────────────

    attribute :legacy_id, :string do
      allow_nil?(true)
      description("Original Airtable positional encoding. 1.5% collision rate — not a key.")
    end

    # ── Timestamps ───────────────────────────────────────────────────

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
      description("Create a new LAT record")
      primary?(true)

      accept([
        :section_id,
        :law_name,
        :law_id,
        :sort_key,
        :position,
        :section_type,
        :hierarchy_path,
        :depth,
        :part,
        :chapter,
        :heading_group,
        :provision,
        :paragraph,
        :sub_paragraph,
        :schedule,
        :text,
        :language,
        :extent_code,
        :amendment_count,
        :modification_count,
        :commencement_count,
        :extent_count,
        :editorial_count,
        :embedding,
        :embedding_model,
        :embedded_at,
        :token_ids,
        :tokenizer_model,
        :legacy_id
      ])
    end

    update :update do
      description("Update an existing LAT record")

      accept([
        :sort_key,
        :position,
        :hierarchy_path,
        :depth,
        :part,
        :chapter,
        :heading_group,
        :provision,
        :paragraph,
        :sub_paragraph,
        :schedule,
        :text,
        :language,
        :extent_code,
        :amendment_count,
        :modification_count,
        :commencement_count,
        :extent_count,
        :editorial_count,
        :embedding,
        :embedding_model,
        :embedded_at,
        :token_ids,
        :tokenizer_model,
        :legacy_id
      ])
    end

    read :by_law do
      description("Get all LAT records for a law by law_id, in document order")
      argument(:law_id, :uuid, allow_nil?: false)
      filter(expr(law_id == ^arg(:law_id)))
      prepare(build(sort: [sort_key: :asc]))
      pagination(offset?: true, default_limit: 100)
    end

    read :by_law_name do
      description("Get all LAT records for a law by law_name, in document order")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
      prepare(build(sort: [sort_key: :asc]))
      pagination(offset?: true, default_limit: 100)
    end

    read :by_section_type do
      description("Get LAT records filtered by section_type")
      argument(:section_type, SertantaiLegal.Legal.Lat.SectionType, allow_nil?: false)
      filter(expr(section_type == ^arg(:section_type)))
      pagination(offset?: true, default_limit: 50)
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:read)
    define(:by_law, args: [:law_id])
    define(:by_law_name, args: [:law_name])
    define(:by_section_type, args: [:section_type])
    define(:create)
    define(:update)
    define(:destroy)
  end
end
