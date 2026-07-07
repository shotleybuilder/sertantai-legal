defmodule SertantaiLegal.Sync.Templates.Artefacts do
  @moduledoc """
  Artefacts template — a register of things that carry information about
  whether an obligation is met.

  Documents, logs, certificates, test results, sensor readings — references
  to things that exist in operational systems, not the things themselves.
  Each artefact is a signal to judgement: some high-confidence (Type-B outcome),
  some low-confidence (Type-A activity). All feed judgement as input.

  Refactored from the original Evidence Vault template. Judgement fields
  (Judged_By, Basis, Reasoning, Confidence) moved to the Judgements template.

  Sub-pattern support:
  - `storage_mode: :embedded` — File field for direct uploads
  - `storage_mode: :reference` — URL + text fields pointing to SharePoint/DMS
  - `people: :linked` — Uploaded By links to Personnel table
  - `people: :flat` — text field for name
  - `safety_argument: :on` — surfaces Argument_Legs and Configuration_Ref

  See `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md` § 1. Artefacts.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @artefact_types [
    "Policy",
    "Procedure",
    "Certificate",
    "Training Record",
    "Inspection Report",
    "Risk Assessment",
    "Permit",
    "Licence",
    "Test Result",
    "Sensor Reading",
    "Other"
  ]

  @artefact_classes ["Activity", "Outcome"]

  @sources ["Upload", "System Generated", "Sensor", "External", "Linked System"]

  @argument_legs ["Compliance", "ALARP", "Hazard Log"]

  @statuses ["Current", "Expired", "Superseded"]

  @impl true
  def id, do: :artefacts

  @impl true
  def name, do: "Artefacts — L4 Evidence Register"

  @impl true
  def requires, do: [:compliance_assessment, :controls]

  @impl true
  def tables, do: [:artefacts]

  @impl true
  def field_specs(sp) do
    %{
      artefacts:
        [
          %{name: "Title", type: :text, description: "Artefact description"},
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
            description:
              "Activity (Type-A, proves activity happened) or Outcome (Type-B, proves a result)"
          },
          %{
            name: "Control",
            type: :link_row,
            target: :controls,
            description: "Which control this relates to (primary link)"
          },
          %{
            name: "Assessment",
            type: :link_row,
            target: :assessments,
            description: "Which assessment this supports"
          },
          %{
            name: "Action",
            type: :link_row,
            target: :actions,
            description: "Which action this completes"
          },
          %{
            name: "Source",
            type: :single_select,
            options: @sources,
            description: "Where this artefact comes from"
          }
        ] ++
          safety_argument_fields(sp.safety_argument) ++
          artifact_fields(sp.storage_mode) ++
          people_fields(sp.people) ++
          [
            %{name: "Version", type: :text, description: "Document version"},
            %{
              name: "Expiry_Date",
              type: :date,
              description: "When this artefact expires"
            },
            %{
              name: "Status",
              type: :single_select,
              options: @statuses
            },
            %{name: "Notes", type: :long_text, description: "Context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      artefacts: [
        %{name: "All Artefacts", type: :grid},
        %{
          name: "Expiring Soon",
          type: :grid,
          filters: [%{field: "Status", op: :equal, value: "Current"}],
          sorts: [%{field: "Expiry_Date", direction: :asc}]
        },
        %{name: "By Type", type: :grid, group_by: "Artefact_Type"},
        %{name: "By Class", type: :grid, group_by: "Artefact_Class"},
        %{name: "By Control", type: :grid, group_by: "Control"},
        %{name: "Gallery", type: :gallery}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    # Rollups deferred to Phase 2 reconciliation (#112)
    %{}
  end

  # ── Safety argument fields (horizontal evidence) ─────────────

  defp safety_argument_fields(:on) do
    [
      %{
        name: "Argument_Legs",
        type: :multi_select,
        options: @argument_legs,
        description:
          "Which safety argument legs this artefact serves (Compliance / ALARP / Hazard Log)"
      },
      %{
        name: "Configuration_Ref",
        type: :text,
        description:
          "System version, configuration, or operating context this artefact applies to"
      }
    ]
  end

  defp safety_argument_fields(_), do: []

  # ── Storage mode fields ──────────────────────────────────────

  defp artifact_fields(:embedded) do
    [
      %{name: "File", type: :file, description: "Uploaded document"},
      %{name: "Upload_Date", type: :date, description: "When uploaded"}
    ]
  end

  defp artifact_fields(:reference) do
    [
      %{name: "Document_URL", type: :url, description: "Link to document in DMS"},
      %{
        name: "Document_Location",
        type: :text,
        description: "Where the document is stored (e.g. SharePoint path)"
      },
      %{name: "Upload_Date", type: :date, description: "When referenced"}
    ]
  end

  # ── People fields ────────────────────────────────────────────

  defp people_fields(:linked) do
    [
      %{
        name: "Uploaded_By",
        type: :link_row,
        target: :personnel,
        description: "Who registered this artefact"
      }
    ]
  end

  defp people_fields(:workspace_member) do
    [%{name: "Uploaded_By", type: :workspace_member, description: "Who registered this artefact"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "Uploaded_By", type: :workspace_member, description: "Who registered this artefact"}]
  end

  defp people_fields(:flat) do
    [%{name: "Uploaded_By", type: :text, description: "Who registered this artefact"}]
  end
end
