defmodule SertantaiLegal.Sync.Templates.Personnel do
  @moduledoc """
  Personnel template — people, roles, and departments.

  Adapts based on `people` sub-pattern:

  - `:flat` — no table created, downstream templates use text fields
  - `:collaborator` — no table created, downstream templates use Baserow Collaborators fields
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
            %{name: "SA_Name", type: :text, description: "Full name"},
            %{name: "SA_Email", type: :email, description: "Email address"},
            %{
              name: "SA_Role",
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
              name: "SA_Department",
              type: :single_select,
              options: [],
              description: "Department — customer populates options"
            },
            %{name: "SA_Employee_ID", type: :text, description: "Internal reference"},
            %{name: "SA_Active", type: :boolean, description: "Currently employed/active"}
          ]
        }

      # :flat and :collaborator — no table needed
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
              filters: [%{field: "SA_Active", op: :equal, value: true}]
            },
            %{name: "By Role", type: :grid, group_by: "SA_Role"},
            %{name: "By Department", type: :grid, group_by: "SA_Department"}
          ]
        }

      _ ->
        %{}
    end
  end

  # No seed — customer populates their own people.
end
