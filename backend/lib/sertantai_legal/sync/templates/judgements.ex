defmodule SertantaiLegal.Sync.Templates.Judgements do
  @moduledoc """
  Judgements template — a person's immutable assessment of whether a control
  works and an obligation is met.

  Records who judged, what they observed (basis), what they found (finding),
  and whether the measurement method has drifted (verified_meaning).
  Immutable: new judgement = new record.

  Sub-pattern support:
  - `people: :linked` — Judge links to Personnel table
  - `people: :flat` — text field for judge name
  - `calibration_mode: :full_hubbard` — surfaces confidence_pct, estimate ranges, artefact join
  - `safety_argument: :on` — surfaces Argument_Legs and Configuration_Ref

  See `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md` § 2. Judgements.
  See `docs/compliance/l4-evidence/EVIDENCE-CALIBRATION.md` for terminology.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @judgement_methods [
    "Visual Inspection",
    "Functional Test",
    "Simulation",
    "Interview",
    "Observation",
    "Exercise",
    "Document Review"
  ]

  @findings ["Still True", "Drifted", "Retired"]

  @argument_legs ["Compliance", "ALARP", "Hazard Log"]

  @vindication_statuses ["Supported", "Contradicted", "Unrelated"]

  @impl true
  def id, do: :judgements

  @impl true
  def name, do: "Judgements — L4 Calibrated Assessments"

  @impl true
  def requires, do: [:controls, :personnel]

  @impl true
  def tables, do: [:judgements]

  @impl true
  def field_specs(sp) do
    %{
      judgements:
        [
          %{
            name: "Name",
            type: :text,
            primary: true,
            description: "Judgement name"
          },
          %{
            name: "Judgement",
            type: :formula,
            expression: %{baserow: "concat(field('Controls'), ' — ', field('Finding'))"},
            description: "Display: Control — Finding"
          },
          %{
            name: "Controls",
            type: :link_row,
            target: :controls,
            description: "Which control was assessed"
          }
        ] ++
          judge_fields(sp.people) ++
          [
            %{
              name: "Judgement_Method",
              type: :single_select,
              options: @judgement_methods,
              description: "How the assessment was conducted"
            },
            %{
              name: "Basis",
              type: :long_text,
              description:
                "What was observed, reviewed, or tested — including what was NOT seen and where uncertainty lies"
            },
            %{
              name: "Finding",
              type: :single_select,
              options: @findings,
              description: "Still True (loop closes) / Drifted (Gap created) / Retired"
            },
            %{
              name: "Verified_Meaning",
              type: :long_text,
              description:
                "What the measurement method actually tells us right now. Populated when measurement drift is detected."
            },
            %{name: "Next_Due", type: :date, description: "When this control needs reassessing"},
            %{
              name: "Assessments",
              type: :link_row,
              target: :assessments,
              description: "Which assessment this informs (optional)"
            }
          ] ++
          confidence_fields(sp.calibration_mode) ++
          safety_argument_fields(sp.safety_argument) ++
          artefact_join_fields(sp.calibration_mode) ++
          [
            %{
              name: "Vindication_Status",
              type: :single_select,
              options: @vindication_statuses,
              description:
                "Set retrospectively when an Incident vindicates or contradicts this judgement"
            },
            %{name: "Notes", type: :long_text, description: "Additional context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      judgements: [
        %{name: "All Judgements", type: :grid},
        %{name: "By Control", type: :grid, group_by: "Controls"},
        %{name: "By Finding", type: :kanban, stack_by: "Finding"},
        %{
          name: "Due Soon",
          type: :grid,
          sorts: [%{field: "Next_Due", direction: :asc}]
        },
        %{name: "By Judge", type: :grid, group_by: "Judge"},
        %{name: "By Method", type: :grid, group_by: "Judgement_Method"}
      ]
    }
  end

  # No seed — judgements are created by calibrated people, not pre-populated.

  # ── Judge fields (people sub-pattern) ────────────────────────

  defp judge_fields(:linked) do
    [
      %{
        name: "Judge",
        type: :link_row,
        target: :personnel,
        description: "Named person who exercised judgement"
      }
    ]
  end

  defp judge_fields(:workspace_member) do
    [%{name: "Judge", type: :workspace_member, description: "Person who exercised judgement"}]
  end

  defp judge_fields(:hybrid) do
    [
      %{name: "Judge", type: :workspace_member, description: "Person who exercised judgement"},
      %{
        name: "Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Accountable person in org"
      }
    ]
  end

  defp judge_fields(:flat) do
    [%{name: "Judge", type: :text, description: "Named person who exercised judgement"}]
  end

  # ── Confidence fields (calibration_mode sub-pattern) ─────────

  defp confidence_fields(:full_hubbard) do
    [
      %{
        name: "Confidence_Pct",
        type: :number,
        description:
          "Stated confidence % for binary/categorical findings (0-100). Requires training."
      },
      %{
        name: "Estimate_Lower",
        type: :number,
        description: "Lower bound of range estimate for quantitative assessments"
      },
      %{
        name: "Estimate_Upper",
        type: :number,
        description: "Upper bound of range estimate for quantitative assessments"
      }
    ]
  end

  defp confidence_fields(_), do: []

  # ── Safety argument fields ───────────────────────────────────

  defp safety_argument_fields(:on) do
    [
      %{
        name: "Argument_Legs",
        type: :multi_select,
        options: @argument_legs,
        description: "Which safety argument legs this judgement serves"
      },
      %{
        name: "Configuration_Ref",
        type: :text,
        description: "System version or operating context this judgement applies to"
      }
    ]
  end

  defp safety_argument_fields(_), do: []

  # ── Artefact join (many:many link, full_hubbard only) ────────

  defp artefact_join_fields(:full_hubbard) do
    [
      %{
        name: "Artefacts_Relied_On",
        type: :link_row,
        target: :artefacts,
        description: "Which artefacts the judge relied on (direct evidential link)"
      }
    ]
  end

  defp artefact_join_fields(_), do: []
end
