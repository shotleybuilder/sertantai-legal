defmodule SertantaiLegal.Sync.Templates.AppUsers do
  @moduledoc """
  App Users template — authentication table for the published Compliance Workbench.

  Separate from Personnel (org directory). App Users are the subset of people
  who log into the app. A link_row to Personnel connects the user to their
  org record.

  Used by Baserow User Sources for published app authentication.
  Required fields for User Source: Name (primary), Email, Password, Role.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @roles ["admin", "assessor", "viewer"]

  @impl true
  def id, do: :app_users

  @impl true
  def name, do: "App Users — Published App Authentication"

  @impl true
  def requires, do: [:personnel]

  @impl true
  def tables, do: [:app_users]

  @impl true
  def field_specs(_sub_patterns) do
    %{
      app_users: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Display name"
        },
        %{
          name: "Email",
          type: :email,
          description: "Login email address"
        },
        %{
          name: "Password",
          type: :password,
          description: "Hashed login password (Baserow Password field)"
        },
        %{
          name: "Role",
          type: :single_select,
          options: @roles,
          description: "App role for element-level RBAC"
        },
        %{
          name: "Active",
          type: :boolean,
          description: "Account enabled"
        },
        %{
          name: "Personnel",
          type: :link_row,
          target: :personnel,
          description: "Linked Personnel record (org directory)"
        }
      ]
    }
  end

  @impl true
  def view_specs(_sub_patterns) do
    %{
      app_users: [
        %{name: "All Users", type: :grid},
        %{
          name: "Active Users",
          type: :grid,
          filters: [%{field: "Active", op: :equal, value: true}]
        },
        %{name: "By Role", type: :grid, group_by: "Role"}
      ]
    }
  end
end
