defmodule SertantaiLegal.Sync.Templates.Controls do
  @moduledoc """
  Controls template — L3 control register with Properties/Methods/Events/Distance ontology.

  Each control is a summary record sufficient for compliance reporting, plus an
  optional pointer to detailed operational documentation. Two link_row fields to the
  Hierarchy table provide organisational context (Org_Unit, Location).

  Sub-pattern support:
  - `people: :linked` — Owner links to Personnel table
  - `people: :flat` — Owner is a text field
  - `people: :workspace_member` — Owner is a Baserow Collaborators field
  - `people: :hybrid` — both Collaborators + link_row

  See `docs/BASEROW-CONTROLS-DESIGN.md` for full design rationale.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  # Properties
  @control_types ["Preventive", "Detective", "Corrective", "Directive"]
  @natures ["Manual", "Automated", "IT-dependent manual"]
  @domains ["Organisational", "People", "Physical", "Technical"]
  @statuses ["Active", "Under Review", "Planned", "Retired"]
  @tiers ["Corporate", "Jurisdiction", "Contract"]
  @effectiveness ["Effective", "Ineffective", "Not Tested"]

  # Methods
  @risk_methods ["Consequence", "Exposure", "Likelihood"]
  @blast_radii ["Local", "Area", "Site", "Enterprise"]

  # Events
  @frequencies ["Continuous", "Daily", "Weekly", "Monthly", "Quarterly", "Annual", "Ad-hoc"]
  @demand_modes ["Normal", "Abnormal", "Emergency"]

  # Distance
  @info_distances ["Direct", "Adjacent", "Mediated", "Remote"]

  @impl true
  def id, do: :controls

  @impl true
  def name, do: "Controls — L3 Control Register"

  @impl true
  def requires, do: [:personnel, :hierarchy]

  @impl true
  def tables, do: [:controls]

  @impl true
  def field_specs(sp) do
    %{
      controls:
        [
          # Primary — stable text identifier for API linking
          %{
            name: "Name",
            type: :text,
            primary: true,
            description: "Stable ID: law_name:control_id (e.g. UK_uksi_1997_1713:e75a4f8c-...)"
          },
          # Display formula (non-primary)
          %{
            name: "Control",
            type: :formula,
            expression: %{baserow: "concat(field('Control_Type'), ' — ', field('Title'))"},
            description: "Display: Control_Type — Title"
          },
          # Law link — enables filtering Controls by law from Legal Register
          %{
            name: "Legal_Register",
            type: :link_row,
            target: :lrt,
            description: "Parent law (for navigation from Legal Register)"
          },
          # Properties (static)
          %{
            name: "Title",
            type: :text,
            description: "Short name (e.g. 'Lone working risk assessment')"
          },
          %{
            name: "Description",
            type: :long_text,
            description: "Summary of how the control works — enough for compliance reporting"
          },
          %{
            name: "Control_Type",
            type: :single_select,
            options: @control_types,
            description: "Function: what the control does"
          },
          %{
            name: "Nature",
            type: :single_select,
            options: @natures,
            description: "How the control operates"
          },
          %{
            name: "Domain",
            type: :single_select,
            options: @domains,
            description: "ISO 27001:2022 category"
          }
        ] ++
          people_fields(sp.people) ++
          [
            %{
              name: "Status",
              type: :single_select,
              options: @statuses,
              description: "Lifecycle state"
            },
            %{
              name: "Tier",
              type: :single_select,
              options: @tiers,
              description: "Inheritance level: Corporate / Jurisdiction / Contract"
            },
            %{
              name: "External_Ref",
              type: :url,
              description: "Link to detailed procedure/policy in operational system"
            },
            %{
              name: "Design_Effectiveness",
              type: :single_select,
              options: @effectiveness,
              description: "As-designed adequacy"
            },
            %{
              name: "Operating_Effectiveness",
              type: :single_select,
              options: @effectiveness,
              description: "As-operated adequacy"
            },
            %{
              name: "Last_Verified",
              type: :date,
              description: "When effectiveness was last checked"
            },
            # Methods (how control acts on risk)
            %{
              name: "Risk_Method",
              type: :multi_select,
              options: @risk_methods,
              description: "Which risk dimensions this control acts on"
            },
            %{
              name: "Blast_Radius",
              type: :single_select,
              options: @blast_radii,
              description: "Scope of the control's effect"
            },
            # Events (demand regime)
            %{
              name: "Frequency",
              type: :single_select,
              options: @frequencies,
              description: "Normal demand rate (design operating frequency)"
            },
            %{
              name: "Demand_Mode",
              type: :single_select,
              options: @demand_modes,
              description: "Current operating mode"
            },
            # Organisational context (links to Hierarchy)
            %{
              name: "Org_Unit",
              type: :link_row,
              target: :hierarchy,
              description: "Organisational position (Division, Department, etc.)"
            },
            %{
              name: "Location",
              type: :link_row,
              target: :hierarchy,
              description: "Geographic position (Site, Building, etc.)"
            },
            # Distance (Westrum information distance)
            %{
              name: "Info_Distance",
              type: :single_select,
              options: @info_distances,
              description: "Westrum information distance: controller → controlled"
            },
            # Notes
            %{
              name: "Notes",
              type: :long_text,
              description: "Implementation notes, conditions, limitations"
            },
            # Coverage & scheduling (computed by fractalaw, written via API)
            %{
              name: "Coverage_Status",
              type: :single_select,
              options: [
                "No Artefact",
                "Artefact Only",
                "Judgement Current",
                "Judgement Stale",
                "Unknown"
              ],
              description: "Computed by fractalaw — not manually set"
            },
            %{
              name: "Recommended_Next_Due",
              type: :date,
              description: "Computed by fractalaw from control properties (read-only)"
            },
            %{
              name: "Scheduled_Next_Due",
              type: :date,
              description: "User-editable. Single source of truth for alerting."
            },
            %{
              name: "Next_Due_Override_Reason",
              type: :text,
              description: "Required if Scheduled differs from Recommended"
            }
          ]
    }
  end

  @impl true
  def view_specs(_sp) do
    %{
      controls: [
        %{name: "All Controls", type: :grid},
        %{name: "By Type", type: :grid, group_by: "Control_Type"},
        %{name: "By Owner", type: :grid, group_by: "Owner"},
        %{name: "By Status", type: :kanban, stack_by: "Status"},
        %{name: "By Domain", type: :grid, group_by: "Domain"},
        %{
          name: "Needing Verification",
          type: :grid,
          filters: [%{field: "Last_Verified", op: :empty, value: true}]
        }
      ]
    }
  end

  # No seed — controls are customer-specific, manually populated.

  # ── People sub-pattern field builders ────────────────────────────

  defp people_fields(:linked) do
    [
      %{
        name: "Owner",
        type: :link_row,
        target: :personnel,
        description: "Who is accountable for this control operating"
      }
    ]
  end

  defp people_fields(:workspace_member) do
    [
      %{
        name: "Owner",
        type: :workspace_member,
        description: "Who is accountable for this control operating"
      }
    ]
  end

  defp people_fields(:hybrid) do
    [
      %{
        name: "Owner",
        type: :workspace_member,
        description: "Control owner (Baserow user)"
      },
      %{
        name: "Responsible_Person",
        type: :link_row,
        target: :personnel,
        description: "Accountable person in org"
      }
    ]
  end

  defp people_fields(:flat) do
    [%{name: "Owner", type: :text, description: "Who is accountable for this control operating"}]
  end
end
