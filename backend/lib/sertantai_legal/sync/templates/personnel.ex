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
          personnel: [
            %{
              name: "Employee_ID",
              type: :text,
              primary: true,
              description: "Unique employee reference"
            },
            %{name: "Name", type: :text, description: "Full name"},
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
          ]
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
end
