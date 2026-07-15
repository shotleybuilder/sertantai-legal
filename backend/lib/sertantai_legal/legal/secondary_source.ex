defmodule SertantaiLegal.Legal.SecondarySource do
  @moduledoc """
  Document-level record for a second-tier compliance requirement.

  Covers ACoPs, standards, JSPs, guidance notes, and industry codes —
  documents that sit below primary/secondary legislation but above
  operational controls in the compliance hierarchy.

  This is SHARED REFERENCE DATA — no organization_id. Customer scoping
  happens via `OrgSecondaryApplicability` and at Baserow sync time.

  Version chain: when a new edition is published, create a new record
  and set `supersedes_id` on the old one. No provision-level versioning.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_sources")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_source_id, [:source_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Classification
    attribute :source_type, SertantaiLegal.Legal.SecondarySource.SourceType do
      allow_nil?(false)
      description("acop / guidance / standard / jsp / industry_code")
    end

    # Identity
    attribute :source_id, :string do
      allow_nil?(false)
      description("Stable human-readable identifier (e.g. L8, HSG65, JSP-375, ISO-45001)")
    end

    attribute :title, :string do
      allow_nil?(false)
      description("Full document title")
    end

    attribute :issuer, :string do
      allow_nil?(false)
      description("Publishing body (e.g. HSE, MoD, BSI, ISO)")
    end

    # Legal status
    attribute :legal_weight, SertantaiLegal.Legal.SecondarySource.LegalWeight do
      allow_nil?(false)

      description(
        "Compliance enforceability: reverse_burden / regard_had_to / contractual / state_of_art / best_practice"
      )
    end

    attribute :status, SertantaiLegal.Legal.SecondarySource.DocumentStatus do
      allow_nil?(false)
      default(:current)
      description("current / withdrawn / superseded")
    end

    # Edition and dates
    attribute :edition, :string do
      allow_nil?(true)
      description("Edition label (e.g. 4th edition, 2013)")
    end

    attribute :effective_date, :date do
      allow_nil?(true)
      description("Date this edition became effective")
    end

    # Version chain
    attribute :supersedes_id, :uuid do
      allow_nil?(true)
      description("FK to the secondary_source this edition replaces")
    end

    # Source and structure
    attribute :source_url, :string do
      allow_nil?(true)
      description("URL to the authoritative source")
    end

    attribute :structure_type, SertantaiLegal.Legal.SecondarySource.StructureType do
      allow_nil?(true)
      description("Parser hint: volumes / parts / clauses / sections")
    end

    attribute :metadata, :map do
      allow_nil?(true)
      default(%{})
      description("Publisher-specific fields (JSONB)")
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :source_type,
        :source_id,
        :title,
        :issuer,
        :legal_weight,
        :status,
        :edition,
        :effective_date,
        :supersedes_id,
        :source_url,
        :structure_type,
        :metadata
      ])
    end

    update :update do
      accept([
        :title,
        :status,
        :edition,
        :effective_date,
        :supersedes_id,
        :source_url,
        :structure_type,
        :metadata
      ])
    end

    read :by_source_id do
      description("Find a secondary source by its human-readable identifier")
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
    end

    read :by_source_type do
      description("All secondary sources of a given type")
      argument(:source_type, SertantaiLegal.Legal.SecondarySource.SourceType, allow_nil?: false)
      filter(expr(source_type == ^arg(:source_type)))
    end

    read :current do
      description("All secondary sources with status = current")
      filter(expr(status == :current))
    end
  end

  relationships do
    has_many :source_links, SertantaiLegal.Legal.SourceLink do
      source_attribute(:id)
      destination_attribute(:secondary_source_id)
      description("Links to primary legislation this source relates to")
    end
  end
end
