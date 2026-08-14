defmodule SertantaiLegal.Legal.LegislativeDefinition do
  @moduledoc """
  Legislative Definitions — one row per defined term per law.

  Stores terms extracted from "Interpretation" sections of UK legislation
  (e.g. `"workplace" means any premises or part of premises...`).

  This is SHARED REFERENCE DATA — no organization_id (accessible to all tenants).

  ## Key design decisions

  - **Per-law rows**: The same term defined by multiple laws gets one row per law,
    enabling side-by-side comparison of how different laws define the same term.
  - **Unique on (law_name, term)**: One definition per term per law. Upserts are idempotent.
  - **law_name is text, not a formal FK**: Matches the pattern used by AmendmentAnnotation.
    JOINs to legal_register use `name` field.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("legislative_definitions")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_law_term, [:law_name, :term])
  end

  attributes do
    uuid_primary_key :id

    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier, e.g. UK_uksi_1999_3242")
    end

    attribute :term, :string do
      allow_nil?(false)
      description("Normalised term (lowercase)")
    end

    attribute :term_welsh, :string do
      allow_nil?(true)
      description("Welsh language equivalent of the term")
    end

    attribute :definition, :string do
      allow_nil?(false)
      description("Full definition text from the Interpretation section")
    end

    attribute :section_id, :string do
      allow_nil?(true)
      description("LAT section where defined, e.g. regulation-2")
    end

    attribute :scope, SertantaiLegal.Legal.LegislativeDefinition.ScopeType do
      allow_nil?(true)
      description("How broadly the definition applies: law, part, or provision")
    end

    attribute :references_other_law, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether the definition references another law for its meaning")
    end

    create_timestamp :inserted_at do
      description("Record creation timestamp")
    end

    update_timestamp :updated_at do
      description("Record update timestamp")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      description("Create a new legislative definition")
      primary?(true)

      accept([
        :law_name,
        :term,
        :term_welsh,
        :definition,
        :section_id,
        :scope,
        :references_other_law
      ])
    end

    create :upsert do
      description("Create or update a definition (idempotent on law_name + term)")
      upsert?(true)
      upsert_identity(:unique_law_term)

      upsert_fields([
        :term_welsh,
        :definition,
        :section_id,
        :scope,
        :references_other_law,
        :updated_at
      ])

      accept([
        :law_name,
        :term,
        :term_welsh,
        :definition,
        :section_id,
        :scope,
        :references_other_law
      ])
    end

    read :by_term do
      description("All definitions of a term across all laws")
      argument(:term, :string, allow_nil?: false)
      filter(expr(term == ^arg(:term)))
    end

    read :by_law do
      description("All definitions in a specific law")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end

    read :by_term_and_law do
      description("Definition of a specific term in a specific law")
      argument(:term, :string, allow_nil?: false)
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(term == ^arg(:term) and law_name == ^arg(:law_name)))
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:read)
    define(:by_term, args: [:term])
    define(:by_law, args: [:law_name])
    define(:by_term_and_law, args: [:term, :law_name])
    define(:create)
    define(:upsert)
    define(:destroy)
  end
end
