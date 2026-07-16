defmodule SertantaiLegal.Sync.Templates.ArtefactTemplates do
  @moduledoc """
  Artefact Templates — AI-generated evidence collection templates.

  Each template describes a thing to collect as evidence for a control.
  Unpacked from the `artefacts_json` array in a fractalaw evidence pattern.
  1-3 templates per evidence pattern, at least one Outcome (Type-B).

  These are TEMPLATES — the customer creates actual artefact records in the
  operational Artefacts table from these templates.

  See `docs/zenoh/ZENOH-EVIDENCE-SPEC.md` § Artefact JSON Structure.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @artefact_types [
    "Policy",
    "Procedure",
    "Certificate",
    "Training Record",
    "Report",
    "Risk Assessment",
    "Permit",
    "Licence",
    "Test Result",
    "Sensor Reading",
    "Other"
  ]

  @artefact_classes ["Activity", "Outcome"]
  @sources ["Upload", "System Generated", "Sensor", "External", "Linked System"]
  @likelihood_ratios ["Low", "Medium", "High"]

  @impl true
  def id, do: :artefact_templates

  @impl true
  def name, do: "Artefact Templates — L4 Evidence Collection Guide"

  @impl true
  def requires, do: [:evidence_patterns, :controls]

  @impl true
  def tables, do: [:artefact_templates]

  @impl true
  def field_specs(_sp) do
    %{
      artefact_templates: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Stable ID: evidence_pattern_id:title"
        },
        %{
          name: "Evidence_Patterns",
          type: :link_row,
          target: :evidence_patterns,
          description: "Parent evidence pattern"
        },
        %{
          name: "Controls",
          type: :link_row,
          target: :controls,
          description: "Parent control (denormalised)"
        },
        %{
          name: "Artefact_Type",
          type: :single_select,
          options: @artefact_types,
          description: "What kind of thing"
        },
        %{
          name: "Artefact_Class",
          type: :single_select,
          options: @artefact_classes,
          description: "Activity (Type-A) or Outcome (Type-B — discriminating)"
        },
        %{
          name: "What_It_Proves",
          type: :long_text,
          description: "What belief this changes"
        },
        %{
          name: "Source",
          type: :single_select,
          options: @sources,
          description: "Where this artefact comes from"
        },
        %{
          name: "Likelihood_Ratio",
          type: :single_select,
          options: @likelihood_ratios,
          description: "Evidential strength: Low / Medium / High"
        },
        %{
          name: "Recommended_Frequency",
          type: :text,
          description: "How often a new instance should be registered"
        },
        %{
          name: "Evidence_By_Design",
          type: :boolean,
          description: "Produced as a natural by-product of the control operating"
        }
      ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      artefact_templates: [
        %{name: "All Artefact Templates", type: :grid},
        %{name: "By Type", type: :grid, group_by: "Artefact_Type"},
        %{name: "By Class", type: :grid, group_by: "Artefact_Class"},
        %{name: "By Control", type: :grid, group_by: "Controls"},
        %{
          name: "Outcome Only",
          type: :grid,
          filters: [%{field: "Artefact_Class", op: :equal, value: "Outcome"}]
        },
        %{
          name: "By Design",
          type: :grid,
          filters: [%{field: "Evidence_By_Design", op: :equal, value: true}]
        }
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp), do: %{}
end
