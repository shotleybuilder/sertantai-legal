defmodule SertantaiLegal.Sync.Templates.ComplianceAssessment do
  @moduledoc """
  Compliance Assessment template — per-law compliance status + gap analysis.

  Creates an Assessments table linked to the Foundation LRT table.
  Adapts fields based on sub-patterns:

  - `risk_scoring: :simple` — single Risk Level select
  - `risk_scoring: :matrix` — Likelihood × Impact with formula score
  - `people: :linked` — Assessment Owner / Assessed By link to Personnel
  - `people: :flat` — text fields for names
  - `review_cycle: :scheduled` — Review Frequency + Next Review Date + formula
  - `review_cycle: :manual` — just Next Review Date, no frequency
  - `assessment_grain: :law` — one row per law (seed from LRT)
  - `assessment_grain: :provision` — one row per provision (seed from LAT)
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @compliance_statuses [
    "Compliant",
    "Partially Compliant",
    "Non-Compliant",
    "Not Assessed",
    "Not Applicable"
  ]

  @risk_levels ["Critical", "High", "Medium", "Low"]

  @likelihood_options [
    "Almost Certain",
    "Likely",
    "Possible",
    "Unlikely",
    "Rare"
  ]

  @impact_options [
    "Catastrophic",
    "Major",
    "Moderate",
    "Minor",
    "Insignificant"
  ]

  @review_frequencies ["Quarterly", "Bi-annually", "Annually", "Biennial"]

  @impl true
  def id, do: :compliance_assessment

  @impl true
  def name, do: "Compliance Assessment"

  @impl true
  def requires, do: [:foundation, :personnel]

  @impl true
  def tables, do: [:assessments]

  @impl true
  def field_specs(sp) do
    %{
      assessments:
        core_fields() ++
          people_fields(sp.people) ++
          review_fields(sp.review_cycle) ++
          risk_fields(sp.risk_scoring) ++
          detail_fields()
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      assessments: [
        %{name: "All Assessments", type: :grid},
        %{
          name: "Non-Compliant",
          type: :grid,
          filters: [
            %{field: "SA_Compliance_Status", op: :contains, value: "Non-Compliant"}
          ]
        },
        %{
          name: "Overdue Reviews",
          type: :grid,
          filters: [
            %{field: "SA_Review_Status", op: :equal, value: "OVERDUE"}
          ]
        },
        %{name: "By Family", type: :grid, group_by: "SA_Family"},
        %{name: "Compliance Board", type: :kanban, stack_by: "SA_Compliance_Status"},
        %{name: "Review Calendar", type: :calendar, date_field: "SA_Next_Review_Date"}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    %{
      lrt: [
        %{
          name: "SA_Assessment_Count",
          type: :rollup,
          target: :assessments,
          target_field: "SA_Compliance_Status",
          rollup_function: :count,
          description: "Number of assessments linked to this law"
        }
      ]
    }
  end

  @impl true
  def webhook_specs do
    [
      %{table: :assessments, events: [:updated]}
    ]
  end

  @impl true
  def seed(context) do
    case context.sub_patterns.assessment_grain do
      :law -> seed_from_lrt(context)
      :provision -> seed_from_lat(context)
    end
  end

  # ── Field builders by sub-pattern ─────────────────────────────

  defp core_fields do
    [
      %{
        name: "SA_Law",
        type: :link_row,
        target: :lrt,
        description: "Which law is being assessed"
      },
      %{
        name: "SA_Compliance_Status",
        type: :single_select,
        options: @compliance_statuses,
        description: "Current compliance status"
      },
      %{name: "SA_Family", type: :lookup, target: :lrt, target_field: "Family"},
      %{name: "SA_Law_Status", type: :lookup, target: :lrt, target_field: "Status"}
    ]
  end

  defp people_fields(:linked) do
    [
      %{
        name: "SA_Assessment_Owner",
        type: :link_row,
        target: :personnel,
        description: "Accountable person"
      },
      %{
        name: "SA_Assessed_By",
        type: :link_row,
        target: :personnel,
        description: "Who performed assessment"
      },
      %{name: "SA_Assessment_Date", type: :date, description: "When last assessed"}
    ]
  end

  defp people_fields(:flat) do
    [
      %{name: "SA_Assessment_Owner", type: :text, description: "Accountable person"},
      %{name: "SA_Assessed_By", type: :text, description: "Who performed assessment"},
      %{name: "SA_Assessment_Date", type: :date, description: "When last assessed"}
    ]
  end

  defp review_fields(:scheduled) do
    [
      %{
        name: "SA_Review_Frequency",
        type: :single_select,
        options: @review_frequencies,
        description: "How often to reassess"
      },
      %{name: "SA_Next_Review_Date", type: :date, description: "When to reassess"},
      %{
        name: "SA_Days_Until_Review",
        type: :formula,
        expression: %{baserow: "date_diff('day', field('SA_Next_Review_Date'), today())"},
        description: "Days until next review (negative = overdue)"
      },
      %{
        name: "SA_Review_Status",
        type: :formula,
        expression: %{
          baserow:
            "if(field('SA_Days_Until_Review') < 0, 'OVERDUE', if(field('SA_Days_Until_Review') < 30, 'Due Soon', 'OK'))"
        },
        description: "OVERDUE / Due Soon / OK"
      }
    ]
  end

  defp review_fields(:manual) do
    [
      %{name: "SA_Next_Review_Date", type: :date, description: "When to reassess"}
    ]
  end

  defp risk_fields(:matrix) do
    [
      %{name: "SA_Risk_Level", type: :single_select, options: @risk_levels},
      %{name: "SA_Likelihood", type: :single_select, options: @likelihood_options},
      %{name: "SA_Impact", type: :single_select, options: @impact_options},
      %{
        name: "SA_Risk_Score",
        type: :formula,
        expression: %{
          baserow: """
          if(
            and(field('SA_Likelihood') != '', field('SA_Impact') != ''),
            (
              if(field('SA_Likelihood') = 'Almost Certain', 5,
              if(field('SA_Likelihood') = 'Likely', 4,
              if(field('SA_Likelihood') = 'Possible', 3,
              if(field('SA_Likelihood') = 'Unlikely', 2, 1))))
            ) * (
              if(field('SA_Impact') = 'Catastrophic', 5,
              if(field('SA_Impact') = 'Major', 4,
              if(field('SA_Impact') = 'Moderate', 3,
              if(field('SA_Impact') = 'Minor', 2, 1))))
            ),
            0
          )
          """
        },
        description: "Likelihood × Impact (1-25)"
      }
    ]
  end

  defp risk_fields(:simple) do
    [
      %{name: "SA_Risk_Level", type: :single_select, options: @risk_levels}
    ]
  end

  defp detail_fields do
    [
      %{
        name: "SA_Gap_Description",
        type: :long_text,
        description: "What's missing or non-compliant"
      },
      %{name: "SA_Notes", type: :long_text, description: "General notes"},
      %{name: "SA_Reference", type: :text, description: "Internal ID or cross-reference"}
    ]
  end

  # ── Seed logic ────────────────────────────────────────────────

  defp seed_from_lrt(context) do
    # Get LRT row mappings — one Assessment per law
    lrt_mappings = Map.get(context.row_mappings, :lrt, [])

    if lrt_mappings == [] do
      {:ok, 0}
    else
      rows =
        Enum.map(lrt_mappings, fn mapping ->
          %{
            "SA_Law" => [mapping.external_row_id],
            "SA_Compliance_Status" => "Not Assessed",
            "SA_Next_Review_Date" => Date.add(Date.utc_today(), 90) |> Date.to_iso8601()
          }
        end)

      assessments_table_id = Map.get(context.table_ids, :assessments)

      case context.provider.batch_create(context.config, assessments_table_id, rows) do
        {:ok, mappings} -> {:ok, length(mappings)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp seed_from_lat(context) do
    # Get LAT row mappings — one Assessment per provision
    lat_mappings = Map.get(context.row_mappings, :lat, [])

    if lat_mappings == [] do
      {:ok, 0}
    else
      rows =
        Enum.map(lat_mappings, fn mapping ->
          %{
            "SA_Compliance_Status" => "Not Assessed",
            "SA_Next_Review_Date" => Date.add(Date.utc_today(), 90) |> Date.to_iso8601()
          }
        end)

      assessments_table_id = Map.get(context.table_ids, :assessments)

      case context.provider.batch_create(context.config, assessments_table_id, rows) do
        {:ok, mappings} -> {:ok, length(mappings)}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
