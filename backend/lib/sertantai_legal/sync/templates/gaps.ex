defmodule SertantaiLegal.Sync.Templates.Gaps do
  @moduledoc """
  Gaps template — the governed gap with three exits.

  When a judgement finds drift (Finding = Drifted), a Gap record is created.
  A named owner decides the response:

  - Correct Work: the practice was wrong. Creates an Action.
  - Amend Constraint: the obligation/control was wrong. Triggers update workflow.
  - Protect Adaptation: the gap is healthy resilience. No Action created.

  The Gap is a first-class entity because a Judgement may find no gap
  (Finding = Still True), and Protect Adaptation creates no Action.

  See `docs/compliance/l4-evidence/EVIDENCE-SCHEMA.md` § 3. Gaps.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @gap_types ["Drift", "Non-Conformance", "Deviation", "Near Miss"]

  @exit_decisions ["Correct Work", "Amend Constraint", "Protect Adaptation"]

  @statuses ["Open", "Resolved", "Accepted"]

  @impl true
  def id, do: :gaps

  @impl true
  def name, do: "Gaps — L4 Reconciliation Decisions"

  @impl true
  def requires, do: [:judgements, :controls, :personnel]

  @impl true
  def tables, do: [:gaps]

  @impl true
  def field_specs(sp) do
    %{
      gaps:
        [
          %{
            name: "Name",
            type: :text,
            primary: true,
            description: "Gap name"
          },
          %{
            name: "Gap",
            type: :formula,
            expression: %{
              baserow: "concat(field('Controls'), ' — ', field('Exit_Decision'))"
            },
            description: "Display: Control — Exit Decision"
          },
          %{
            name: "Judgements",
            type: :link_row,
            target: :judgements,
            description: "Which judgement identified this gap"
          },
          %{
            name: "Controls",
            type: :link_row,
            target: :controls,
            description: "Which control has the gap (denormalised)"
          },
          %{
            name: "Gap_Type",
            type: :single_select,
            options: @gap_types,
            description: "What kind of gap"
          },
          %{
            name: "Exit_Decision",
            type: :single_select,
            options: @exit_decisions,
            description: "Correct Work / Amend Constraint / Protect Adaptation"
          },
          %{
            name: "Decision_Date",
            type: :date,
            description: "When the exit was decided"
          },
          %{
            name: "Reason",
            type: :long_text,
            description:
              "Why this exit was chosen. Append-only — each entry dated and attributed."
          },
          %{
            name: "Status",
            type: :single_select,
            options: @statuses,
            description: "Open / Resolved / Accepted"
          }
        ] ++
          owner_fields(sp.people) ++
          [
            %{
              name: "Actions",
              type: :link_row,
              target: :actions,
              description: "Created if Exit = Correct Work"
            },
            %{name: "Notes", type: :long_text, description: "Additional context"}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      gaps: [
        %{name: "All Gaps", type: :grid},
        %{
          name: "Open Gaps",
          type: :grid,
          filters: [%{field: "Status", op: :equal, value: "Open"}]
        },
        %{name: "By Exit", type: :kanban, stack_by: "Exit_Decision"},
        %{name: "By Control", type: :grid, group_by: "Controls"},
        %{name: "By Type", type: :grid, group_by: "Gap_Type"}
      ]
    }
  end

  # No seed — gaps are created when judgements find drift.

  # ── Owner fields (people sub-pattern) ────────────────────────

  defp owner_fields(:linked) do
    [
      %{
        name: "Owner",
        type: :link_row,
        target: :personnel,
        description: "Who owns the resolution"
      }
    ]
  end

  defp owner_fields(:workspace_member) do
    [%{name: "Owner", type: :workspace_member, description: "Who owns the resolution"}]
  end

  defp owner_fields(:hybrid) do
    [
      %{name: "Owner", type: :workspace_member, description: "Who owns the resolution"},
      %{
        name: "Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Accountable person in org"
      }
    ]
  end

  defp owner_fields(:flat) do
    [%{name: "Owner", type: :text, description: "Who owns the resolution"}]
  end
end
