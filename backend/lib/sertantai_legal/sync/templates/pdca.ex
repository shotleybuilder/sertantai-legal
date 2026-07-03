defmodule SertantaiLegal.Sync.Templates.PDCA do
  @moduledoc """
  PDCA template — Plan-Do-Check-Act improvement cycle tracker.

  For organisations implementing formal management systems (ISO 14001,
  45001, 27001) that require structured continuous improvement.
  Links improvement initiatives to assessments and actions.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @phases ["Plan", "Do", "Check", "Act", "Completed"]

  @impl true
  def id, do: :pdca

  @impl true
  def name, do: "PDCA — Continuous Improvement"

  @impl true
  def requires, do: [:compliance_assessment, :action_tracker]

  @impl true
  def tables, do: [:improvements]

  @impl true
  def field_specs(sp) do
    %{
      improvements:
        [
          %{name: "Title", type: :text, description: "Initiative title"},
          %{name: "Goal", type: :long_text, description: "What we're trying to achieve"},
          %{name: "Phase", type: :single_select, options: @phases}
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "Start_Date", type: :date},
            %{name: "Due_Date", type: :date},
            %{
              name: "Related_Assessments",
              type: :link_row,
              target: :assessments,
              description: "Which compliance gaps this addresses"
            },
            %{
              name: "Related_Actions",
              type: :link_row,
              target: :actions,
              description: "Actions within this initiative"
            },
            %{name: "Outcome", type: :long_text, description: "Results and lessons learned"},
            %{
              name: "Effectiveness_Review_Date",
              type: :date,
              description: "When to verify effectiveness"
            }
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      improvements: [
        %{name: "All Initiatives", type: :grid},
        %{name: "PDCA Board", type: :kanban, stack_by: "Phase"},
        %{name: "Timeline", type: :calendar, date_field: "Due_Date"}
      ]
    }
  end

  defp people_fields(:linked) do
    [%{name: "Owner", type: :link_row, target: :personnel, description: "Initiative owner"}]
  end

  defp people_fields(:workspace_member) do
    [%{name: "Owner", type: :workspace_member, description: "Initiative owner"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "Owner", type: :workspace_member, description: "Initiative owner"}]
  end

  defp people_fields(:flat) do
    [%{name: "Owner", type: :text, description: "Initiative owner"}]
  end
end
