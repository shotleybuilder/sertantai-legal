defmodule SertantaiLegal.Sync.Templates.EvidenceVault do
  @moduledoc """
  Evidence Vault template — artifacts and judgement records proving compliance.

  Handles two natures of evidence:
  - **Artifact** — documents, logs, certificates proving the *form* of a control
  - **Judgement** — a named person's assessed conclusion proving the *substance*

  Judgement evidence carries additional fields (Judged_By, Basis, Reasoning,
  Confidence) to record the exercise of professional judgement, not a tick.

  Sub-pattern support:
  - `storage_mode: :embedded` — File field for direct uploads into Baserow
  - `storage_mode: :reference` — URL + text fields pointing to SharePoint/DMS
  - `people: :linked` — Uploaded By / Judged By link to Personnel table
  - `people: :flat` — text fields for names

  See `docs/EVIDENCE-VAULT-PATTERNS.md` § The Operationalisation Paradox.
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
    "Judgement Record",
    "Other"
  ]

  @evidence_natures ["Artifact", "Judgement"]
  @confidence_levels ["High", "Medium", "Low"]
  @evidence_statuses ["Current", "Expired", "Superseded"]

  @impl true
  def id, do: :evidence_vault

  @impl true
  def name, do: "Evidence Vault"

  @impl true
  def requires, do: [:compliance_assessment, :controls]

  @impl true
  def tables, do: [:evidence]

  @impl true
  def field_specs(sp) do
    %{
      evidence:
        [
          %{name: "Title", type: :text, description: "Evidence description"},
          %{
            name: "Type",
            type: :single_select,
            options: @evidence_types
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
            name: "Control",
            type: :link_row,
            target: :controls,
            description: "Which control this proves operated"
          },
          %{
            name: "Evidence_Nature",
            type: :single_select,
            options: @evidence_natures,
            description:
              "Artifact (document/log proves form) or Judgement (person's conclusion proves substance)"
          }
        ] ++
          artifact_fields(sp.storage_mode) ++
          people_fields(sp.people) ++
          judgement_fields(sp.people) ++
          [
            %{name: "Version", type: :text, description: "Document version"},
            %{
              name: "Expiry_Date",
              type: :date,
              description: "When this evidence expires (e.g., certificate renewal)"
            },
            %{
              name: "Status",
              type: :single_select,
              options: @evidence_statuses
            },
            %{name: "Notes", type: :long_text, description: "Context"}
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
          filters: [%{field: "Status", op: :equal, value: "Current"}],
          sorts: [%{field: "Expiry_Date", direction: :asc}]
        },
        %{name: "By Type", type: :grid, group_by: "Type"},
        %{
          name: "Judgements",
          type: :grid,
          filters: [%{field: "Evidence_Nature", op: :equal, value: "Judgement"}]
        },
        %{
          name: "Artifacts",
          type: :grid,
          filters: [%{field: "Evidence_Nature", op: :equal, value: "Artifact"}]
        },
        %{name: "By Control", type: :grid, group_by: "Control"},
        %{name: "Gallery", type: :gallery}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    # Rollup on Assessments requires the reverse link_row field name that
    # Baserow auto-creates. Deferred to Phase 2 reconciliation (#112).
    # For PoC: use Baserow's native Count field (see BASEROW-CONFIG-RECIPES.md)
    %{}
  end

  # ── Sub-pattern field builders ────────────────────────────────

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
        description: "Where the document is stored (e.g., SharePoint path)"
      },
      %{name: "Upload_Date", type: :date, description: "When referenced"}
    ]
  end

  # ── Judgement fields (load-bearing evidence) ──────────────────

  defp judgement_fields(:linked) do
    [
      %{
        name: "Judged_By",
        type: :link_row,
        target: :personnel,
        description: "Named person who exercised professional judgement"
      },
      %{
        name: "Basis",
        type: :long_text,
        description: "What was observed, reviewed, or tested to form the judgement"
      },
      %{
        name: "Reasoning",
        type: :long_text,
        description: "Why the conclusion was reached — the professional rationale"
      },
      %{
        name: "Confidence",
        type: :single_select,
        options: @confidence_levels,
        description: "How confident the judgement is"
      }
    ]
  end

  defp judgement_fields(:workspace_member) do
    [
      %{
        name: "Judged_By",
        type: :workspace_member,
        description: "Person who exercised judgement"
      },
      %{
        name: "Basis",
        type: :long_text,
        description: "What was observed, reviewed, or tested to form the judgement"
      },
      %{
        name: "Reasoning",
        type: :long_text,
        description: "Why the conclusion was reached — the professional rationale"
      },
      %{
        name: "Confidence",
        type: :single_select,
        options: @confidence_levels,
        description: "How confident the judgement is"
      }
    ]
  end

  defp judgement_fields(:hybrid) do
    [
      %{
        name: "Judged_By",
        type: :workspace_member,
        description: "Person who exercised judgement"
      },
      %{
        name: "Basis",
        type: :long_text,
        description: "What was observed, reviewed, or tested to form the judgement"
      },
      %{
        name: "Reasoning",
        type: :long_text,
        description: "Why the conclusion was reached — the professional rationale"
      },
      %{
        name: "Confidence",
        type: :single_select,
        options: @confidence_levels,
        description: "How confident the judgement is"
      }
    ]
  end

  defp judgement_fields(:flat) do
    [
      %{name: "Judged_By", type: :text, description: "Named person who exercised judgement"},
      %{
        name: "Basis",
        type: :long_text,
        description: "What was observed, reviewed, or tested to form the judgement"
      },
      %{
        name: "Reasoning",
        type: :long_text,
        description: "Why the conclusion was reached — the professional rationale"
      },
      %{
        name: "Confidence",
        type: :single_select,
        options: @confidence_levels,
        description: "How confident the judgement is"
      }
    ]
  end

  # ── People fields (who uploaded/referenced) ──────────────────

  defp people_fields(:linked) do
    [
      %{
        name: "Uploaded_By",
        type: :link_row,
        target: :personnel,
        description: "Who uploaded/referenced"
      }
    ]
  end

  defp people_fields(:workspace_member) do
    [%{name: "Uploaded_By", type: :workspace_member, description: "Who uploaded/referenced"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "Uploaded_By", type: :workspace_member, description: "Who uploaded/referenced"}]
  end

  defp people_fields(:flat) do
    [%{name: "Uploaded_By", type: :text, description: "Who uploaded/referenced"}]
  end
end
