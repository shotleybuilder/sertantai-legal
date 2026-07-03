defmodule SertantaiLegal.Sync.Templates.TrainingTracker do
  @moduledoc """
  Training Tracker template — mandatory training linked to laws/provisions.

  Tracks who needs what training, when it was completed, and when renewal
  is due. Certificate storage adapts to storage_mode sub-pattern.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @frequencies ["One-off", "Annual", "Biennial", "On Change"]
  @statuses ["Current", "Due", "Overdue", "Not Started"]

  @impl true
  def id, do: :training_tracker

  @impl true
  def name, do: "Training Tracker"

  @impl true
  def requires, do: [:foundation]

  @impl true
  def tables, do: [:training]

  @impl true
  def field_specs(sp) do
    %{
      training:
        [
          %{name: "Course_Name", type: :text, description: "Training title"},
          %{
            name: "Required_By",
            type: :link_row,
            target: :lrt,
            description: "Which law requires this"
          },
          %{name: "Frequency", type: :single_select, options: @frequencies}
        ] ++
          people_fields(sp.people) ++
          [
            %{name: "Completed_Date", type: :date, description: "When last completed"},
            %{name: "Next_Due", type: :date, description: "When renewal due"}
          ] ++
          certificate_fields(sp.storage_mode) ++
          [
            %{name: "Status", type: :single_select, options: @statuses},
            %{
              name: "Days_Until_Due",
              type: :formula,
              expression: %{baserow: "date_diff('day', field('SA_Next_Due'), today())"},
              description: "Days until due (negative = overdue)"
            }
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      training: [
        %{name: "All Training", type: :grid},
        %{
          name: "Overdue",
          type: :grid,
          filters: [%{field: "Status", op: :equal, value: "Overdue"}]
        },
        %{name: "Training Calendar", type: :calendar, date_field: "Next_Due"},
        %{name: "By Status", type: :kanban, stack_by: "Status"}
      ]
    }
  end

  defp people_fields(:linked) do
    [
      %{
        name: "Assigned_To",
        type: :link_row,
        target: :personnel,
        description: "Who needs this training"
      }
    ]
  end

  defp people_fields(:collaborator) do
    [%{name: "Assigned_To", type: :collaborator, description: "Who needs this training"}]
  end

  defp people_fields(:hybrid) do
    [
      %{name: "Assigned_To", type: :collaborator, description: "Task assignee (Baserow user)"},
      %{
        name: "Trainee",
        type: :link_row,
        target: :personnel,
        description: "Who needs this training"
      }
    ]
  end

  defp people_fields(:flat) do
    [%{name: "Assigned_To", type: :text, description: "Who needs this training"}]
  end

  defp certificate_fields(:embedded) do
    [%{name: "Certificate", type: :file, description: "Completion certificate"}]
  end

  defp certificate_fields(:reference) do
    [%{name: "Certificate_URL", type: :url, description: "Link to certificate in DMS"}]
  end
end
