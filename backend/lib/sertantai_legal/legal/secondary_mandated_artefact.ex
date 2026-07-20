defmodule SertantaiLegal.Legal.SecondaryMandatedArtefact do
  @moduledoc """
  Artefact mandated by a secondary source obligation.

  Captures what documents/records an obligation requires (risk assessments,
  permits, safety cases, etc.) and the matched text that triggered detection.

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("secondary_mandated_artefacts")
    repo(SertantaiLegal.Repo)
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :obligation_id, :string do
      allow_nil?(false)
      description("FK to secondary_obligations.obligation_id")
    end

    attribute :section_id, :string do
      allow_nil?(false)
      description("Denormalised from parent obligation")
    end

    attribute :source_id, :string do
      allow_nil?(false)
      description("Denormalised for fast filtering")
    end

    attribute :artefact_type, :string do
      allow_nil?(false)
      description("Risk Assessment / Safety Case / Hazard Log / Permit / etc.")
    end

    attribute :matched_text, :string do
      allow_nil?(true)
      description("Text fragment that triggered artefact detection")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :obligation_id,
        :section_id,
        :source_id,
        :artefact_type,
        :matched_text
      ])
    end

    read :by_source_id do
      argument(:source_id, :string, allow_nil?: false)
      filter(expr(source_id == ^arg(:source_id)))
    end

    read :by_obligation_id do
      argument(:obligation_id, :string, allow_nil?: false)
      filter(expr(obligation_id == ^arg(:obligation_id)))
    end

    read :by_artefact_type do
      argument(:artefact_type, :string, allow_nil?: false)
      filter(expr(artefact_type == ^arg(:artefact_type)))
    end
  end
end
