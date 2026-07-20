defmodule SertantaiLegal.Legal.SecondaryObligation do
  @moduledoc """
  Individual obligation extracted from a secondary source provision.

  A single provision paragraph may contain multiple obligations (e.g.,
  lettered list items "a. X must... b. Y must..."). Each gets its own row
  with a stable `obligation_id` for RACI linkage.

  obligation_id convention: `{section_id}:ob.{index}`
  Example: `JSP_mod_2026_JSP375CH23:part-1-directive/policy-statements.para.23:ob.0`

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_obligations")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_obligation_id, [:obligation_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :obligation_id, :string do
      allow_nil?(false)
      description("Stable ID: {section_id}:ob.{index}")
    end

    attribute :section_id, :string do
      allow_nil?(false)
      description("FK to secondary_source_provisions.section_id")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("Denormalised from parent provision for fast filtering")
    end

    attribute :obligation_index, :integer do
      allow_nil?(false)
      description("Position within the provision (0-based)")
    end

    attribute :text, :string do
      allow_nil?(true)
      description("Full obligation text")
    end

    attribute :modal_verb, :string do
      allow_nil?(true)
      description("shall / must / will / should / may / is to")
    end

    attribute :strength, :string do
      allow_nil?(true)
      description("Mandatory / Recommended / Permissive")
    end

    attribute :clause_refined, :string do
      allow_nil?(true)
      description("'Who must do what' extract")
    end

    attribute :competence_requirements, :string do
      allow_nil?(true)
      description("Comma-separated competence requirements")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :upsert do
      accept([
        :obligation_id,
        :section_id,
        :source_id,
        :obligation_index,
        :text,
        :modal_verb,
        :strength,
        :clause_refined,
        :competence_requirements
      ])

      upsert?(true)
      upsert_identity(:unique_obligation_id)

      upsert_fields([
        :text,
        :modal_verb,
        :strength,
        :clause_refined,
        :competence_requirements
      ])
    end

    read :by_source_id do
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
    end

    read :by_section_id do
      argument(:section_id, :string, allow_nil?: false)
      filter(expr(section_id == ^arg(:section_id)))
    end
  end
end
