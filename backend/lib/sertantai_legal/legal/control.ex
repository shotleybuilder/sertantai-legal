defmodule SertantaiLegal.Legal.Control do
  @moduledoc """
  AI-generated control — a compliance mechanism derived from law provisions.

  Published by fractalaw as Arrow IPC over Zenoh, keyed on `(law_name, control_id)`.
  Each control represents an operational mechanism that addresses obligations in a law.

  This is SHARED REFERENCE DATA — no organization_id. Customer scoping happens
  at Baserow sync time by filtering to laws in the customer's Legal Register.

  Policy predicates (one per law — the law's "big idea") share this table
  with `is_predicate: true`.

  ## Three-Way Merge

  The `base_hash` field enables regeneration without losing customer edits
  in Baserow. When fractalaw re-generates controls, the hash identifies
  which fields changed vs. which the customer customised.
  """

  use Ash.Resource,
    domain: SertantaiLegal.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("controls")
    repo(SertantaiLegal.Repo)
  end

  identities do
    identity(:unique_control, [:law_name, :control_id])
  end

  attributes do
    uuid_primary_key(:id, writable?: true)

    # Core identification
    attribute :law_name, :string do
      allow_nil?(false)
      description("Parent law identifier (e.g. UK_uksi_1997_1713)")
    end

    attribute :control_id, :string do
      allow_nil?(false)
      description("UUID from fractalaw — stable identifier for three-way merge")
    end

    attribute :source_id, :string do
      allow_nil?(true)

      description(
        "NULL for legislation controls, JSP chapter ID for JSP controls (e.g. JSP-375-CH23)"
      )
    end

    attribute :related_control_ids, :string do
      allow_nil?(true)
      description("Comma-separated IDs of legislation controls this JSP control implements")
    end

    # Control content
    attribute :title, :string do
      allow_nil?(true)
      description("Indicative-mood control statement")
    end

    attribute :description, :string do
      allow_nil?(true)
      description("What reality the control stands for")
    end

    attribute :what_it_checks, :string do
      allow_nil?(true)
      description("The discriminating test (Type-B)")
    end

    # Classification (Properties)
    attribute :control_type, :string do
      allow_nil?(true)
      description("Preventive / Detective / Corrective / Directive")
    end

    attribute :nature, :string do
      allow_nil?(true)
      description("Manual / Automated / IT-dependent manual")
    end

    attribute :domain, :string do
      allow_nil?(true)
      description("Organisational / People / Physical / Technical")
    end

    # Events (demand regime)
    attribute :frequency, :string do
      allow_nil?(true)
      description("Continuous / Daily / Weekly / Monthly / Quarterly / Annual / Ad-hoc")
    end

    # Distance
    attribute :info_distance, :string do
      allow_nil?(true)
      description("Direct / Adjacent / Mediated / Remote (AI-estimated default)")
    end

    # Methods
    attribute :blast_radius, :string do
      allow_nil?(true)
      description("Local / Area / Site / Enterprise (AI-estimated default)")
    end

    attribute :expected_touch_frequency, :string do
      allow_nil?(true)
      description("How often the control is exercised under normal demand")
    end

    # Provision linkage
    attribute :linked_provisions, {:array, :string} do
      allow_nil?(true)
      description("Short section refs (e.g. [\"reg.3(1)\", \"reg.4(2)\"])")
    end

    attribute :mapping_strength, :string do
      allow_nil?(true)
      description("Primary / Supporting / Ancillary")
    end

    # Judgement and evidence
    attribute :load_bearing_judgement, :string do
      allow_nil?(true)
      description("The irreducible judgement term, or null")
    end

    attribute :evidence_type_a, :string do
      allow_nil?(true)
      description("Activity evidence description (legible proxy)")
    end

    attribute :evidence_type_b, :string do
      allow_nil?(true)
      description("Outcome evidence description (discriminating test)")
    end

    attribute :honest_limit, :string do
      allow_nil?(true)
      description("What resists reduction to a checkable predicate, or null")
    end

    # Status and tier
    attribute :status, :string do
      allow_nil?(true)
      default("Planned")
      description("Planned — all AI-generated controls start as Planned")
    end

    attribute :tier, :string do
      allow_nil?(true)
      default("Jurisdiction")
      description("Jurisdiction — derived from law")
    end

    # Predicate flag
    attribute :is_predicate, :boolean do
      allow_nil?(false)
      default(false)
      description("True for policy predicates (one per law — the law's big idea)")
    end

    # Pipeline metadata
    attribute :generation_model, :string do
      allow_nil?(true)
      description("Which LLM produced this control")
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
      description("Upsert a control from fractalaw Arrow IPC data")

      accept([
        :law_name,
        :control_id,
        :source_id,
        :related_control_ids,
        :title,
        :description,
        :what_it_checks,
        :control_type,
        :nature,
        :domain,
        :frequency,
        :info_distance,
        :blast_radius,
        :expected_touch_frequency,
        :linked_provisions,
        :mapping_strength,
        :load_bearing_judgement,
        :evidence_type_a,
        :evidence_type_b,
        :honest_limit,
        :status,
        :tier,
        :is_predicate,
        :generation_model,
        :base_hash
      ])

      upsert?(true)
      upsert_identity(:unique_control)

      upsert_fields([
        :source_id,
        :related_control_ids,
        :title,
        :description,
        :what_it_checks,
        :control_type,
        :nature,
        :domain,
        :frequency,
        :info_distance,
        :blast_radius,
        :expected_touch_frequency,
        :linked_provisions,
        :mapping_strength,
        :load_bearing_judgement,
        :evidence_type_a,
        :evidence_type_b,
        :honest_limit,
        :status,
        :tier,
        :is_predicate,
        :generation_model,
        :base_hash
      ])
    end

    read :by_law_name do
      description("Controls for a single law")
      argument(:law_name, :string, allow_nil?: false)
      filter(expr(law_name == ^arg(:law_name)))
    end

    read :by_law_names do
      description("Controls for a list of laws (batch Baserow sync)")
      argument(:law_names, {:array, :string}, allow_nil?: false)
      filter(expr(law_name in ^arg(:law_names)))
    end
  end

  relationships do
    has_many :control_mappings, SertantaiLegal.Legal.ControlMapping do
      source_attribute(:id)
      destination_attribute(:control_id)
      description("Provision-level mappings derived from linked_provisions")
    end
  end
end
