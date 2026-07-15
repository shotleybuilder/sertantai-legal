defmodule SertantaiLegal.Legal.SecondarySourceProvision do
  @moduledoc """
  Parsed provision within a secondary source, analogous to `LegalArticle`.

  Each row represents a structural unit (volume, chapter, paragraph, clause)
  within an ACoP, JSP, standard, or guidance note. Parsed from PDF using
  `extractous_ex` (Tika XML) or `ex_pdfium` (character-level extraction).

  Section_id convention: `{TYPE}_{issuer}_{year}_{id}:{locator}`
  Examples:
  - `ACOP_hse_2013_L8:para.29`
  - `JSP_mod_2024_375:v1.ch25.3`
  - `STD_bsi_2018_45001:cl.6.1.2`

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_source_provisions")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_section_id, [:section_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Identity
    attribute :section_id, :string do
      allow_nil?(false)
      description("Stable provision identifier (e.g. JSP_mod_2024_375:v1.ch25.3)")
    end

    attribute :secondary_source_id, :uuid do
      allow_nil?(false)
      description("FK to secondary_sources")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("Denormalised from parent secondary_source for joins (e.g. JSP-375)")
    end

    # Document structure
    attribute :sort_key, :string do
      allow_nil?(true)
      description("Document order key for sorting provisions in reading order")
    end

    attribute :position, :integer do
      allow_nil?(true)
      description("Numeric position within the document (1-based)")
    end

    attribute :section_type, SertantaiLegal.Legal.SecondarySource.ProvisionSectionType do
      allow_nil?(false)
      description("Structural type: volume / part / chapter / clause / paragraph / etc.")
    end

    attribute :depth, :integer do
      allow_nil?(true)
      description("Nesting depth (0 = top-level volume/part, 1 = chapter, 2 = section, etc.)")
    end

    attribute :hierarchy_path, :string do
      allow_nil?(true)
      description("/ delimited ancestor path for tree queries")
    end

    # Content
    attribute :heading, :string do
      allow_nil?(true)
      description("Section/paragraph heading text")
    end

    attribute :text, :string do
      allow_nil?(true)
      description("Full provision text (nullable for paywalled content)")
    end

    attribute :text_source, SertantaiLegal.Legal.SecondarySource.TextSource do
      allow_nil?(false)
      default(:full_text)
      description("How text was obtained: full_text / summary / heading_only")
    end

    # ── Taxa enrichment (same shape as legal_articles) ──

    attribute :drrp_types, {:array, :string} do
      allow_nil?(true)
      description("Duty / Right / Responsibility / Power classifications")
    end

    attribute :actors, {:array, :map} do
      allow_nil?(true)
      description("[{label, position, relates_to, label_source, reason}]")
    end

    attribute :governed_actors, {:array, :string} do
      allow_nil?(true)
      description("Extracted governed actor labels")
    end

    attribute :popimar, {:array, :string} do
      allow_nil?(true)
      description("POPIMAR management framework categories")
    end

    attribute :purposes, {:array, :string} do
      allow_nil?(true)
      description("Purpose/function classifications")
    end

    attribute :significance_overall, :string do
      allow_nil?(true)
      description("HIGH / MEDIUM / LOW")
    end

    attribute :taxa_enriched_at, :utc_datetime_usec do
      allow_nil?(true)
      description("When taxa enrichment was last applied")
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :section_id,
        :secondary_source_id,
        :source_id,
        :sort_key,
        :position,
        :section_type,
        :depth,
        :hierarchy_path,
        :heading,
        :text,
        :text_source
      ])
    end

    create :upsert do
      description("Create or update a provision (used by parser)")

      accept([
        :section_id,
        :secondary_source_id,
        :source_id,
        :sort_key,
        :position,
        :section_type,
        :depth,
        :hierarchy_path,
        :heading,
        :text,
        :text_source
      ])

      upsert?(true)
      upsert_identity(:unique_section_id)

      upsert_fields([
        :sort_key,
        :position,
        :section_type,
        :depth,
        :hierarchy_path,
        :heading,
        :text,
        :text_source
      ])
    end

    update :update_taxa do
      description("Apply taxa enrichment from fractalaw")

      accept([
        :drrp_types,
        :actors,
        :governed_actors,
        :popimar,
        :purposes,
        :significance_overall,
        :taxa_enriched_at
      ])
    end

    read :by_source do
      description("All provisions for a given secondary source")
      argument(:secondary_source_id, :uuid, allow_nil?: false)
      filter(expr(secondary_source_id == ^arg(:secondary_source_id)))
    end

    read :by_source_id do
      description("All provisions for a given source_id (denormalised)")
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
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
