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
          %{name: "SA_Title", type: :text, description: "Initiative title"},
          %{name: "SA_Goal", type: :long_text, description: "What we're trying to achieve"},
          %{name: "SA_Phase", type: :single_select, options: @phases}
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Start_Date", type: :date},
            %{name: "SA_Due_Date", type: :date},
            %{
              name: "SA_Related_Assessments",
              type: :link_row,
              target: :assessments,
              description: "Which compliance gaps this addresses"
            },
            %{
              name: "SA_Related_Actions",
              type: :link_row,
              target: :actions,
              description: "Actions within this initiative"
            },
            %{name: "SA_Outcome", type: :long_text, description: "Results and lessons learned"},
            %{
              name: "SA_Effectiveness_Review_Date",
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
        %{name: "PDCA Board", type: :kanban, stack_by: "SA_Phase"},
        %{name: "Timeline", type: :calendar, date_field: "SA_Due_Date"}
      ]
    }
  end

  defp people_fields(:linked) do
    [%{name: "SA_Owner", type: :link_row, target: :personnel, description: "Initiative owner"}]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Owner", type: :text, description: "Initiative owner"}]
  end
end
