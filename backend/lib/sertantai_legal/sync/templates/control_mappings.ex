defmodule SertantaiLegal.Sync.Templates.ControlMappings do
  @moduledoc """
  Control Mappings template — the wiring diagram between obligations and controls.

  A lean join table with two-tier obligation linking:
  - Law field (link → LRT) — always populated, coarse mapping
  - Obligation field (link → LAT) — optional, provision-level for targeted controls

  Four fields plus the primary. No status (implied by Control + Law status), no
  justification (that's L7 governance), no audit trail (Baserow row history).

  See `docs/BASEROW-CONTROLS-DESIGN.md` § Control Mapping for full design rationale.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @strengths ["Primary", "Supporting", "Ancillary"]

  @impl true
  def id, do: :control_mappings

  @impl true
  def name, do: "Control Mappings — L3 Obligation↔Control Wiring"

  @impl true
  def requires, do: [:foundation, :controls]

  @impl true
  def tables, do: [:control_mappings]

  @impl true
  def field_specs(_sp) do
    %{
      control_mappings: [
        %{
          name: "Mapping",
          type: :formula,
          primary: true,
          expression: %{
            baserow:
              "if(field('Obligation') != '', concat(field('Obligation'), ' ↔ ', field('Control')), concat(field('Law'), ' ↔ ', field('Control')))"
          },
          description: "Display: Obligation ↔ Control (or Law ↔ Control for law-level mappings)"
        },
        %{
          name: "Law",
          type: :link_row,
          target: :lrt,
          description: "Law-level mapping (always populated)"
        },
        %{
          name: "Obligation",
          type: :link_row,
          target: :lat,
          description: "Provision-level mapping (empty for law-level mappings)"
        },
        %{
          name: "Control",
          type: :link_row,
          target: :controls,
          description: "Which control addresses this obligation"
        },
        %{
          name: "Strength",
          type: :single_select,
          options: @strengths,
          description:
            "Primary / Supporting / Ancillary — how strongly this control addresses the obligation"
        }
      ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      control_mappings: [
        %{name: "All Mappings", type: :grid},
        %{name: "By Control", type: :grid, group_by: "Control"},
        %{name: "By Law", type: :grid, group_by: "Law"},
        %{name: "By Strength", type: :grid, group_by: "Strength"}
      ]
    }
  end

  # No seed — mappings are customer-specific, built via AI-assisted or manual workflow.
end
