defmodule SertantaiLegal.Sync.Templates.IncidentRegister do
  @moduledoc """
  Incident Register template — non-conformances, near misses, and deviations.

  Critical for ISO 14001/45001. Links to assessments (which compliance gap)
  and actions (corrective/preventative).
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @severities ["Critical", "Major", "Minor", "Near Miss"]
  @statuses ["Open", "Investigating", "Closed"]

  @impl true
  def id, do: :incident_register

  @impl true
  def name, do: "Incident Register"

  @impl true
  def requires, do: [:compliance_assessment, :action_tracker]

  @impl true
  def tables, do: [:incidents]

  @impl true
  def field_specs(sp) do
    %{
      incidents:
        [
          %{name: "Title", type: :text, description: "Incident description"},
          %{name: "Date", type: :date, description: "When it occurred"},
          %{name: "Severity", type: :single_select, options: @severities},
          %{name: "Description", type: :long_text, description: "Full details"},
          %{name: "Root_Cause", type: :long_text, description: "Investigation findings"},
          %{
            name: "Assessment",
            type: :link_row,
            target: :assessments,
            description: "Related compliance gap"
          },
          %{
            name: "Corrective_Action",
            type: :link_row,
            target: :actions,
            description: "Corrective action taken"
          },
          %{
            name: "Preventative_Action",
            type: :link_row,
            target: :actions,
            description: "Preventative action"
          }
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "Status", type: :single_select, options: @statuses}
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      incidents: [
        %{name: "All Incidents", type: :grid},
        %{
          name: "Open",
          type: :grid,
          filters: [%{field: "Status", op: :not_equal, value: "Closed"}]
        },
        %{name: "By Severity", type: :grid, group_by: "Severity"},
        %{name: "Incident Board", type: :kanban, stack_by: "Status"},
        %{
          name: "Report Form",
          type: :form
        }
      ]
    }
  end

  @impl true
  def webhook_specs do
    [%{table: :incidents, events: [:created, :updated]}]
  end

  defp people_fields(:linked) do
    [%{name: "Reported_By", type: :link_row, target: :personnel, description: "Who reported"}]
  end

  defp people_fields(:collaborator) do
    [%{name: "Reported_By", type: :collaborator, description: "Who reported"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "Reported_By", type: :collaborator, description: "Who reported"}]
  end

  defp people_fields(:flat) do
    [%{name: "Reported_By", type: :text, description: "Who reported"}]
  end
end
