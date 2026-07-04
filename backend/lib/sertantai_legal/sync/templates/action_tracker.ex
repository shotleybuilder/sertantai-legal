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
  def requires, do: [:compliance_assessment, :controls]

  @impl true
  def tables, do: [:actions]

  @impl true
  def field_specs(sp) do
    %{
      actions:
        [
          %{
            name: "Action",
            type: :formula,
            primary: true,
            expression: %{
              baserow: "concat(field('Assessment'), ' — ', field('Title'))"
            },
            description: "Display: Assessment — Title"
          },
          %{
            name: "Title",
            type: :text,
            description:
              "Short action phrase (e.g. 'Develop lone working RA'). Use Notes for detail."
          },
          %{
            name: "Assessment",
            type: :link_row,
            target: :assessments,
            description: "Which gap this addresses"
          },
          %{name: "Law", type: :lookup, target: "Assessment", target_field: "Law"},
          %{
            name: "Status",
            type: :single_select,
            options: @statuses,
            description: "Current status"
          },
          %{
            name: "Priority",
            type: :single_select,
            options: @priorities
          },
          %{
            name: "Action_Type",
            type: :single_select,
            options: @action_types
          }
        ] ++
          people_fields(sp.people) ++
          [
            %{
              name: "Control",
              type: :link_row,
              target: :controls,
              description: "Which control to fix/improve/create"
            },
            %{name: "Due_Date", type: :date, description: "Deadline"},
            %{name: "Completed_Date", type: :date, description: "When completed"},
            %{name: "Notes", type: :long_text, description: "Progress notes"},
            %{
              name: "Days_Until_Due",
              type: :formula,
              expression: %{baserow: "date_diff('day', field('Due_Date'), today())"},
              description: "Days until deadline (negative = overdue)"
            },
            %{
              name: "Overdue",
              type: :formula,
              expression: %{
                baserow:
                  "if(and(and(field('Status') != 'Completed', field('Status') != 'Cancelled'), field('Days_Until_Due') < 0), 'OVERDUE', '')"
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
          filters: [%{field: "Overdue", op: :equal, value: "OVERDUE"}]
        },
        %{name: "Action Board", type: :kanban, stack_by: "Status"},
        %{name: "Timeline", type: :calendar, date_field: "Due_Date"},
        %{name: "By Priority", type: :grid, group_by: "Priority"},
        %{name: "By Type", type: :grid, group_by: "Action_Type"}
      ]
    }
  end

  @impl true
  def cross_table_fields(_sp) do
    # Rollup on Assessments requires the reverse link_row field name.
    # Deferred to Phase 2. Use Baserow Count field manually.
    %{}
  end

  @impl true
  def webhook_specs do
    [%{table: :actions, events: [:created, :updated]}]
  end

  defp people_fields(:linked) do
    [
      %{
        name: "Assigned_To",
        type: :link_row,
        target: :personnel,
        description: "Person responsible"
      }
    ]
  end

  defp people_fields(:workspace_member) do
    [%{name: "Assigned_To", type: :workspace_member, description: "Person responsible"}]
  end

  defp people_fields(:hybrid) do
    [
      %{
        name: "Assigned_To",
        type: :workspace_member,
        description: "Task assignee (Baserow user)"
      },
      %{
        name: "Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Responsible in org"
      }
    ]
  end

  defp people_fields(:flat) do
    [%{name: "Assigned_To", type: :text, description: "Person responsible"}]
  end
end
