defmodule SertantaiLegal.Sync.Templates.EvidenceVault do
  @moduledoc """
  Evidence Vault template — documents, certificates, and records proving compliance.

  Sub-pattern support:
  - `storage_mode: :embedded` — File field for direct uploads into Baserow
  - `storage_mode: :reference` — URL + text fields pointing to SharePoint/DMS
  - `people: :linked` — Uploaded By links to Personnel table
  - `people: :flat` — Uploaded By is a text field
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @evidence_types [
    "Policy",
    "Procedure",
    "Certificate",
    "Training Record",
    "Inspection Report",
    "Risk Assessment",
    "Permit",
    "Licence",
    "Other"
  ]

  @evidence_statuses ["Current", "Expired", "Superseded"]

  @impl true
  def id, do: :evidence_vault

  @impl true
  def name, do: "Evidence Vault"

  @impl true
  def requires, do: [:compliance_assessment]

  @impl true
  def tables, do: [:evidence]

  @impl true
  def field_specs(sp) do
    %{
      evidence:
        [
          %{name: "SA_Title", type: :text, description: "Evidence description"},
          %{
            name: "SA_Type",
            type: :single_select,
            options: @evidence_types
          },
          %{
            name: "SA_Assessment",
            type: :link_row,
            target: :assessments,
            description: "Which assessment this supports"
          },
          %{
            name: "SA_Action",
            type: :link_row,
            target: :actions,
            description: "Which action this completes"
          }
        ] ++
          artifact_fields(sp.storage_mode) ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Version", type: :text, description: "Document version"},
            %{
              name: "SA_Expiry_Date",
              type: :date,
              description: "When this evidence expires (e.g., certificate renewal)"
            },
            %{
              name: "SA_Status",
              type: :single_select,
              options: @evidence_statuses
            },
            %{name: "SA_Notes", type: :long_text, description: "Context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      evidence: [
        %{name: "All Evidence", type: :grid},
        %{
          name: "Expiring Soon",
          type: :grid,
          filters: [%{field: "SA_Status", op: :equal, value: "Current"}],
          sorts: [%{field: "SA_Expiry_Date", direction: :asc}]
        },
        %{name: "By Type", type: :grid, group_by: "SA_Type"},
        %{name: "Gallery", type: :gallery}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    %{
      assessments: [
        %{
          name: "SA_Evidence_Count",
          type: :rollup,
          target: :evidence,
          target_field: "SA_Title",
          rollup_function: :count,
          description: "Number of evidence items linked"
        }
      ]
    }
  end

  # ── Sub-pattern field builders ────────────────────────────────

  defp artifact_fields(:embedded) do
    [
      %{name: "SA_File", type: :file, description: "Uploaded document"},
      %{name: "SA_Upload_Date", type: :date, description: "When uploaded"}
    ]
  end

  defp artifact_fields(:reference) do
    [
      %{name: "SA_Document_URL", type: :url, description: "Link to document in DMS"},
      %{
        name: "SA_Document_Location",
        type: :text,
        description: "Where the document is stored (e.g., SharePoint path)"
      },
      %{name: "SA_Upload_Date", type: :date, description: "When referenced"}
    ]
  end

  defp people_fields(:linked) do
    [
      %{
        name: "SA_Uploaded_By",
        type: :link_row,
        target: :personnel,
        description: "Who uploaded/referenced"
      }
    ]
  end

  defp people_fields(:collaborator) do
    [%{name: "SA_Uploaded_By", type: :collaborator, description: "Who uploaded/referenced"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "SA_Uploaded_By", type: :collaborator, description: "Who uploaded/referenced"}]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Uploaded_By", type: :text, description: "Who uploaded/referenced"}]
  end
end
