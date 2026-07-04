defmodule SertantaiLegal.Sync.Templates.Hierarchy do
  @moduledoc """
  Hierarchy template — single adjacency-list table for all organisational hierarchies.

  Replaces the previous OrgStructure template (separate Sites + Divisions tables)
  with a flexible adjacency list. One table handles org, geo, finance, and reporting
  hierarchies at any depth via a self-referential Parent field.

  See `docs/BASEROW-CONTROLS-DESIGN.md` § Hierarchy Table for full design rationale.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @hierarchies ["org", "geo", "finance", "reporting"]

  @node_types [
    "Organisation",
    "Division",
    "Department",
    "Function",
    "Site",
    "Building",
    "Floor",
    "Region",
    "Country",
    "Cost Centre"
  ]

  @impl true
  def id, do: :hierarchy

  @impl true
  def name, do: "Hierarchy — Org, Geo & Finance Trees"

  @impl true
  def requires, do: []

  @impl true
  def tables, do: [:hierarchy]

  @impl true
  def field_specs(_sp) do
    %{
      hierarchy: [
        %{
          name: "Node",
          type: :formula,
          primary: true,
          expression: %{baserow: "concat(field('Type'), ': ', field('Name'))"},
          description: "Display: Type: Name"
        },
        %{
          name: "Name",
          type: :text,
          description: "Node name (e.g. 'Manchester', 'EHS Department')"
        },
        %{
          name: "Hierarchy",
          type: :single_select,
          options: @hierarchies,
          description: "Which hierarchy this node belongs to"
        },
        %{
          name: "Type",
          type: :single_select,
          options: @node_types,
          description: "Node type — customer may add options"
        },
        %{
          name: "Parent",
          type: :link_row,
          target: :hierarchy,
          description: "Parent node in the tree (empty = root)"
        },
        %{name: "Description", type: :long_text, description: "Notes about this node"}
      ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      hierarchy: [
        %{name: "All Nodes", type: :grid},
        %{
          name: "Org Structure",
          type: :grid,
          filters: [%{field: "Hierarchy", op: :equal, value: "org"}]
        },
        %{
          name: "Locations",
          type: :grid,
          filters: [%{field: "Hierarchy", op: :equal, value: "geo"}]
        },
        %{
          name: "Cost Centres",
          type: :grid,
          filters: [%{field: "Hierarchy", op: :equal, value: "finance"}]
        },
        %{
          name: "Top Level",
          type: :grid,
          filters: [%{field: "Parent", op: :empty, value: true}]
        },
        %{name: "By Type", type: :grid, group_by: "Type"}
      ]
    }
  end

  # No seed — customer populates their own org structure.
end
