defmodule SertantaiLegal.Legal.EvidencePattern do
  @moduledoc """
  AI-generated evidence pattern — how to prove a control works.

  Published by fractalaw as Arrow IPC over Zenoh, keyed on `(law_name, control_id)`.
  Each evidence pattern is 1:1 with a Control and describes what artefacts to collect,
  whether professional judgement is needed, and how to detect drift.

  This is SHARED REFERENCE DATA — no organization_id. Customer scoping happens
  at Baserow sync time by filtering to laws in the customer's Legal Register.

  ## Artefact Templates

  The `artefacts_json` field from fractalaw is unpacked into separate
  `ArtefactTemplate` records (1-3 per evidence pattern). At least one
  has `artefact_class: "Outcome"` (Type-B — discriminating evidence).

  ## Three-Way Merge

  The `base_hash` field enables regeneration without losing customer edits
  in Baserow. Same merge logic as controls.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("evidence_patterns")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_evidence_pattern, [:law_name, :control_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Core identification (matches parent Control's identity)
    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier (e.g. UK_uksi_1997_1713)")
    end

    attribute :control_id, :string do
      allow_nil?(false)
      description("FK to controls.control_id — the fractalaw UUID")
    end

    attribute :control_title, :string do
      allow_nil?(true)
      description("Denormalised control title for readability")
    end

    # Judgement fields
    attribute :needs_judgement, :boolean do
      allow_nil?(true)
      description("Whether artefacts alone are insufficient")
    end

    attribute :judgement_rationale, :string do
      allow_nil?(true)
      description("Why judgement is or isn't needed — always populated")
    end

    attribute :recommended_method, :string do
      allow_nil?(true)

      description(
        "Visual Inspection / Functional Test / Simulation / Interview / Observation / Exercise / Document Review — null when needs_judgement=false"
      )
    end

    attribute :basis_guidance, :string do
      allow_nil?(true)
      description("What the assessor should look at — null when needs_judgement=false")
    end

    attribute :discriminating_question, :string do
      allow_nil?(true)
      description("The question the judge answers — null when needs_judgement=false")
    end

    attribute :drift_signal, :string do
      allow_nil?(true)

      description(
        "How the measurement method can decouple from reality — null when needs_judgement=false"
      )
    end

    # Always-populated fields
    attribute :drift_conditions, :string do
      allow_nil?(true)

      description(
        "When the control itself has drifted (bridges to Gaps entity) — always populated"
      )
    end

    # Value of Information classification
    attribute :voi_quadrant, :string do
      allow_nil?(true)
      description("Table Stakes / No-Brainer / Judgement / Waste")
    end

    attribute :voi_rationale, :string do
      allow_nil?(true)
      description("Why this VoI classification — references control properties")
    end

    # Evidence calibration
    attribute :evidence_standard, :string do
      allow_nil?(true)
      description("Basic / Focused / Comprehensive (from blast_radius)")
    end

    attribute :recommended_interval, :string do
      allow_nil?(true)
      description("How often evidence should be refreshed")
    end

    attribute :sample_size_guidance, :string do
      allow_nil?(true)
      description("For manual controls: how many instances to evidence per period")
    end

    attribute :staleness_tolerance, :string do
      allow_nil?(true)
      description("Low / Medium / High")
    end

    attribute :nature_strategy, :string do
      allow_nil?(true)
      description("Evidence strategy from the control's Nature (Automated/Manual/hybrid)")
    end

    # Pipeline metadata
    attribute :generation_model, :string do
      allow_nil?(true)
      description("Which LLM produced this pattern")
    end

    attribute :base_hash, :string do
      allow_nil?(true)
      description("Deterministic hash for three-way merge on regeneration")
    end

    # Timestamps
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :upsert_from_fractalaw do
      description("Upsert an evidence pattern from fractalaw Arrow IPC data")

      accept([
        :law_name,
        :control_id,
        :control_title,
        :needs_judgement,
        :judgement_rationale,
        :recommended_method,
        :basis_guidance,
        :discriminating_question,
        :drift_signal,
        :drift_conditions,
        :voi_quadrant,
        :voi_rationale,
        :evidence_standard,
        :recommended_interval,
        :sample_size_guidance,
        :staleness_tolerance,
        :nature_strategy,
        :generation_model,
        :base_hash
      ])

      upsert?(true)
      upsert_identity(:unique_evidence_pattern)

      upsert_fields([
        :control_title,
        :needs_judgement,
        :judgement_rationale,
        :recommended_method,
        :basis_guidance,
        :discriminating_question,
        :drift_signal,
        :drift_conditions,
        :voi_quadrant,
        :voi_rationale,
        :evidence_standard,
        :recommended_interval,
        :sample_size_guidance,
        :staleness_tolerance,
        :nature_strategy,
        :generation_model,
        :base_hash
      ])
    end

    read :by_law_name do
      description("Evidence patterns for a single law")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end

    read :by_law_names do
      description("Evidence patterns for a list of laws (batch Baserow sync)")
      argument(:law_names, {:array, :string}, allow_nil?: false)
      filter(expr(law_name in ^arg(:law_names)))
    end
  end

  relationships do
    has_many :artefact_templates, SertantaiLegal.Legal.ArtefactTemplate do
      source_attribute(:id)
      destination_attribute(:evidence_pattern_id)
      description("Artefact templates unpacked from artefacts_json")
    end
  end
end
