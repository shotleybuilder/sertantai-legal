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
    with {:ok, existing} <- list_fields(config, table_key) do
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
      %{name: "Section ID", type: "text"},
      %{name: "Law Name", type: "text"},
      %{name: "Section Type", type: "text"},
      %{name: "Text", type: "long_text"},
      %{name: "Part", type: "text"},
      %{name: "Chapter", type: "text"},
      %{name: "Provision", type: "text"},
      %{name: "Paragraph", type: "text"},
      %{name: "Depth", type: "number", opts: %{"number_decimal_places" => 0}},
      %{name: "Position", type: "number", opts: %{"number_decimal_places" => 0}},
      %{name: "Language", type: "text"},
      %{name: "Parent Law", type: "link_row", opts: %{"link_row_table_id" => lrt_table_id}}
    ]
  end

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

  defp tier_fields(:essential), do: []

  defp tier_fields(:standard) do
    [
      %{name: "Function", type: "long_text"},
      %{name: "Duty Holder", type: "long_text"},
      %{name: "Power Holder", type: "long_text"},
      %{name: "Rights Holder", type: "long_text"},
      %{name: "Purpose", type: "long_text"},
      %{name: "Duty Type", type: "long_text"},
      %{name: "Domain", type: "text"},
      %{name: "Geographic Region", type: "text"},
      %{name: "Making Classification", type: "text"},
      %{name: "Is Making", type: "boolean"},
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
      "_source_id" => lat.section_id,
      "Section ID" => lat.section_id,
      "Law Name" => lat.law_name,
      "Section Type" => to_string(lat.section_type),
      "Text" => lat.text,
      "Part" => lat.part,
      "Chapter" => lat.chapter,
      "Provision" => lat.provision,
      "Paragraph" => lat.paragraph,
      "Depth" => lat.depth,
      "Position" => lat.position,
      "Language" => lat.language,
      "Parent Law" => [lrt_external_row_id]
    }
  end

  defp maybe_add_standard(row, _lrt, :essential), do: row

  defp maybe_add_standard(row, lrt, _tier) do
    Map.merge(row, %{
      "Function" => json_or_nil(lrt.function),
      "Duty Holder" => json_or_nil(lrt.duty_holder),
      "Power Holder" => json_or_nil(lrt.power_holder),
      "Rights Holder" => json_or_nil(lrt.rights_holder),
      "Purpose" => json_or_nil(lrt.purpose),
      "Duty Type" => json_or_nil(lrt.duty_type),
      "Domain" => join_array(lrt.domain),
      "Geographic Region" => join_array(lrt.geo_region),
      "Making Classification" => lrt.making_classification,
      "Making Review" => lrt.making_review,
      "Is Making" => lrt.is_making || false,
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
      "POPIMAR" => json_or_nil(lrt.popimar),
      "SI Code" => json_or_nil(lrt.si_code),
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

  defp json_or_nil(nil), do: nil
  defp json_or_nil(map) when is_map(map), do: Jason.encode!(map)
  defp json_or_nil(other), do: inspect(other)

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
