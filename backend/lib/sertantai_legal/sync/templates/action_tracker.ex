defmodule SertantaiLegal.Sync.Templates.ActionTracker do
  @moduledoc """
  Action Tracker template — remediation tasks linked to assessments.

  Tracks corrective, preventative, improvement, and maintenance actions
  with owners, deadlines, and status. Kanban and calendar views for
  workflow management.

  Sub-pattern support:
  - `people: :linked` — Assigned To links to Personnel table
  - `people: :flat` — Assigned To is a text field
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @statuses ["Open", "In Progress", "Completed", "Cancelled"]
  @priorities ["Critical", "High", "Medium", "Low"]
  @action_types ["Corrective", "Preventative", "Improvement", "Maintenance"]

  @impl true
  def id, do: :action_tracker

  @impl true
  def name, do: "Action Tracker"

  @impl true
  def requires, do: [:compliance_assessment]

  @impl true
  def tables, do: [:actions]

  @impl true
  def field_specs(sp) do
    %{
      actions:
        [
          %{name: "SA_Title", type: :text, description: "Action description"},
          %{
            name: "SA_Assessment",
            type: :link_row,
            target: :assessments,
            description: "Which gap this addresses"
          },
          %{name: "SA_Law", type: :lookup, target: :assessments, target_field: "SA_Law"},
          %{
            name: "SA_Status",
            type: :single_select,
            options: @statuses,
            description: "Current status"
          },
          %{
            name: "SA_Priority",
            type: :single_select,
            options: @priorities
          },
          %{
            name: "SA_Action_Type",
            type: :single_select,
            options: @action_types
          }
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "SA_Due_Date", type: :date, description: "Deadline"},
            %{name: "SA_Completed_Date", type: :date, description: "When completed"},
            %{name: "SA_Notes", type: :long_text, description: "Progress notes"},
            %{
              name: "SA_Days_Until_Due",
              type: :formula,
              expression: %{baserow: "date_diff('day', field('SA_Due_Date'), today())"},
              description: "Days until deadline (negative = overdue)"
            },
            %{
              name: "SA_Overdue",
              type: :formula,
              expression: %{
                baserow:
                  "if(and(field('SA_Status') != 'Completed', field('SA_Status') != 'Cancelled', field('SA_Days_Until_Due') < 0), 'OVERDUE', '')"
              },
              description: "OVERDUE if past due and not completed"
            }
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      actions: [
        %{name: "All Actions", type: :grid},
        %{
          name: "Overdue",
          type: :grid,
          filters: [%{field: "SA_Overdue", op: :equal, value: "OVERDUE"}]
        },
        %{name: "Action Board", type: :kanban, stack_by: "SA_Status"},
        %{name: "Timeline", type: :calendar, date_field: "SA_Due_Date"},
        %{name: "By Priority", type: :grid, group_by: "SA_Priority"},
        %{name: "By Type", type: :grid, group_by: "SA_Action_Type"}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    %{
      assessments: [
        %{
          name: "SA_Open_Actions",
          type: :rollup,
          target: :actions,
          target_field: "SA_Status",
          rollup_function: :count,
          description: "Number of linked actions"
        }
      ]
    }
  end

  @impl true
  def webhook_specs do
    [%{table: :actions, events: [:created, :updated]}]
  end

  defp people_fields(:linked) do
    [
      %{
        name: "SA_Assigned_To",
        type: :link_row,
        target: :personnel,
        description: "Person responsible"
      }
    ]
  end

  defp people_fields(:collaborator) do
    [%{name: "SA_Assigned_To", type: :collaborator, description: "Person responsible"}]
  end

  defp people_fields(:hybrid) do
    [
      %{name: "SA_Assigned_To", type: :collaborator, description: "Task assignee (Baserow user)"},
      %{
        name: "SA_Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Responsible in org"
      }
    ]
  end

  defp people_fields(:flat) do
    [%{name: "SA_Assigned_To", type: :text, description: "Person responsible"}]
  end
end
