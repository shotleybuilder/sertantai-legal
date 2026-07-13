defmodule SertantaiLegal.Legal.LegalArticle do
  @moduledoc """
  Legal Articles — one row per structural unit of legal text.

  Each row represents an addressable unit of legislation: a title, part, chapter,
  heading, section, sub-section, article, paragraph, schedule entry, etc.

  This is SHARED REFERENCE DATA — no organization_id (accessible to all tenants).

  ## Relationship
  Many articles belong to one LegalRegister record via `law_id`.
  The `law_name` column is denormalised for query convenience.

  ## Primary Key
  `section_id` is a citation-based structural address, e.g. `UK_ukpga_1974_37:s.25A(1)`.
  Stable across amendments — parliament assigns citations that never change.

  ## Partitioning
  PostgreSQL LIST partition on `country`. Each country has its own physical
  partition (e.g. `legal_articles_uk`). Backwards-compatible `lat` view exists.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("legal_articles")
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

    attribute :country, :string do
      allow_nil?(false)
      default("uk")
      description("Country code: uk, au, nz, etc. Partition key.")
    end

    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier. Denormalised from legal_register.name.")
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
      description("Cross-heading group label")
    end

    attribute :provision, :string do
      allow_nil?(true)
      description("Section (Acts) or article/regulation (SIs) number")
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
      description("Territorial extent. NULL if matches parent default.")
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

    # ── Taxa / DRRP Classification (from fractalaw) ──────────────────
    # Populated via zenoh subscriber from fractalaw provision-level enrichment.
    # NULL until fractalaw processes this provision.

    attribute :drrp_types, {:array, :string} do
      allow_nil?(true)
      description("Duty/Right/Responsibility/Power classifications")
    end

    attribute :governed_actors, {:array, :string} do
      allow_nil?(true)

      description(
        "DEPRECATED — use actors column. Regulated actors flat list, dual-written for backward compat."
      )
    end

    attribute :government_actors, {:array, :string} do
      allow_nil?(true)

      description(
        "DEPRECATED — use actors column. Government actors flat list, dual-written for backward compat."
      )
    end

    attribute :actors, {:array, :map} do
      allow_nil?(true)

      description(
        "Structured actors per provision. Each entry: {label, position, relates_to, label_source, reason}. " <>
          "position: active|counterparty|beneficiary|mentioned. label_source: canonical|invented."
      )
    end

    attribute :extraction_method, :string do
      allow_nil?(true)

      description("How actors were determined: regex|reconciled|slm|llm|inferred")
    end

    attribute :holder_inferred_from, :string do
      allow_nil?(true)
      description("Source of actor inference: self, parent, or comma-separated ancestors")
    end

    attribute :ancestor_distance, :integer do
      allow_nil?(true)
      description("Clause distance when actors inherited from parent provision")
    end

    attribute :duty_family, :string do
      allow_nil?(true)
      description("Duty family classification")
    end

    attribute :duty_sub_type, :string do
      allow_nil?(true)
      description("Duty sub-type classification")
    end

    attribute :clause_refined, :string do
      allow_nil?(true)
      description("AI extraction: 'who must do what' summary of the provision")
    end

    attribute :purposes, {:array, :string} do
      allow_nil?(true)
      description("Purpose/function classifications (Application+Scope, Enforcement, etc.)")
    end

    attribute :popimar, {:array, :string} do
      allow_nil?(true)
      description("POPIMAR management system categories")
    end

    attribute :taxa_confidence, :float do
      allow_nil?(true)
      description("Classification confidence score (0.0–1.0)")
    end

    attribute :taxa_enriched_at, :utc_datetime_usec do
      allow_nil?(true)
      description("When taxa/fitness data was last received from fractalaw")
    end

    # ── Significance (from fractalaw — per-provision) ────────────────
    # Null for non-Obligation provisions and provisions not yet rated.

    attribute :significance_scope_duty_bearer, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — breadth of duty bearer")
    end

    attribute :significance_scope_protected_class, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — breadth of protected class")
    end

    attribute :significance_gravity, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — what's at stake (health/property/admin)")
    end

    attribute :significance_strength, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — obligation strength (absolute/qualified/procedural)")
    end

    attribute :significance_hierarchy, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — structural position in the law")
    end

    attribute :significance_confidence, :float do
      allow_nil?(true)
      description("SLM logprobs average (0-1) — confidence of significance rating")
    end

    attribute :significance_overall, :string do
      allow_nil?(true)
      description("HIGH/MEDIUM/LOW — weighted aggregate of all 5 dimensions")
    end

    # ── Embeddings (populated later) ─────────────────────────────────

    attribute :embedding, {:array, :float} do
      allow_nil?(true)
      description("Semantic embedding vector. NULL until AI pipeline runs.")
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
      description("Original Airtable positional encoding.")
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
    belongs_to :legal_register, SertantaiLegal.Legal.LegalRegister do
      source_attribute(:law_id)
      destination_attribute(:id)
      allow_nil?(false)
      attribute_type(:uuid)
      description("Parent law in the Legal Register")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new legal article record")
      primary?(true)

      accept([
        :section_id,
        :country,
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
      description("Update an existing legal article record")

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

    update :update_taxa do
      description("Update taxa/fitness enrichment from fractalaw")

      accept([
        :drrp_types,
        :governed_actors,
        :government_actors,
        :actors,
        :extraction_method,
        :holder_inferred_from,
        :ancestor_distance,
        :duty_family,
        :duty_sub_type,
        :clause_refined,
        :purposes,
        :popimar,
        :taxa_confidence,
        :taxa_enriched_at,
        :significance_scope_duty_bearer,
        :significance_scope_protected_class,
        :significance_gravity,
        :significance_strength,
        :significance_hierarchy,
        :significance_confidence,
        :significance_overall
      ])
    end

    read :by_law do
      description("Get all articles for a law by law_id, in document order")
      argument(:law_id, :uuid, allow_nil?: false)
      filter(expr(law_id == ^arg(:law_id)))
      prepare(build(sort: [sort_key: :asc]))
      pagination(offset?: true, default_limit: 100)
    end

    read :by_law_name do
      description("Get all articles for a law by law_name, in document order")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
      prepare(build(sort: [sort_key: :asc]))
      pagination(offset?: true, default_limit: 100)
    end

    read :by_section_type do
      description("Get articles filtered by section_type")
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
    define(:update_taxa)
    define(:destroy)
  end
end
