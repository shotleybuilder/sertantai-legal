defmodule SertantaiLegal.Legal.SecondaryTerm do
  @moduledoc """
  Acronym or definition extracted from a secondary source provision.

  Captures terms like "ELV" (Extra Low Voltage), "DSEAR" (Dangerous Substances
  and Explosive Atmospheres Regulations 2002). Used for glossary generation
  and conflict detection across sources.

  term_id convention: `{source_id}:{normalised}`
  Example: `JSP-375-CH23:elv`

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_terms")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_term_id, [:term_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :term_id, :string do
      allow_nil?(false)
      description("Stable ID: {source_id}:{normalised}")
    end

    attribute :section_id, :string do
      allow_nil?(false)
      description("Where the term was defined")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("Denormalised for fast filtering")
    end

    attribute :term, :string do
      allow_nil?(false)
      description("Full expansion (e.g. 'Extra Low Voltage')")
    end

    attribute :acronym, :string do
      allow_nil?(true)
      description("Abbreviation (e.g. 'ELV')")
    end

    attribute :normalised, :string do
      allow_nil?(false)
      description("Lowercase for dedup and conflict detection")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :upsert do
      accept([:term_id, :section_id, :source_id, :term, :acronym, :normalised])

      upsert?(true)
      upsert_identity(:unique_term_id)
      upsert_fields([:term, :acronym, :section_id])
    end

    read :by_source_id do
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
    end

    read :by_normalised do
      argument(:normalised, :string, allow_nil?: false)
      filter(expr(normalised == ^arg(:normalised)))
    end
  end
end
