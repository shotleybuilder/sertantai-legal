defmodule SertantaiLegal.Sync.Templates.Personnel do
  @moduledoc """
  Personnel template — people, roles, and departments.

  Foundational table for all templates that track who-did-what.
  All "Assigned To", "Assessed By", "Responsible" fields in other
  templates link here instead of using free text.
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
  def field_specs(_sub_patterns) do
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
  end

  @impl true
  def view_specs(_sub_patterns) do
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
  end

  # No seed — customer populates their own people.
end
