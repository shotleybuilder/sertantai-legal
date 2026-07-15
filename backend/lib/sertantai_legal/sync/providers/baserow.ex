defmodule SertantaiLegal.Sync.Providers.Baserow do
  @moduledoc """
  Baserow sync provider — pushes LRT/LAT data to Baserow (SaaS or self-hosted).

  Delegates all Baserow API calls to `SertantaiLegal.Baserow.Client` and
  implements `SertantaiLegal.Sync.ProviderBehaviour` with domain-specific
  field specs and row formatters.

  Credentials stored in SyncConfiguration (AES-256 encrypted):
  - `email`: Baserow account email
  - `password`: Baserow account password

  Rows are batched at 200 with `?user_field_names=true`.
  """

  @behaviour SertantaiLegal.Sync.ProviderBehaviour

  require Logger

  alias SertantaiLegal.Baserow.Client

  # Values to filter out of holder data — parser artifacts, not real actors
  @holder_exclusions MapSet.new([": He"])

  @function_options ["Making", "Amending", "Revoking", "Commencing", "Enacting"]
  @significance_options ["HIGH", "MEDIUM", "LOW"]

  @status_options [
    "✔ In force",
    "⭕ Part Revocation / Repeal",
    "❌ Revoked / Repealed / Abolished"
  ]

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

  @family_options (SertantaiLegal.Scraper.Models.ehs_family() ++
                     SertantaiLegal.Scraper.Models.hr_family())
                  |> Enum.sort()

  @control_types ["Preventive", "Detective", "Corrective", "Directive"]
  @control_natures ["Manual", "Automated", "IT-dependent manual"]
  @control_domains ["Organisational", "People", "Physical", "Technical"]
  @control_statuses ["Active", "Under Review", "Planned", "Retired"]
  @control_tiers ["Corporate", "Jurisdiction", "Contract"]
  @control_frequencies [
    "Continuous",
    "Daily",
    "Weekly",
    "Monthly",
    "Quarterly",
    "Annual",
    "Ad-hoc"
  ]
  @info_distances ["Direct", "Adjacent", "Mediated", "Remote"]
  @blast_radii ["Local", "Area", "Site", "Enterprise"]
  @mapping_strengths ["Primary", "Supporting", "Ancillary"]
  @demand_modes ["Normal", "Abnormal", "Emergency"]
  @effectiveness ["Effective", "Ineffective", "Not Tested"]

  # Actor vocabulary loaded from ActorDictionary (Zenoh queryable + YAML snapshot).
  alias SertantaiLegal.Legal.ActorDictionary

  # ── ProviderBehaviour Implementation ─────────────────────────────

  @impl true
  defdelegate test_connection(config), to: Client

  @impl true
  defdelegate list_fields(config, table_key_or_id), to: Client

  @impl true
  def ensure_fields(config, table_key, field_specs) do
    with {:ok, existing} <- Client.list_fields(config, table_key),
         :ok <- Client.clean_default_fields(config, table_key, existing, field_specs) do
      # Re-fetch after cleanup
      {:ok, existing} = Client.list_fields(config, table_key)
      existing_by_name = Map.new(existing, &{&1["name"], &1})

      {missing, needs_update} =
        Enum.split_with(field_specs, fn spec ->
          not Map.has_key?(existing_by_name, spec.name)
        end)

      # Create missing fields
      with :ok <- Client.create_fields_sequentially(config, table_key, missing) do
        # Update existing select fields that have new options
        Client.update_select_options(config, existing_by_name, needs_update)
      end
    end
  end

  @impl true
  defdelegate batch_create(config, table_key, rows), to: Client

  @doc """
  Create rows with optional per-batch callback.

  If `on_batch` is provided, it's called with each batch's mappings immediately
  after that batch succeeds — ensuring mappings are saved even if a later batch fails.
  Signature: `on_batch.(batch_mappings)`
  """
  defdelegate batch_create(config, table_key, rows, on_batch), to: Client

  @impl true
  defdelegate batch_update(config, table_key, rows), to: Client

  @impl true
  defdelegate batch_delete(config, table_key, external_row_ids), to: Client

  @doc """
  Prepare a Baserow table for first sync: rename from default "Table" to
  a meaningful name, delete default empty rows, and remove default columns
  (Notes, Active, etc.) that Baserow creates automatically.

  Call this before `ensure_fields` on first sync. Idempotent — skips
  rename if already named correctly, skips cleanup if no default fields.
  """
  defdelegate prepare_table(config, table_key, table_name), to: Client

  # ── Template Schema Operations ─────────────────────────────────
  # These implement the extended ProviderBehaviour for TemplateApplicator.
  # They work with universal field types from Templates.FieldTypes and
  # translate to Baserow-specific API calls.

  @impl true
  @doc "Provider capabilities for template feature gating."
  def capabilities do
    %{
      view_types: [:grid, :kanban, :calendar, :form, :gallery],
      field_level_permissions: true,
      webhooks: true,
      webhook_includes_old_values: false,
      webhook_includes_user_id: false,
      batch_size: 200
    }
  end

  @impl true
  @doc "Create a new table in the Baserow database. Returns the table ID."
  defdelegate create_table(config, name), to: Client

  @doc """
  Clean up Baserow default columns after table creation.

  Baserow auto-creates Name (primary, can't delete), Notes, and Active on
  every new table. This function:
  1. Deletes the Notes column (unwanted)
  2. Renames/updates the primary Name field to match the template's primary field
  3. Deletes Active if the template doesn't define one

  `field_specs` is the list of template field specs for this table.
  """
  defdelegate cleanup_table_defaults(config, table_id, field_specs), to: Client

  @doc """
  Convert the primary field to a formula after all other fields are created.
  Only needed when the template's primary field is type :formula.
  """
  defdelegate finalize_primary_formula(config, table_id, field_specs), to: Client

  @doc "Update an existing Baserow field by ID."
  defdelegate update_field(config, field_id, updates), to: Client

  @impl true
  @doc """
  Create a field on a Baserow table from a universal field spec.

  Translates universal types (`:text`, `:single_select`, `:link_row`, etc.)
  to Baserow API parameters.
  """
  defdelegate create_field(config, table_id, field_spec), to: Client

  @impl true
  @doc "Create a view on a Baserow table from a universal view spec."
  defdelegate create_view(config, table_id, view_spec), to: Client

  @impl true
  @doc "Register a webhook on a Baserow table."
  defdelegate create_webhook(config, table_id, webhook_spec), to: Client

  @doc """
  Parse a Baserow webhook payload into a common event struct.

  Baserow sends: `%{"table_id" => ..., "event_type" => "rows.updated", "items" => [...]}`
  """
  defdelegate parse_webhook_event(payload), to: Client

  @doc """
  Authenticate with Baserow and return config with JWT attached.

  Credentials must contain `email` and `password`. The returned config
  has `jwt` set, which `auth_header/1` uses for all subsequent calls.
  """
  defdelegate authenticate(config), to: Client

  @doc """
  Re-authenticate if JWT has expired. Called by Engine on 401 errors.
  Updates the stored config with a fresh JWT.
  """
  defdelegate refresh_auth(config), to: Client

  # ── Field Spec Helpers ────────────────────────────────────────────

  @doc """
  Returns Baserow field specs for LRT columns at the given field tier.

  For standard/full tiers, pass `rows` to extract multi-select options
  from the actual data (holder vocabularies vary across laws).
  """
  def lrt_field_specs(field_tier) do
    essential_fields() ++ tier_fields(field_tier)
  end

  @doc """
  Returns Baserow field specs for the LAT table.
  Includes a link_row field back to the LRT table.
  """
  def lat_field_specs(lrt_table_id) do
    [
      Client.multi_select_spec("Type", drrp_type_options()),
      Client.multi_select_spec("Duty Type", duty_sub_type_options()),
      Client.multi_select_spec("Regulated Actors", regulated_actor_options()),
      %{name: "Provision Text", type: "long_text"},
      %{name: "Provision", type: "text"},
      # Significance (provision-level)
      Client.single_select_spec("Significance", @significance_options),
      Client.single_select_spec("Gravity", @significance_options),
      Client.single_select_spec("Scope: Duty Bearer", @significance_options),
      Client.single_select_spec("Strength", @significance_options),
      %{name: "Confidence", type: "number", opts: %{"number_decimal_places" => 2}},
      %{name: "_source_id", type: "text"},
      %{name: "Parent Law", type: "link_row", opts: %{"link_row_table_id" => lrt_table_id}}
    ]
  end

  @doc """
  Validate that all holder values in the rows are in the actor dictionary.
  Returns `:ok` or `{:error, unknown_values}`. Call before sync to
  catch taxonomy drift from fractalaw early.
  """
  def validate_holder_vocabulary(rows) do
    known = MapSet.new(holder_options())

    unknown =
      rows
      |> Enum.flat_map(fn row ->
        extract_holder_list(row.duty_holder) ++
          extract_holder_list(row.power_holder) ++
          extract_holder_list(row.rights_holder)
      end)
      |> Enum.uniq()
      |> Enum.reject(&MapSet.member?(known, &1))
      |> Enum.sort()

    case unknown do
      [] -> :ok
      vals -> {:error, vals}
    end
  end

  # ── Controls field specs and formatting ─────────────────────────

  @doc """
  Field specs for the Controls Baserow table.

  Combines AI-generated fields (populated by sync from Postgres) with
  customer-set fields (created empty for manual population in Baserow).
  """
  def controls_field_specs(lrt_table_id) do
    [
      # AI-generated fields — names match template (underscores)
      %{name: "Title", type: "text"},
      %{name: "Description", type: "long_text"},
      %{name: "What_It_Checks", type: "long_text"},
      Client.single_select_spec("Control_Type", @control_types),
      Client.single_select_spec("Nature", @control_natures),
      Client.single_select_spec("Domain", @control_domains),
      Client.single_select_spec("Frequency", @control_frequencies),
      Client.single_select_spec("Info_Distance", @info_distances),
      Client.single_select_spec("Blast_Radius", @blast_radii),
      %{name: "Expected_Touch_Frequency", type: "text"},
      Client.single_select_spec("Mapping_Strength", @mapping_strengths),
      %{name: "Load_Bearing_Judgement", type: "long_text"},
      %{name: "Evidence_Type_A", type: "long_text"},
      %{name: "Evidence_Type_B", type: "long_text"},
      %{name: "Honest_Limit", type: "long_text"},
      Client.single_select_spec("Status", @control_statuses),
      Client.single_select_spec("Tier", @control_tiers),
      %{name: "Is_Predicate", type: "boolean"},
      %{name: "Legal_Register", type: "link_row", opts: %{"link_row_table_id" => lrt_table_id}},
      # Customer-set fields (created empty)
      %{name: "Owner", type: "text"},
      %{name: "External_Ref", type: "url"},
      Client.single_select_spec("Demand_Mode", @demand_modes),
      Client.single_select_spec("Design_Effectiveness", @effectiveness),
      Client.single_select_spec("Operating_Effectiveness", @effectiveness),
      %{name: "Last_Verified", type: "date"},
      %{name: "Notes", type: "long_text"},
      # System
      %{name: "_source_id", type: "text"}
    ]
  end

  @doc """
  Format a Control Ash resource into a Baserow row map.

  `lrt_external_row_id` is the Baserow row ID of the parent law in the
  Legal Register table (for the Parent Law link_row field).
  """
  def format_control_row(control, lrt_name) do
    source_id = "#{control.law_name}:#{control.control_id}"

    row = %{
      "Name" => source_id,
      "_source_id" => source_id,
      "Title" => control.title,
      "Description" => control.description,
      "What_It_Checks" => control.what_it_checks,
      "Control_Type" => control.control_type,
      "Nature" => control.nature,
      "Domain" => control.domain,
      "Frequency" => control.frequency,
      "Info_Distance" => control.info_distance,
      "Blast_Radius" => control.blast_radius,
      "Expected_Touch_Frequency" => control.expected_touch_frequency,
      "Mapping_Strength" => control.mapping_strength,
      "Load_Bearing_Judgement" => control.load_bearing_judgement,
      "Evidence_Type_A" => control.evidence_type_a,
      "Evidence_Type_B" => control.evidence_type_b,
      "Honest_Limit" => control.honest_limit,
      "Status" => control.status,
      "Tier" => control.tier,
      "Is_Predicate" => control.is_predicate
    }

    if lrt_name do
      Map.put(row, "Legal_Register", lrt_name)
    else
      row
    end
  end

  @doc """
  Field specs for the Control Mappings Baserow table.
  """
  def control_mappings_field_specs(controls_table_id, lat_table_id, lrt_table_id \\ nil) do
    specs = [
      %{
        name: "Controls",
        type: "link_row",
        opts: %{"link_row_table_id" => controls_table_id}
      },
      Client.single_select_spec("Strength", @mapping_strengths),
      %{name: "Short_Ref", type: "text"},
      %{name: "_source_id", type: "text"}
    ]

    specs =
      if lrt_table_id do
        specs ++
          [
            %{
              name: "Legal_Register",
              type: "link_row",
              opts: %{"link_row_table_id" => lrt_table_id}
            }
          ]
      else
        specs
      end

    if lat_table_id do
      specs ++
        [
          %{
            name: "Duties",
            type: "link_row",
            opts: %{"link_row_table_id" => lat_table_id}
          }
        ]
    else
      specs
    end
  end

  @doc """
  Format a ControlMapping Ash resource into a Baserow row map.

  All link_row fields use text values — Baserow resolves by matching
  the target table's primary field. No row ID tracking needed.
  """
  def format_control_mapping_row(mapping, control_name, duties_name, lrt_name \\ nil) do
    source_id = "#{mapping.control_id}:#{mapping.section_id}"

    row = %{
      "Name" => source_id,
      "_source_id" => source_id,
      "Strength" => mapping.mapping_strength,
      "Short_Ref" => mapping.short_ref
    }

    row = if control_name, do: Map.put(row, "Controls", control_name), else: row
    row = if lrt_name, do: Map.put(row, "Legal_Register", lrt_name), else: row
    if duties_name, do: Map.put(row, "Duties", duties_name), else: row
  end

  # ── Row Formatting ────────────────────────────────────────────────

  @doc """
  Formats a LegalRegister record into a Baserow row map at the given field tier.
  Uses user_field_names so keys are human-readable.
  """
  def format_lrt_row(lrt, field_tier) do
    essential = %{
      "_source_id" => format_uuid(lrt.id),
      "Name" => lrt.name,
      "Title" => lrt.title_en,
      "Family" => lrt.family,
      "Year" => lrt.year,
      "Number" => lrt.number,
      "Type" => lrt.type_desc,
      "Status" => lrt.live,
      "Geographic_Extent" => lrt.geo_extent,
      "Legislation_URL" => lrt.source_url,
      "Significance" => lrt.significance_rating,
      "Significance_Score" => round_score(lrt.significance_score)
    }

    essential
    |> maybe_add_standard(lrt, field_tier)
    |> maybe_add_full(lrt, field_tier)
  end

  @doc """
  Formats a LAT record into a Baserow row map.
  `lrt_external_row_id` is the Baserow row ID of the parent LRT record (for link_row).
  """
  def format_lat_row(lat, lrt_name) do
    row = %{
      "Name" => lat.section_id,
      "_source_id" => lat.section_id,
      "Type" => lat.drrp_types || [],
      "Duty_Type" => lat.duty_sub_type || [],
      "Regulated_Actors" => extract_active_actors(lat),
      "Provision_Text" => lat.text,
      "Provision" => lat.provision,
      "Significance" => lat[:significance_overall],
      "Gravity" => lat[:significance_gravity],
      "Scope_Duty_Bearer" => lat[:significance_scope_duty_bearer],
      "Strength" => lat[:significance_strength],
      "Confidence" => round_float(lat[:significance_confidence], 2)
    }

    if lrt_name, do: Map.put(row, "Legal_Register", lrt_name), else: row
  end

  # Raw binary UUIDs from string-table queries need casting to string format
  @doc false
  def format_uuid(<<_::128>> = raw), do: Ecto.UUID.load!(raw)
  def format_uuid(uuid) when is_binary(uuid), do: uuid
  def format_uuid(nil), do: nil

  # ── Private: Essential / Tier Field Specs ────────────────────────

  defp essential_fields do
    [
      %{name: "Title", type: "long_text"},
      Client.single_select_spec("Family", @family_options),
      %{name: "Year", type: "number", opts: %{"number_decimal_places" => 0}},
      %{name: "Number", type: "text"},
      Client.single_select_spec("Type", type_desc_options()),
      Client.single_select_spec("Status", @status_options),
      Client.single_select_spec("Geographic Extent", @geo_extent_options),
      %{name: "Legislation URL", type: "url"},
      # Significance (law-level — rating + score only; counts are Baserow Rollups)
      Client.single_select_spec("Significance", @significance_options),
      %{name: "Significance Score", type: "number", opts: %{"number_decimal_places" => 1}},
      %{name: "_source_id", type: "text"}
    ]
  end

  defp tier_fields(:essential), do: []

  defp tier_fields(:standard) do
    [
      Client.multi_select_spec("Function", @function_options),
      Client.multi_select_spec("Duty Type", duty_type_options()),
      Client.multi_select_spec("Purpose", purpose_options()),
      Client.multi_select_spec("Duty Holder", holder_options()),
      Client.multi_select_spec("Power Holder", holder_options()),
      Client.multi_select_spec("Rights Holder", holder_options()),
      Client.multi_select_spec("Domain", domain_options()),
      Client.multi_select_spec("Geographic Region", geo_region_options()),
      %{name: "Fitness Entities", type: "long_text"}
    ]
  end

  defp tier_fields(:full) do
    tier_fields(:standard) ++
      [
        %{name: "POPIMAR", type: "long_text"},
        %{name: "SI Code", type: "long_text"},
        %{name: "Description", type: "long_text"},
        %{name: "Role", type: "text"},
        %{name: "Amending", type: "long_text"},
        %{name: "Amended By", type: "long_text"},
        %{name: "Rescinding", type: "long_text"},
        %{name: "Rescinded By", type: "long_text"},
        %{name: "Date", type: "date"},
        %{name: "Made Date", type: "date"},
        %{name: "Enactment Date", type: "date"},
        %{name: "Coming Into Force Date", type: "date"},
        %{name: "Latest Amendment Date", type: "date"}
      ]
  end

  # ── Private: Dynamic Option Queries ──────────────────────────────

  defp holder_options, do: ActorDictionary.canonical_labels()

  defp duty_type_options, do: distinct_jsonb_values("duty_type")

  defp drrp_type_options do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT unnest(drrp_types) as val FROM legal_articles WHERE drrp_types IS NOT NULL ORDER BY val"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> ["Duty", "Responsibility", "Power", "Right", "Rule"]
    end
  end

  defp duty_sub_type_options do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT duty_sub_type FROM legal_articles WHERE duty_sub_type IS NOT NULL AND duty_sub_type != '' ORDER BY duty_sub_type"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> []
    end
  end

  defp domain_options, do: distinct_array_values("domain")
  defp geo_region_options, do: distinct_array_values("geo_region")
  defp purpose_options, do: distinct_jsonb_values("purpose")
  defp type_desc_options, do: distinct_values("type_desc")

  defp regulated_actor_options do
    # Union of dictionary labels + actual active actor labels from LAT data
    dict_labels = holder_options()

    data_labels =
      case SertantaiLegal.Repo.query(
             "SELECT DISTINCT a->>'label' FROM legal_articles la, unnest(la.actors) a WHERE a->>'position' = 'active' AND a->>'label' IS NOT NULL AND a->>'label_source' = 'canonical' ORDER BY 1"
           ) do
        {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
        _ -> []
      end

    (dict_labels ++ data_labels) |> Enum.uniq() |> Enum.sort()
  end

  defp distinct_array_values(column) do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT val FROM (SELECT unnest(#{column}) as val FROM uk_lrt WHERE #{column} IS NOT NULL) sub WHERE val IS NOT NULL AND val != '' ORDER BY val"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> []
    end
  end

  defp distinct_values(column) do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT #{column} FROM uk_lrt WHERE #{column} IS NOT NULL AND #{column} != '' ORDER BY #{column}"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> []
    end
  end

  defp distinct_jsonb_values(column) do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT val FROM (SELECT jsonb_array_elements_text(#{column}->'values') as val FROM uk_lrt WHERE #{column} IS NOT NULL) sub WHERE val IS NOT NULL ORDER BY val"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> []
    end
  end

  # ── Private: Row Formatting Helpers ──────────────────────────────

  defp maybe_add_standard(row, _lrt, :essential), do: row

  defp maybe_add_standard(row, lrt, _tier) do
    Map.merge(row, %{
      "Function" => format_function(lrt.function),
      "Duty_Type" => extract_values_list(lrt.duty_type),
      "Purpose" => extract_values_list(lrt.purpose),
      "Duty_Holder" => extract_holder_list(lrt.duty_holder),
      "Power_Holder" => extract_holder_list(lrt.power_holder),
      "Rights_Holder" => extract_holder_list(lrt.rights_holder),
      "Domain" => lrt.domain || [],
      "Geographic_Region" => lrt.geo_region || [],
      "Fitness_Entities" => join_array(lrt.fitness_entities)
    })
  end

  defp maybe_add_full(row, _lrt, tier) when tier in [:essential, :standard], do: row

  defp maybe_add_full(row, lrt, :full) do
    Map.merge(row, %{
      "POPIMAR" => extract_values(lrt.popimar),
      "SI_Code" => extract_values(lrt.si_code),
      "Description" => lrt.md_description,
      "Role" => join_array(lrt.role),
      "Amending" => join_array(lrt.amending),
      "Amended_By" => join_array(lrt.amended_by),
      "Rescinding" => join_array(lrt.rescinding),
      "Rescinded_By" => join_array(lrt.rescinded_by),
      "Date" => format_date(lrt.md_date),
      "Made_Date" => format_date(lrt.md_made_date),
      "Enactment_Date" => format_date(lrt.md_enactment_date),
      "Coming_Into_Force_Date" => format_date(lrt.md_coming_into_force_date),
      "Latest_Amendment_Date" => format_date(lrt.latest_amend_date)
    })
  end

  # Function map {"Making": true, "Amending": true} → ["Making", "Amending"]
  # Baserow multiple_select expects a list of option value strings
  defp format_function(nil), do: []

  defp format_function(func) when is_map(func) do
    func
    |> Enum.filter(fn {_k, v} -> v == true end)
    |> Enum.map(fn {k, _} -> to_string(k) end)
    |> Enum.filter(&(&1 in @function_options))
  end

  defp format_function(_), do: []

  # Extract active actor labels from the actors struct column.
  # Active = position is "active" (duty/responsibility/power holders).
  # Falls back to deprecated governed_actors flat column if actors is nil.
  defp extract_active_actors(%{actors: actors}) when is_list(actors) and actors != [] do
    actors
    |> Enum.filter(fn a ->
      pos = a["position"] || a[:position]
      source = a["label_source"] || a[:label_source]
      pos in ["active"] and source != "invented"
    end)
    |> Enum.map(fn a -> a["label"] || a[:label] end)
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&MapSet.member?(@holder_exclusions, &1))
    |> Enum.uniq()
  end

  defp extract_active_actors(%{governed_actors: ga}) when is_list(ga), do: ga
  defp extract_active_actors(_), do: []

  # Extract holder values, filtering out known artifacts and unknown labels.
  # Unknown labels (invented by fractalaw LLM, not in actor dictionary) are
  # excluded to avoid Baserow select option validation errors.
  defp extract_holder_list(field) do
    known = MapSet.new(holder_options())

    extract_values_list(field)
    |> Enum.reject(&MapSet.member?(@holder_exclusions, &1))
    |> Enum.filter(&MapSet.member?(known, &1))
  end

  # Extract values from JSONB fields as a list (for multiple_select columns)
  defp extract_values_list(nil), do: []
  defp extract_values_list(%{"values" => values}) when is_list(values), do: values

  defp extract_values_list(map) when is_map(map) do
    map
    |> Enum.filter(fn {_k, v} -> v == true end)
    |> Enum.map(fn {k, _} -> to_string(k) end)
  end

  defp extract_values_list(list) when is_list(list), do: list
  defp extract_values_list(_), do: []

  # Extract values from JSONB fields into comma-separated text.
  # Handles multiple storage formats:
  #   {"values": ["a", "b"]}           → "a, b"
  #   {"a": true, "b": true, "c": false} → "a, b"  (boolean-map, like function)
  #   ["a", "b"]                       → "a, b"
  defp extract_values(nil), do: nil
  defp extract_values(%{"values" => values}) when is_list(values), do: Enum.join(values, ", ")

  defp extract_values(map) when is_map(map) do
    # Boolean-map format: keys with truthy values
    map
    |> Enum.filter(fn {_k, v} -> v == true end)
    |> Enum.map(fn {k, _} -> to_string(k) end)
    |> case do
      [] -> nil
      vals -> Enum.join(vals, ", ")
    end
  end

  defp extract_values(list) when is_list(list), do: Enum.join(list, ", ")
  defp extract_values(other), do: to_string(other)

  defp round_score(nil), do: nil
  defp round_score(score) when is_float(score), do: Float.round(score, 1)
  defp round_score(score), do: score

  defp round_float(nil, _), do: nil
  defp round_float(val, decimals) when is_float(val), do: Float.round(val, decimals)
  defp round_float(val, _), do: val

  defp join_array(nil), do: nil
  defp join_array(list) when is_list(list), do: Enum.join(list, ", ")
  defp join_array(other), do: to_string(other)

  defp format_date(nil), do: nil
  defp format_date(%Date{} = d), do: Date.to_iso8601(d)
  defp format_date(other), do: to_string(other)
end
