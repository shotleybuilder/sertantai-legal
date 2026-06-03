defmodule SertantaiLegal.Sync.Providers.Baserow do
  @moduledoc """
  Baserow sync provider — pushes LRT/LAT data to Baserow (SaaS or self-hosted).

  Uses JWT auth (email/password login) for full API access including schema
  management (field creation). The JWT is obtained at the start of each sync
  run and used for all operations.

  Credentials stored in SyncConfiguration (AES-256 encrypted):
  - `email`: Baserow account email
  - `password`: Baserow account password

  Rows are batched at 200 with `?user_field_names=true`.
  """

  @behaviour SertantaiLegal.Sync.ProviderBehaviour

  @batch_size 200

  # ── Public API ────────────────────────────────────────────────────

  @impl true
  def test_connection(config) do
    # Lightweight check: list fields on the LRT table
    case list_fields(config, :lrt) do
      {:ok, fields} ->
        {:ok, %{lrt_field_count: length(fields)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def list_fields(config, table_key) do
    table_id = table_id(config, table_key)

    case api_get(config, "/api/database/fields/table/#{table_id}/") do
      {:ok, %{status: 200, body: fields}} when is_list(fields) ->
        {:ok, fields}

      {:ok, %{status: status, body: body}} ->
        {:error, "Baserow list_fields returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Baserow list_fields failed: #{inspect(reason)}"}
    end
  end

  @impl true
  def ensure_fields(config, table_key, field_specs) do
    with {:ok, existing} <- list_fields(config, table_key),
         :ok <- clean_default_fields(config, table_key, existing, field_specs) do
      # Re-fetch after cleanup
      {:ok, existing} = list_fields(config, table_key)
      existing_names = MapSet.new(existing, & &1["name"])

      missing =
        Enum.reject(field_specs, fn spec ->
          MapSet.member?(existing_names, spec.name)
        end)

      create_fields_sequentially(config, table_key, missing)
    end
  end

  @impl true
  def batch_create(config, table_key, rows) when is_list(rows) do
    table_id = table_id(config, table_key)

    rows
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, []}, fn chunk, {:ok, acc} ->
      body = %{"items" => chunk}

      case api_post(
             config,
             "/api/database/rows/table/#{table_id}/batch/?user_field_names=true",
             body
           ) do
        {:ok, %{status: 200, body: %{"items" => created}}} ->
          mappings = extract_mappings(created)
          {:cont, {:ok, acc ++ mappings}}

        {:ok, %{status: status, body: body}} ->
          {:halt, {:error, "Baserow batch_create returned #{status}: #{inspect(body)}"}}

        {:error, reason} ->
          {:halt, {:error, "Baserow batch_create failed: #{inspect(reason)}"}}
      end
    end)
  end

  @impl true
  def batch_update(config, table_key, rows) when is_list(rows) do
    table_id = table_id(config, table_key)

    rows
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, count} ->
      body = %{"items" => chunk}

      case api_patch(
             config,
             "/api/database/rows/table/#{table_id}/batch/?user_field_names=true",
             body
           ) do
        {:ok, %{status: 200, body: %{"items" => updated}}} ->
          {:cont, {:ok, count + length(updated)}}

        {:ok, %{status: status, body: body}} ->
          {:halt, {:error, "Baserow batch_update returned #{status}: #{inspect(body)}"}}

        {:error, reason} ->
          {:halt, {:error, "Baserow batch_update failed: #{inspect(reason)}"}}
      end
    end)
  end

  @impl true
  def batch_delete(config, table_key, external_row_ids) when is_list(external_row_ids) do
    table_id = table_id(config, table_key)

    external_row_ids
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, 0}, fn chunk, {:ok, count} ->
      body = %{"items" => chunk}

      case api_post(config, "/api/database/rows/table/#{table_id}/batch-delete/", body) do
        {:ok, %{status: status}} when status in [200, 204] ->
          {:cont, {:ok, count + length(chunk)}}

        {:ok, %{status: status, body: body}} ->
          {:halt, {:error, "Baserow batch_delete returned #{status}: #{inspect(body)}"}}

        {:error, reason} ->
          {:halt, {:error, "Baserow batch_delete failed: #{inspect(reason)}"}}
      end
    end)
  end

  @doc """
  Prepare a Baserow table for first sync: rename from default "Table" to
  a meaningful name, delete default empty rows, and remove default columns
  (Notes, Active, etc.) that Baserow creates automatically.

  Call this before `ensure_fields` on first sync. Idempotent — skips
  rename if already named correctly, skips cleanup if no default fields.
  """
  def prepare_table(config, table_key, table_name) do
    with :ok <- rename_table(config, table_key, table_name),
         :ok <- clean_default_rows(config, table_key) do
      :ok
    end
  end

  # ── Internals ─────────────────────────────────────────────────────

  defp table_id(config, :lrt), do: config["lrt_table_id"] || config[:lrt_table_id]
  defp table_id(config, :lat), do: config["lat_table_id"] || config[:lat_table_id]

  defp base_url(config), do: String.trim_trailing(config["base_url"] || config[:base_url], "/")

  defp credentials(config), do: config["credentials"] || config[:credentials]

  @doc """
  Authenticate with Baserow and return config with JWT attached.

  Credentials must contain `email` and `password`. The returned config
  has `jwt` set, which `auth_header/1` uses for all subsequent calls.
  """
  def authenticate(config) do
    creds = credentials(config)
    email = creds["email"] || creds[:email]
    password = creds["password"] || creds[:password]

    url = base_url(config) <> "/api/user/token-auth/"

    case Req.post(url,
           headers: [{"Content-Type", "application/json"}],
           json: %{"email" => email, "password" => password},
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: %{"token" => jwt}}} ->
        {:ok, Map.put(config, "jwt", jwt)}

      {:ok, %{status: status, body: body}} ->
        {:error, "Baserow auth failed (#{status}): #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Baserow auth request failed: #{inspect(reason)}"}
    end
  end

  defp auth_header(config) do
    case config["jwt"] do
      jwt when is_binary(jwt) ->
        {"Authorization", "JWT #{jwt}"}

      _ ->
        # Fallback to database token for backwards compatibility
        creds = credentials(config)
        token = creds["database_token"] || creds[:database_token]
        {"Authorization", "Token #{token}"}
    end
  end

  defp api_get(config, path) do
    url = base_url(config) <> path

    Req.get(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      receive_timeout: 30_000
    )
  end

  defp api_post(config, path, body) do
    url = base_url(config) <> path

    Req.post(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      json: body,
      receive_timeout: 60_000
    )
  end

  defp api_patch(config, path, body) do
    url = base_url(config) <> path

    Req.patch(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      json: body,
      receive_timeout: 60_000
    )
  end

  defp api_delete(config, path) do
    url = base_url(config) <> path

    Req.delete(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      receive_timeout: 30_000
    )
  end

  # Delete default Baserow fields that aren't in our field specs.
  # Baserow creates "Notes" (long_text), "Active" (boolean), and "Name" (text)
  # by default. We keep any that match our specs, delete the rest.
  defp clean_default_fields(config, _table_key, existing_fields, desired_specs) do
    desired_names = MapSet.new(desired_specs, & &1.name)

    # Baserow's default fields — only delete these, never user-created fields
    default_names = MapSet.new(["Notes", "Active"])

    to_delete =
      existing_fields
      |> Enum.filter(fn f ->
        MapSet.member?(default_names, f["name"]) and not MapSet.member?(desired_names, f["name"])
      end)

    Enum.reduce_while(to_delete, :ok, fn field, :ok ->
      case api_delete(config, "/api/database/fields/#{field["id"]}/") do
        {:ok, %{status: status}} when status in [200, 204] ->
          {:cont, :ok}

        {:ok, %{status: s, body: b}} ->
          {:halt, {:error, "Delete field #{field["name"]}: #{s} #{inspect(b)}"}}

        {:error, reason} ->
          {:halt, {:error, "Delete field #{field["name"]}: #{inspect(reason)}"}}
      end
    end)
  end

  defp rename_table(config, table_key, desired_name) do
    table = table_id(config, table_key)

    case api_patch(config, "/api/database/tables/#{table}/", %{"name" => desired_name}) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s, body: b}} -> {:error, "Rename table: #{s} #{inspect(b)}"}
      {:error, reason} -> {:error, "Rename table: #{inspect(reason)}"}
    end
  end

  defp clean_default_rows(config, table_key) do
    table = table_id(config, table_key)

    # Fetch existing rows — if few and empty, delete them (default Baserow rows)
    case api_get(config, "/api/database/rows/table/#{table}/?size=200") do
      {:ok, %{status: 200, body: %{"count" => count, "results" => rows}}} when count <= 10 ->
        # Only delete rows that look like defaults (no meaningful data)
        default_ids =
          rows
          |> Enum.filter(fn row ->
            # Default rows have only system fields (id, order) + empty user fields
            user_values =
              row
              |> Map.drop(["id", "order"])
              |> Map.values()
              |> Enum.reject(&is_nil/1)
              |> Enum.reject(&(&1 == ""))
              |> Enum.reject(&(&1 == false))

            user_values == []
          end)
          |> Enum.map(& &1["id"])

        if default_ids != [] do
          api_post(config, "/api/database/rows/table/#{table}/batch-delete/", %{
            "items" => default_ids
          })
        end

        :ok

      # Table has real data or is empty — don't touch
      _ ->
        :ok
    end
  end

  defp create_fields_sequentially(_, _, []), do: :ok

  defp create_fields_sequentially(config, table_key, [spec | rest]) do
    table_id = table_id(config, table_key)

    body =
      %{"name" => spec.name, "type" => spec.type}
      |> Map.merge(spec[:opts] || %{})

    case api_post(config, "/api/database/fields/table/#{table_id}/", body) do
      {:ok, %{status: 200}} ->
        create_fields_sequentially(config, table_key, rest)

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "Failed to create field '#{spec.name}': #{status} #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, "Failed to create field '#{spec.name}': #{inspect(reason)}"}
    end
  end

  defp extract_mappings(created_rows) do
    Enum.map(created_rows, fn row ->
      %{
        external_row_id: row["id"],
        # The source_id is set by the caller who knows the mapping
        source_id: row["_source_id"]
      }
    end)
  end

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

  defp essential_fields do
    [
      %{name: "Name", type: "text"},
      %{name: "Title", type: "long_text"},
      %{name: "Family", type: "text"},
      %{name: "Year", type: "number", opts: %{"number_decimal_places" => 0}},
      %{name: "Number", type: "text"},
      %{name: "Type", type: "text"},
      %{name: "Status", type: "text"},
      %{name: "Geographic Extent", type: "text"},
      %{name: "Legislation URL", type: "url"},
      # Hidden source ID for mapping — always included
      %{name: "_source_id", type: "text"}
    ]
  end

  @function_options ["Making", "Amending", "Revoking", "Commencing", "Enacting"]
  @duty_type_options ["Duty", "Power", "Responsibility", "Right", "Rule"]
  @purpose_options [
    "Amendment",
    "Application+Scope",
    "Charge+Fee",
    "Defence+Appeal",
    "Enactment+Citation+Commencement",
    "Enforcement+Prosecution",
    "Exemption",
    "Extent",
    "Interpretation+Definition",
    "Liability",
    "Offence",
    "Power Conferred",
    "Process+Rule+Constraint+Condition",
    "Repeal+Revocation",
    "Transitional Arrangement"
  ]

  # Master holder vocabulary — sourced from ActorDefinitions taxonomy + observed data values.
  # Ordered by group: Government → Business → Person → Public → Specialist → Supply Chain → Other.
  # If fractalaw evolves the taxonomy, new values surface as a sync validation error
  # rather than silently failing. Fix by adding the new values here.
  # Values to filter out of holder data — parser artifacts, not real actors
  @holder_exclusions MapSet.new([": He"])

  @holder_options [
    # Government
    "Crown",
    "EU: Commission",
    "EU: Commission (inferred)",
    "Gvt: Agency",
    "Gvt: Agency (inferred)",
    "Gvt: Agency:",
    "Gvt: Agency: Environment Agency",
    "Gvt: Agency: Health and Safety Executive",
    "Gvt: Agency: Health and Safety Executive (inferred)",
    "Gvt: Agency: Health and Safety Executive for Northern Ireland",
    "Gvt: Agency: Maritime and Coastguard Agency",
    "Gvt: Agency: Natural Resources Body for Wales",
    "Gvt: Agency: OFCOM",
    "Gvt: Agency: Office for Nuclear Regulation",
    "Gvt: Agency: Office of Rail and Road",
    "Gvt: Agency: Oil and Gas Authority",
    "Gvt: Agency: Scottish Environment Protection Agency",
    "Gvt: Appropriate Person",
    "Gvt: Authority",
    "Gvt: Authority (inferred)",
    "Gvt: Authority: Energy",
    "Gvt: Authority: Enforcement",
    "Gvt: Authority: Fire and Rescue",
    "Gvt: Authority: Harbour",
    "Gvt: Authority: Licensing",
    "Gvt: Authority: Local",
    "Gvt: Authority: Local (inferred)",
    "Gvt: Authority: Market",
    "Gvt: Authority: Planning",
    "Gvt: Authority: Planning (inferred)",
    "Gvt: Authority: Public",
    "Gvt: Authority: Traffic",
    "Gvt: Authority: Waste",
    "Gvt: Commissioners",
    "Gvt: Commissioners (inferred)",
    "Gvt: Devolved Admin",
    "Gvt: Devolved Admin:",
    "Gvt: Devolved Admin: National Assembly for Wales",
    "Gvt: Devolved Admin: Northern Ireland Assembly",
    "Gvt: Devolved Admin: Scottish Parliament",
    "Gvt: Emergency Services",
    "Gvt: Emergency Services: Police",
    "Gvt: Judiciary",
    "Gvt: Judiciary (inferred)",
    "Gvt: Minister",
    "Gvt: Minister (inferred)",
    "Gvt: Minister: Attorney General",
    "Gvt: Minister: Secretary of State for Defence",
    "Gvt: Minister: Secretary of State for Transport",
    "Gvt: Ministry",
    "Gvt: Ministry:",
    "Gvt: Ministry: Department of Enterprise, Trade and Investment",
    "Gvt: Ministry: Department of the Environment",
    "Gvt: Ministry: HMRC",
    "Gvt: Ministry: Ministry of Defence",
    "Gvt: Ministry: Treasury",
    "Gvt: Officer",
    "Gvt: Official",
    "HM Forces",
    # Business / Organisation
    "Operator",
    "Operator (inferred)",
    "Organisation",
    "Org: Company",
    "Org: Employer",
    "Org: Employer (inferred)",
    "Org: Investor",
    "Org: Landlord",
    "Org: Landlord (inferred)",
    "Org: Lessee",
    "Org: Occupier",
    "Org: Occupier (inferred)",
    "Org: Owner",
    "Org: Owner (inferred)",
    "Org: Partnership",
    # Person
    "Ind: Applicant",
    "Ind: Appointed Person",
    "Ind: Authorised Person",
    "Ind: Chair",
    "Ind: Competent Person",
    "Ind: Diver",
    "Ind: Duty Holder",
    "Ind: Duty Holder (inferred)",
    "Ind: Dutyholder",
    "Ind: Employee",
    "Ind: Employee (inferred)",
    "Ind: Holder",
    "Ind: Licence Holder",
    "Ind: Licensee",
    "Ind: Manager",
    "Ind: Manager (inferred)",
    "Ind: Person",
    "Ind: Person (inferred)",
    "Ind: Relevant Person",
    "Ind: Responsible Person",
    "Ind: Responsible Person (inferred)",
    "Ind: Self-employed Worker",
    "Ind: Suitable Person",
    "Ind: Supervisor",
    "Ind: Supervisor (inferred)",
    "Ind: User",
    "Ind: User (inferred)",
    "Ind: Worker",
    "Ind: Worker (inferred)",
    "Ind: Young Person",
    # Public
    "Public",
    "Public (inferred)",
    "Public: Parents",
    # Specialist
    "Spc: Advisor",
    "Spc: Assessor",
    "Spc: Body",
    "Spc: Employees' Representative",
    "Spc: Engineer",
    "Spc: Inspector",
    "Spc: Inspector (inferred)",
    "Spc: OH Advisor",
    "Spc: Representative",
    "Spc: Surveyor",
    "Spc: Technician",
    "Spc: Trade Union",
    # Supply Chain
    "SC: Agent",
    "SC: C: Constructor",
    "SC: C: Contractor",
    "SC: C: Designer",
    "SC: C: Designer (inferred)",
    "SC: C: Principal Contractor",
    "SC: C: Principal Designer",
    "SC: Client",
    "SC: Client (inferred)",
    "SC: Consumer",
    "SC: Customer",
    "SC: Dealer",
    "SC: Distributor",
    "SC: Domestic Client",
    "SC: Exporter",
    "SC: Generator",
    "SC: Importer",
    "SC: Importer (inferred)",
    "SC: Keeper",
    "SC: Manufacturer",
    "SC: Manufacturer (inferred)",
    "SC: Marketer",
    "SC: Producer",
    "SC: Retailer",
    "SC: Seller",
    "SC: Storer",
    "SC: Supplier",
    "SC: Supplier (inferred)",
    "SC: T&L: Carrier",
    "SC: T&L: Carrier (inferred)",
    "SC: T&L: Consignee",
    "SC: T&L: Consignor",
    "SC: T&L: Driver",
    "SC: T&L: Handler",
    # Service
    "Svc: Installer",
    "Svc: Installer (inferred)",
    "Svc: Maintainer",
    "Svc: Repairer",
    # Maritime
    "Maritime: crew",
    "Maritime: master",
    # Offshore
    "Offshore: Licensee",
    "Offshore: Licensee (inferred)",
    # Environment
    "Env: Disposer",
    "Env: Polluter",
    "Env: Recycler",
    "Env: Reuser",
    "Env: Treater"
  ]

  @doc """
  Validate that all holder values in the rows are in the master list.
  Returns `:ok` or `{:error, unknown_values}`. Call before sync to
  catch taxonomy drift from fractalaw early.
  """
  def validate_holder_vocabulary(rows) do
    known = MapSet.new(@holder_options)

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

  # ── LAT Field Specs ───────────────────────────────────────────────

  @drrp_type_options ["Duty", "Responsibility", "Power", "Right", "Rule"]
  @duty_sub_type_options [
    "Delegation",
    "Enabling",
    "Enforcement",
    "Fees",
    "GeneralDuty",
    "InformationDuty",
    "ParliamentaryReporting",
    "Prescriptive",
    "Prohibitive",
    "RiskAssessment",
    "SfairpDuty",
    "ThingObligation",
    "TrainingDuty"
  ]

  @doc """
  Returns Baserow field specs for the LAT table (duty-focused).
  Only provisions with Duty/Responsibility DRRP types are synced.
  """
  def lat_field_specs(lrt_table_id) do
    [
      %{name: "Duty Summary", type: "long_text"},
      multi_select_spec("Type", @drrp_type_options),
      multi_select_spec("Duty Type", @duty_sub_type_options),
      multi_select_spec("Regulated Actors", @holder_options),
      %{name: "Provision Text", type: "long_text"},
      %{name: "Law Name", type: "text"},
      %{name: "Provision", type: "text"},
      %{name: "Section Type", type: "text"},
      %{name: "_source_id", type: "text"},
      %{name: "Parent Law", type: "link_row", opts: %{"link_row_table_id" => lrt_table_id}}
    ]
  end

  # ── LRT Field Specs ──────────────────────────────────────────────

  defp tier_fields(:essential), do: []

  defp tier_fields(:standard) do
    [
      multi_select_spec("Function", @function_options),
      multi_select_spec("Duty Type", @duty_type_options),
      multi_select_spec("Purpose", @purpose_options),
      multi_select_spec("Duty Holder", @holder_options),
      multi_select_spec("Power Holder", @holder_options),
      multi_select_spec("Rights Holder", @holder_options),
      %{name: "Domain", type: "text"},
      %{name: "Geographic Region", type: "text"},
      %{name: "Making Classification", type: "text"},
      %{name: "Fitness Person", type: "text"},
      %{name: "Fitness Process", type: "text"},
      %{name: "Fitness Place", type: "text"},
      %{name: "Fitness Plant", type: "text"},
      %{name: "Fitness Sector", type: "text"}
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

  defp multi_select_spec(name, options) do
    %{
      name: name,
      type: "multiple_select",
      opts: %{
        "select_options" => Enum.map(options, &%{"value" => &1, "color" => "light-gray"})
      }
    }
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
      "Geographic Extent" => lrt.geo_extent,
      "Legislation URL" => lrt.leg_gov_uk_url
    }

    essential
    |> maybe_add_standard(lrt, field_tier)
    |> maybe_add_full(lrt, field_tier)
  end

  @doc """
  Formats a LAT record into a Baserow row map.
  `lrt_external_row_id` is the Baserow row ID of the parent LRT record (for link_row).
  """
  def format_lat_row(lat, lrt_external_row_id) do
    %{
      "Name" => lat.section_id,
      "_source_id" => lat.section_id,
      "Duty Summary" => lat.clause_refined,
      "Type" => lat.drrp_types || [],
      "Duty Type" => if(lat.duty_sub_type, do: [lat.duty_sub_type], else: []),
      "Regulated Actors" => extract_holder_list(lat.governed_actors),
      "Provision Text" => lat.text,
      "Law Name" => lat.law_name,
      "Provision" => lat.provision,
      "Section Type" => to_string(lat.section_type),
      "Language" => lat.language,
      "Parent Law" => [lrt_external_row_id]
    }
  end

  defp maybe_add_standard(row, _lrt, :essential), do: row

  defp maybe_add_standard(row, lrt, _tier) do
    Map.merge(row, %{
      "Function" => format_function(lrt.function),
      "Duty Type" => extract_values_list(lrt.duty_type),
      "Purpose" => extract_values_list(lrt.purpose),
      "Duty Holder" => extract_holder_list(lrt.duty_holder),
      "Power Holder" => extract_holder_list(lrt.power_holder),
      "Rights Holder" => extract_holder_list(lrt.rights_holder),
      "Domain" => join_array(lrt.domain),
      "Geographic Region" => join_array(lrt.geo_region),
      "Making Classification" => lrt.making_classification,
      "Fitness Person" => join_array(lrt.fitness_person),
      "Fitness Process" => join_array(lrt.fitness_process),
      "Fitness Place" => join_array(lrt.fitness_place),
      "Fitness Plant" => join_array(lrt.fitness_plant),
      "Fitness Sector" => join_array(lrt.fitness_sector)
    })
  end

  defp maybe_add_full(row, _lrt, tier) when tier in [:essential, :standard], do: row

  defp maybe_add_full(row, lrt, :full) do
    Map.merge(row, %{
      "POPIMAR" => extract_values(lrt.popimar),
      "SI Code" => extract_values(lrt.si_code),
      "Description" => lrt.md_description,
      "Role" => join_array(lrt.role),
      "Amending" => join_array(lrt.amending),
      "Amended By" => join_array(lrt.amended_by),
      "Rescinding" => join_array(lrt.rescinding),
      "Rescinded By" => join_array(lrt.rescinded_by),
      "Date" => format_date(lrt.md_date),
      "Made Date" => format_date(lrt.md_made_date),
      "Enactment Date" => format_date(lrt.md_enactment_date),
      "Coming Into Force Date" => format_date(lrt.md_coming_into_force_date),
      "Latest Amendment Date" => format_date(lrt.latest_amend_date)
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

  # Extract holder values, filtering out known artifacts
  defp extract_holder_list(field) do
    extract_values_list(field)
    |> Enum.reject(&MapSet.member?(@holder_exclusions, &1))
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

  defp join_array(nil), do: nil
  defp join_array(list) when is_list(list), do: Enum.join(list, ", ")
  defp join_array(other), do: to_string(other)

  defp format_date(nil), do: nil
  defp format_date(%Date{} = d), do: Date.to_iso8601(d)
  defp format_date(other), do: to_string(other)

  # Raw binary UUIDs from string-table queries need casting to string format
  defp format_uuid(<<_::128>> = raw), do: Ecto.UUID.load!(raw)
  defp format_uuid(uuid) when is_binary(uuid), do: uuid
  defp format_uuid(nil), do: nil
end
