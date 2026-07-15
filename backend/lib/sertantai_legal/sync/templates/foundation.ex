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
  def requires, do: []

  @impl true
  def tables, do: [:lrt, :lat]

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
        %{name: "Year", type: :number, description: "Year of enactment"},
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
        %{name: "Significance_Score", type: :number, description: "Raw L-score"},
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
        %{name: "_source_id", type: :text, description: "Sync source identifier"}
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
        %{name: "Confidence", type: :number, description: "Classification confidence"},
        %{name: "Legal_Register", type: :link_row, target: :lrt, description: "Parent law"},
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
