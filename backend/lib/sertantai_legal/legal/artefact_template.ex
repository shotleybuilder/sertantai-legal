defmodule SertantaiLegal.Legal.ArtefactTemplate do
  @moduledoc """
  AI-generated artefact template — a thing to collect as evidence for a control.

  Unpacked from the `artefacts_json` array in a fractalaw evidence pattern.
  Each evidence pattern has 1-3 artefact templates. At least one has
  `artefact_class: "Outcome"` (Type-B — discriminating evidence).

  These are TEMPLATES, not operational artefacts. The customer creates
  actual artefact records in the Baserow Artefacts table from these templates.

  This is SHARED REFERENCE DATA — no organization_id.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("artefact_templates")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_artefact, [:evidence_pattern_id, :title])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    attribute :evidence_pattern_id, :uuid do
      allow_nil?(false)
      description("FK to evidence_patterns.id")
    end

    attribute :title, :string do
      allow_nil?(false)
      description("Domain-specific artefact description")
    end

    attribute :artefact_type, :string do
      allow_nil?(true)

      description(
        "Policy / Procedure / Certificate / Training Record / Report / Risk Assessment / Permit / Licence / Test Result / Sensor Reading / Other"
      )
    end

    attribute :artefact_class, :string do
      allow_nil?(true)
      description("Activity (Type-A) or Outcome (Type-B — discriminating evidence)")
    end

    attribute :what_it_proves, :string do
      allow_nil?(true)

      description(
        "What belief this changes — discriminating test for Outcome, activity record for Activity"
      )
    end

    attribute :source, :string do
      allow_nil?(true)
      description("Upload / System Generated / Sensor / External / Linked System")
    end

    attribute :likelihood_ratio, :string do
      allow_nil?(true)
      description("Low / Medium / High")
    end

    attribute :recommended_frequency, :string do
      allow_nil?(true)
      description("How often a new instance should be registered")
    end

    attribute :evidence_by_design, :boolean do
      allow_nil?(true)

      description(
        "Whether this artefact is produced as a natural by-product of the control operating"
      )
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :upsert do
      description("Upsert an artefact template — idempotent on (evidence_pattern_id, title)")

      accept([
        :evidence_pattern_id,
        :title,
        :artefact_type,
        :artefact_class,
        :what_it_proves,
        :source,
        :likelihood_ratio,
        :recommended_frequency,
        :evidence_by_design
      ])

      upsert?(true)
      upsert_identity(:unique_artefact)

      upsert_fields([
        :artefact_type,
        :artefact_class,
        :what_it_proves,
        :source,
        :likelihood_ratio,
        :recommended_frequency,
        :evidence_by_design
      ])
    end

    read :by_evidence_pattern do
      description("Artefact templates for a specific evidence pattern")
      argument(:evidence_pattern_id, :uuid, allow_nil?: false)
      filter(expr(evidence_pattern_id == ^arg(:evidence_pattern_id)))
    end

    read :by_evidence_pattern_ids do
      description("Artefact templates for a list of evidence patterns (batch Baserow sync)")
      argument(:evidence_pattern_ids, {:array, :uuid}, allow_nil?: false)
      filter(expr(evidence_pattern_id in ^arg(:evidence_pattern_ids)))
    end
  end

  relationships do
    belongs_to :evidence_pattern, SertantaiLegal.Legal.EvidencePattern do
      source_attribute(:evidence_pattern_id)
      destination_attribute(:id)
      define_attribute?(false)
      description("Parent evidence pattern")
    end
  end
end
