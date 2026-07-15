defmodule SertantaiLegal.Sync.Templates.Personnel do
  @moduledoc """
  Personnel template — people, roles, and departments.

  Adapts based on `people` sub-pattern:

  - `:flat` — no table created, downstream templates use text fields
  - `:workspace_member` — no table created, downstream templates use Baserow Collaborators fields
  - `:linked` — Personnel table created, downstream templates use link_row fields
  - `:hybrid` — Personnel table created, downstream templates use both Collaborators + link_row
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @impl true
  def id, do: :personnel

  @impl true
  def name, do: "Personnel — People, Roles & Departments"

  @impl true
  def requires, do: []

  @impl true
  def tables, do: [:personnel]

  @impl true
  def field_specs(sub_patterns) do
    case sub_patterns.people do
      mode when mode in [:linked, :hybrid] ->
        %{
          personnel:
            [
              %{
                name: "Name",
                type: :text,
                primary: true,
                description: "Full name"
              },
              %{
                name: "Employee_ID",
                type: :text,
                description: "Unique employee reference"
              },
              %{name: "Email", type: :email, description: "Email address"},
              %{
                name: "Role",
                type: :single_select,
                options: [
                  "Compliance Manager",
                  "Safety Officer",
                  "Environmental Officer",
                  "Legal Counsel",
                  "Line Manager",
                  "Engineer",
                  "Operative",
                  "Contractor",
                  "Director",
                  "Other"
                ],
                description: "Organisational role"
              },
              %{
                name: "Department",
                type: :single_select,
                options: [],
                description: "Department — customer populates options"
              },
              %{name: "Active", type: :boolean, description: "Currently employed/active"},
              %{
                name: "Baserow User",
                type: :workspace_member,
                description: "Linked Baserow workspace member"
              }
            ] ++ calibrator_fields(sub_patterns.calibration_mode)
        }

      # :flat and :workspace_member — no table needed
      _ ->
        %{}
    end
  end

  @impl true
  def view_specs(sub_patterns) do
    case sub_patterns.people do
      mode when mode in [:linked, :hybrid] ->
        %{
          personnel: [
            %{name: "All Personnel", type: :grid},
            %{
              name: "Active",
              type: :grid,
              filters: [%{field: "Active", op: :equal, value: true}]
            },
            %{name: "By Role", type: :grid, group_by: "Role"},
            %{name: "By Department", type: :grid, group_by: "Department"}
          ]
        }

      _ ->
        %{}
    end
  end

  # No seed — customer populates their own people.

  # ── Calibrator quality fields ────────────────────────────────

  defp calibrator_fields(mode) when mode in [:calibrator_aware, :full_hubbard] do
    [
      %{
        name: "Calibration_Score",
        type: :number,
        description:
          "Accuracy % (Hubbard-style, 0-100). Measured, not self-assessed. Firewalled from HR."
      },
      %{
        name: "Calibration_Sample_Size",
        type: :number,
        description:
          "How many judgements the score is based on. 85 (n=200) is solid; 85 (n=5) is preliminary."
      },
      %{
        name: "Last_Cal_Test",
        type: :date,
        description: "When calibration accuracy was last tested"
      },
      %{
        name: "Calibrated_Domains",
        type: :multi_select,
        options: [
          "EHS",
          "Environmental",
          "Fire",
          "Electrical",
          "Process Safety",
          "Information Security",
          "Quality",
          "Regulatory",
          "Other"
        ],
        description: "Which domains this person is calibrated to judge"
      }
    ]
  end

  defp calibrator_fields(_), do: []
end
