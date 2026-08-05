defmodule SertantaiLegal.Sync.Templates.Foundation do
  @moduledoc """
  Foundation template — Legal Register (LRT) + Duties (LAT).

  Defines the complete schema for both tables. Data is synced by Engine.run.
  Multi-select option values are static defaults — the sync engine can
  add new values dynamically via update_select_options on each run.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @family_options (SertantaiLegal.Scraper.Models.ehs_family() ++
                     SertantaiLegal.Scraper.Models.hr_family())
                  |> Enum.sort()

  @status_options [
    "✔ In force",
    "⭕ Part Revocation / Repeal",
    "❌ Revoked / Repealed / Abolished"
  ]

  @function_options ["Making", "Amending", "Revoking", "Commencing", "Enacting"]
  @significance_options ["HIGH", "MEDIUM", "LOW"]

  @geo_extent_options [
    "E",
    "E+S",
    "E+W",
    "E+W+NI",
    "E+W+S",
    "E+W+S+NI",
    "GB",
    "NI",
    "S",
    "UK",
    "W"
  ]

  @drrp_options ["Obligation", "Right", "Power", "Liberty", "Immunity"]

  @impl true
  def id, do: :foundation

  @impl true
  def name, do: "Foundation — Legal Register + Provisions"

  @impl true
  def requires, do: [:customers, :hierarchy]

  @impl true
  def tables, do: [:lrt, :lat, :actor_tuples]

  @impl true
  def field_specs(_sub_patterns) do
    %{
      lrt: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Law name (e.g. UK_uksi_1997_1713)"
        },
        %{name: "Title", type: :long_text, description: "Full title of the legislation"},
        %{
          name: "Family",
          type: :single_select,
          options: @family_options,
          description: "Primary classification"
        },
        %{
          name: "Year",
          type: :number,
          opts: %{"number_decimal_places" => 0},
          description: "Year of enactment"
        },
        %{name: "Number", type: :text, description: "Legislation number"},
        %{
          name: "Type",
          type: :single_select,
          options: [],
          description: "Type description (e.g. UK Public General Acts)"
        },
        %{
          name: "Status",
          type: :single_select,
          options: @status_options,
          description: "Enforcement status"
        },
        %{
          name: "Geographic_Extent",
          type: :single_select,
          options: @geo_extent_options,
          description: "Geographic scope"
        },
        %{name: "Legislation_URL", type: :url, description: "Link to legislation.gov.uk"},
        %{
          name: "Significance",
          type: :single_select,
          options: @significance_options,
          description: "Law-level significance rating"
        },
        %{
          name: "Significance_Score",
          type: :number,
          opts: %{"number_decimal_places" => 1},
          description: "Raw L-score"
        },
        %{
          name: "Function",
          type: :multi_select,
          options: @function_options,
          description: "Making, Amending, Revoking, etc."
        },
        %{
          name: "Duty_Holder",
          type: :multi_select,
          options: [],
          description: "Entities with duties"
        },
        %{
          name: "Power_Holder",
          type: :multi_select,
          options: [],
          description: "Entities with powers"
        },
        %{
          name: "Rights_Holder",
          type: :multi_select,
          options: [],
          description: "Entities with rights"
        },
        %{name: "Domain", type: :multi_select, options: [], description: "Regulatory domain(s)"},
        %{
          name: "Geographic_Region",
          type: :multi_select,
          options: [],
          description: "Regions covered"
        },
        %{name: "Duty_Type", type: :multi_select, options: [], description: "DRRP duty types"},
        %{name: "Purpose", type: :multi_select, options: [], description: "Legal purposes"},
        %{name: "Fitness_Entities", type: :long_text, description: "Applicability entity tags"},
        %{
          name: "Customers",
          type: :link_row,
          target: :customers,
          description: "Demo customers this law applies to"
        },
        %{
          name: "Hierarchy",
          type: :link_row,
          target: :hierarchy,
          description: "Linked hierarchy nodes (sites, org units, etc.)"
        },
        %{
          name: "Hierarchy_Filter",
          type: :formula,
          expression: %{baserow: "concat(field('Hierarchy'), '')"},
          description: "Flattened hierarchy node names for App Builder filtering"
        },
        %{name: "_source_id", type: :text, description: "Sync source identifier"},
        # Cross-table lookups through Assessments reverse link
        %{
          name: "Assessment_Status",
          type: :lookup,
          target: "Assessments",
          target_field: "Compliance_Status",
          description: "Compliance status from linked Assessment"
        },
        %{
          name: "Actions_Open",
          type: :lookup,
          target: "Assessments",
          target_field: "Actions_Open",
          description: "Count of open actions (from Assessment rollup)"
        },
        %{
          name: "Actions_Overdue",
          type: :lookup,
          target: "Assessments",
          target_field: "Actions_Overdue",
          description: "Count of overdue actions (from Assessment rollup)"
        },
        %{
          name: "Actions_Done",
          type: :lookup,
          target: "Assessments",
          target_field: "Actions_Done",
          description: "Count of completed actions (from Assessment rollup)"
        }
      ],
      lat: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Section ID (e.g. UK_uksi_1997_1713:reg.3(1))"
        },
        %{
          name: "Type",
          type: :multi_select,
          options: @drrp_options,
          description: "DRRP classification"
        },
        %{name: "Duty_Type", type: :multi_select, options: [], description: "Duty sub-type"},
        %{
          name: "Regulated_Actors",
          type: :multi_select,
          options: [],
          description: "Governed actors"
        },
        %{name: "Provision_Text", type: :long_text, description: "Full provision text"},
        %{name: "Provision", type: :text, description: "Short section reference"},
        %{
          name: "Significance",
          type: :single_select,
          options: @significance_options,
          description: "Provision-level significance"
        },
        %{
          name: "Gravity",
          type: :single_select,
          options: @significance_options,
          description: "Gravity rating"
        },
        %{
          name: "Scope_Duty_Bearer",
          type: :single_select,
          options: @significance_options,
          description: "Scope: duty bearer"
        },
        %{
          name: "Strength",
          type: :single_select,
          options: @significance_options,
          description: "Strength rating"
        },
        %{
          name: "Confidence",
          type: :number,
          opts: %{"number_decimal_places" => 2},
          description: "Classification confidence"
        },
        %{name: "Legal_Register", type: :link_row, target: :lrt, description: "Parent law"},
        %{
          name: "Actors",
          type: :link_row,
          target: :actor_tuples,
          description: "Actor combinations for this provision"
        },
        %{name: "_source_id", type: :text, description: "Sync source identifier"}
      ],
      actor_tuples: [
        %{
          name: "Name",
          type: :text,
          primary: true,
          description: "Composite key: actor|position|drrp_type"
        },
        %{name: "Actor", type: :single_select, options: [], description: "Actor label"},
        %{
          name: "Position",
          type: :single_select,
          options: [],
          description: "Actor position (active/passive)"
        },
        %{
          name: "DRRP_Type",
          type: :single_select,
          options: [],
          description: "Obligation/Right/Power/etc."
        },
        %{name: "_source_id", type: :text, description: "Sync source identifier"}
      ]
    }
  end

  @impl true
  def view_specs(_sub_patterns) do
    %{
      lrt: [
        %{name: "All Laws", type: :grid},
        %{name: "By Family", type: :grid, group_by: "Family"},
        %{name: "By Status", type: :grid, group_by: "Status"}
      ],
      lat: [
        %{name: "All Duties", type: :grid},
        %{name: "By Type", type: :grid, group_by: "Type"},
        %{name: "By Significance", type: :grid, group_by: "Significance"}
      ]
    }
  end
end
