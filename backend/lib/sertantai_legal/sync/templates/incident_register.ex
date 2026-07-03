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
          %{name: "SA_Title", type: :text, description: "Incident description"},
          %{name: "SA_Date", type: :date, description: "When it occurred"},
          %{name: "SA_Severity", type: :single_select, options: @severities},
          %{name: "SA_Description", type: :long_text, description: "Full details"},
          %{name: "SA_Root_Cause", type: :long_text, description: "Investigation findings"},
          %{
            name: "SA_Assessment",
            type: :link_row,
            target: :assessments,
            description: "Related compliance gap"
          },
          %{
            name: "SA_Corrective_Action",
            type: :link_row,
            target: :actions,
            description: "Corrective action taken"
          },
          %{
            name: "SA_Preventative_Action",
            type: :link_row,
            target: :actions,
            description: "Preventative action"
          }
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Status", type: :single_select, options: @statuses}
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
          filters: [%{field: "SA_Status", op: :not_equal, value: "Closed"}]
        },
        %{name: "By Severity", type: :grid, group_by: "SA_Severity"},
        %{name: "Incident Board", type: :kanban, stack_by: "SA_Status"},
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
    [%{name: "SA_Reported_By", type: :link_row, target: :personnel, description: "Who reported"}]
  end

  defp people_fields(:collaborator) do
    [%{name: "SA_Reported_By", type: :collaborator, description: "Who reported"}]
  end

  defp people_fields(:hybrid) do
    [%{name: "SA_Reported_By", type: :collaborator, description: "Who reported"}]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Reported_By", type: :text, description: "Who reported"}]
  end
end
