defmodule SertantaiLegal.Sync.Templates.OrgStructure do
  @moduledoc """
  Org Structure template — Sites and Divisions tables.

  Only applied when org_structure sub-pattern is `:site` or `:division_site`.
  Other templates can link Personnel/Assessments to Sites for scoped views.

  Sub-pattern behaviour:
  - `:flat` / `:department` — this template is not applied (no tables needed)
  - `:site` — creates Sites table only
  - `:division_site` — creates Divisions + Sites tables with hierarchy link
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @impl true
  def id, do: :org_structure

  @impl true
  def name, do: "Org Structure — Sites & Divisions"

  @impl true
  def requires, do: []

  @impl true
  def tables, do: [:sites, :divisions]

  @impl true
  def field_specs(sp) do
    case sp.org_structure do
      :site ->
        %{sites: site_fields()}

      :division_site ->
        %{
          divisions: division_fields(),
          sites:
            site_fields() ++
              [
                %{
                  name: "Division",
                  type: :link_row,
                  target: :divisions,
                  description: "Parent division"
                }
              ]
        }

      _ ->
        %{}
    end
  end

  @impl true
  def view_specs(sp) do
    case sp.org_structure do
      :site ->
        %{sites: [%{name: "All Sites", type: :grid}]}

      :division_site ->
        %{
          divisions: [%{name: "All Divisions", type: :grid}],
          sites: [
            %{name: "All Sites", type: :grid},
            %{name: "By Division", type: :grid, group_by: "Division"}
          ]
        }

      _ ->
        %{}
    end
  end

  defp site_fields do
    [
      %{name: "Site_Name", type: :text, description: "Site name"},
      %{name: "Address", type: :long_text, description: "Address"},
      %{
        name: "Region",
        type: :single_select,
        options: [],
        description: "Geographic region — customer populates"
      },
      %{name: "Active", type: :boolean, description: "Currently operational"}
    ]
  end

  defp division_fields do
    [
      %{name: "Division_Name", type: :text, description: "Division/business unit name"},
      %{name: "Code", type: :text, description: "Internal code"},
      %{name: "Active", type: :boolean, description: "Currently active"}
    ]
  end
end
