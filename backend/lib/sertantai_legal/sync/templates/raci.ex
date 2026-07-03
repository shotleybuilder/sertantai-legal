defmodule SertantaiLegal.Sync.Templates.RACI do
  @moduledoc """
  RACI template — responsibility matrix per law or provision.

  Maps fractalaw's Hohfeldian actor positions to the customer's
  organisational roles:

  - `active` → pre-populates Responsible/Accountable columns
  - `counterparty` → pre-populates Informed column
  - `beneficiary` → pre-populates Informed column

  The customer then assigns their own people to each role.

  Assessment grain sub-pattern controls granularity:
  - `:provision` (default) — one RACI row per LAT provision
  - `:law` — one RACI row per LRT law
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @impl true
  def id, do: :raci

  @impl true
  def name, do: "RACI — Responsibility Matrix"

  @impl true
  def requires, do: [:foundation]

  @impl true
  def tables, do: [:raci]

  @impl true
  def field_specs(sp) do
    %{
      raci:
        link_fields(sp.assessment_grain) ++
          [
            %{
              name: "Actor_Label",
              type: :text,
              description: "Actor from law (e.g., Org: Employer)"
            },
            %{
              name: "Actor_Position",
              type: :single_select,
              options: ["active", "counterparty", "beneficiary", "mentioned"],
              description: "Hohfeldian position from fractalaw"
            }
          ] ++
          role_fields(sp.people)
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      raci: [
        %{name: "All RACI", type: :grid},
        %{name: "By Actor Position", type: :grid, group_by: "Actor_Position"},
        %{name: "RACI Board", type: :kanban, stack_by: "Actor_Position"}
      ]
    }
  end

  defp link_fields(:provision) do
    [
      %{name: "Provision", type: :link_row, target: :lat, description: "Which provision"},
      %{name: "Law", type: :lookup, target: :lat, target_field: "Parent Law"}
    ]
  end

  defp link_fields(:law) do
    [
      %{name: "Law", type: :link_row, target: :lrt, description: "Which law"}
    ]
  end

  defp role_fields(:linked) do
    [
      %{
        name: "Responsible",
        type: :link_row,
        target: :personnel,
        description: "Who does the work"
      },
      %{
        name: "Accountable",
        type: :link_row,
        target: :personnel,
        description: "Who owns the outcome"
      },
      %{
        name: "Consulted",
        type: :link_row,
        target: :personnel,
        description: "Who provides input"
      },
      %{
        name: "Informed",
        type: :link_row,
        target: :personnel,
        description: "Who is kept informed"
      }
    ]
  end

  defp role_fields(:flat) do
    [
      %{name: "Responsible", type: :text, description: "Who does the work"},
      %{name: "Accountable", type: :text, description: "Who owns the outcome"},
      %{name: "Consulted", type: :text, description: "Who provides input"},
      %{name: "Informed", type: :text, description: "Who is kept informed"}
    ]
  end
end
