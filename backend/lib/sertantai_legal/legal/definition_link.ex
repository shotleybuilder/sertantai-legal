defmodule SertantaiLegal.Legal.DefinitionLink do
  @moduledoc """
  Junction table linking cross-referencing definitions to their root (originating)
  definitions.

  A child definition like Fire Safety Order's "local housing authority — as in
  section 261(2) of the Housing Act 2004" links to the Housing Act's own definition
  of that term. When the parent law defines the same term in multiple sections
  (e.g. England vs Wales), a child can link to all of them.

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("definition_links")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    attribute :child_definition_id, :uuid do
      allow_nil?(false)
      primary_key?(true)
    end

    attribute :root_definition_id, :uuid do
      allow_nil?(false)
      primary_key?(true)
    end

    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :child_definition, SertantaiLegal.Legal.LegislativeDefinition do
      source_attribute(:child_definition_id)
      allow_nil?(false)
      define_attribute?(false)
    end

    belongs_to :root_definition, SertantaiLegal.Legal.LegislativeDefinition do
      source_attribute(:root_definition_id)
      allow_nil?(false)
      define_attribute?(false)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:child_definition_id, :root_definition_id])
    end
  end

  code_interface do
    domain(SertantaiLegal.Api)
    define(:read)
    define(:create)
    define(:destroy)
  end
end
