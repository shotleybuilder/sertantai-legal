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

  @managed_description "🚫 Managed by SertantAI — do not rename or delete"

  @behaviour SertantaiLegal.Sync.ProviderBehaviour

  require Logger

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
  def list_fields(config, table_key_or_id) do
    tid =
      if is_atom(table_key_or_id),
        do: table_id(config, table_key_or_id),
        else: table_key_or_id

    case api_get(config, "/api/database/fields/table/#{tid}/") do
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
      existing_by_name = Map.new(existing, &{&1["name"], &1})

      {missing, needs_update} =
        Enum.split_with(field_specs, fn spec ->
          not Map.has_key?(existing_by_name, spec.name)
        end)

      # Create missing fields
      with :ok <- create_fields_sequentially(config, table_key, missing) do
        # Update existing select fields that have new options
        update_select_options(config, existing_by_name, needs_update)
      end
    end
  end

  @impl true
  def batch_create(config, table_key, rows) when is_list(rows) do
    batch_create(config, table_key, rows, nil)
  end

  @doc """
  Create rows with optional per-batch callback.

  If `on_batch` is provided, it's called with each batch's mappings immediately
  after that batch succeeds — ensuring mappings are saved even if a later batch fails.
  Signature: `on_batch.(batch_mappings)`
  """
  def batch_create(config, table_key, rows, on_batch) when is_list(rows) do
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
          if is_function(on_batch, 1), do: on_batch.(mappings)
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
  def create_table(config, name) do
    database_id = config["database_id"] || config[:database_id]

    case api_post(config, "/api/database/tables/database/#{database_id}/", %{"name" => name}) do
      {:ok, %{status: 200, body: %{"id" => table_id}}} ->
        {:ok, table_id}

      {:ok, %{status: status, body: body}} ->
        {:error, "Create table '#{name}': #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Create table '#{name}': #{inspect(reason)}"}
    end
  end

  @doc """
  Clean up Baserow default columns after table creation.

  Baserow auto-creates Name (primary, can't delete), Notes, and Active on
  every new table. This function:
  1. Deletes the Notes column (unwanted)
  2. Renames/updates the primary Name field to match the template's primary field
  3. Deletes Active if the template doesn't define one

  `field_specs` is the list of template field specs for this table.
  """
  def cleanup_table_defaults(config, table_id, field_specs) do
    case list_fields(config, table_id) do
      {:ok, existing_fields} ->
        template_names = MapSet.new(field_specs, & &1.name)
        primary_spec = Enum.find(field_specs, & &1[:primary])

        # Delete Notes (always unwanted)
        delete_default_field(config, existing_fields, "Notes")

        # Handle Active: delete if template doesn't define it, update description if it does
        active_field = Enum.find(existing_fields, &(&1["name"] == "Active"))

        if active_field do
          if MapSet.member?(template_names, "Active") do
            # Template wants Active — update the default's description
            active_spec = Enum.find(field_specs, &(&1.name == "Active"))
            desc = active_spec[:description] || "Active status"

            update_field(config, active_field["id"], %{
              "description" => "#{@managed_description}\n#{desc}"
            })
          else
            delete_default_field(config, existing_fields, "Active")
          end
        end

        # Handle primary field (Name) — rename to match template's primary if different
        name_field = Enum.find(existing_fields, &(&1["name"] == "Name" && &1["primary"]))

        if name_field && primary_spec && primary_spec.name != "Name" do
          # Rename Baserow's Name to template's primary field name
          update_field(config, name_field["id"], %{
            "name" => primary_spec.name,
            "description" => "#{@managed_description}\n#{primary_spec[:description] || ""}"
          })
        else
          if name_field do
            # Just add managed description to the default Name
            update_field(config, name_field["id"], %{
              "description" =>
                "#{@managed_description}\n#{primary_spec[:description] || "Primary field"}"
            })
          end
        end

        :ok

      {:error, reason} ->
        Logger.warning("[Baserow] Failed to clean defaults for table #{table_id}: #{reason}")
        :ok
    end
  end

  @doc "Update an existing Baserow field by ID."
  def update_field(config, field_id, updates) do
    case api_patch(config, "/api/database/fields/#{field_id}/", updates) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s, body: b}} -> {:error, "Update field #{field_id}: #{s} #{inspect(b)}"}
      {:error, reason} -> {:error, "Update field #{field_id}: #{inspect(reason)}"}
    end
  end

  defp delete_default_field(config, existing_fields, name) do
    case Enum.find(existing_fields, &(&1["name"] == name)) do
      nil ->
        :ok

      field ->
        case api_delete(config, "/api/database/fields/#{field["id"]}/") do
          {:ok, %{status: status}} when status in [200, 204] ->
            Logger.debug("[Baserow] Deleted default field '#{name}'")
            :ok

          _ ->
            Logger.warning("[Baserow] Failed to delete default field '#{name}'")
            :ok
        end
    end
  end

  @impl true
  @doc """
  Create a field on a Baserow table from a universal field spec.

  Translates universal types (`:text`, `:single_select`, `:link_row`, etc.)
  to Baserow API parameters.
  """
  def create_field(config, table_id, field_spec) do
    body = translate_field_spec(field_spec, config)

    case api_post(config, "/api/database/fields/table/#{table_id}/", body) do
      {:ok, %{status: 200, body: %{"id" => field_id}}} ->
        {:ok, field_id}

      {:ok, %{status: status, body: resp}} ->
        {:error, "Create field '#{field_spec.name}': #{status} #{inspect(resp)}"}

      {:error, reason} ->
        {:error, "Create field '#{field_spec.name}': #{inspect(reason)}"}
    end
  end

  @impl true
  @doc "Create a view on a Baserow table from a universal view spec."
  def create_view(config, table_id, view_spec) do
    body = %{
      "name" => view_spec.name,
      "type" => translate_view_type(view_spec.type)
    }

    case api_post(config, "/api/database/views/table/#{table_id}/", body) do
      {:ok, %{status: 200, body: %{"id" => view_id}}} ->
        # Apply filters and sorts if specified
        maybe_apply_filters(config, view_id, view_spec)
        maybe_apply_sorts(config, view_id, view_spec)
        {:ok, view_id}

      {:ok, %{status: status, body: resp}} ->
        {:error, "Create view '#{view_spec.name}': #{status} #{inspect(resp)}"}

      {:error, reason} ->
        {:error, "Create view '#{view_spec.name}': #{inspect(reason)}"}
    end
  end

  @impl true
  @doc "Register a webhook on a Baserow table."
  def create_webhook(config, table_id, webhook_spec) do
    events = Enum.map(webhook_spec.events, &translate_webhook_event/1)
    callback_url = config["webhook_url"] || config[:webhook_url]

    body = %{
      "table_id" => table_id,
      "url" => callback_url,
      "events" => events,
      "active" => true
    }

    case api_post(config, "/api/database/webhooks/table/#{table_id}/", body) do
      {:ok, %{status: 200, body: %{"id" => webhook_id}}} ->
        {:ok, webhook_id}

      {:ok, %{status: status, body: resp}} ->
        {:error, "Create webhook: #{status} #{inspect(resp)}"}

      {:error, reason} ->
        {:error, "Create webhook: #{inspect(reason)}"}
    end
  end

  # ── Universal → Baserow Type Translation ──────────────────────

  @universal_to_baserow %{
    text: "text",
    long_text: "long_text",
    number: "number",
    date: "date",
    boolean: "boolean",
    single_select: "single_select",
    multi_select: "multiple_select",
    link_row: "link_row",
    lookup: "lookup",
    rollup: "rollup",
    formula: "formula",
    file: "file",
    url: "url",
    email: "email",
    workspace_member: "multiple_collaborators"
  }

  defp translate_field_spec(spec, config) do
    baserow_type = Map.get(@universal_to_baserow, spec.type, to_string(spec.type))

    body = %{"name" => spec.name, "type" => baserow_type}

    body
    |> maybe_add_description(spec)
    |> maybe_add_select_options(spec)
    |> maybe_add_link_row(spec, config)
    |> maybe_add_lookup(spec)
    |> maybe_add_rollup(spec)
    |> maybe_add_formula(spec)
    |> maybe_add_raw_opts(spec)
  end

  defp maybe_add_description(body, %{description: desc}) when is_binary(desc) do
    Map.put(body, "description", "#{@managed_description}\n#{desc}")
  end

  defp maybe_add_description(body, _), do: Map.put(body, "description", @managed_description)

  # Pass through raw opts for fields using direct Baserow API params (e.g., link_row_table_id)
  defp maybe_add_raw_opts(body, %{opts: opts}) when is_map(opts), do: Map.merge(body, opts)
  defp maybe_add_raw_opts(body, _), do: body

  defp maybe_add_select_options(body, %{type: type, options: options})
       when type in [:single_select, :multi_select] and is_list(options) do
    Map.put(
      body,
      "select_options",
      Enum.map(options, fn opt -> %{"value" => opt, "color" => "light-gray"} end)
    )
  end

  defp maybe_add_select_options(body, _), do: body

  defp maybe_add_link_row(body, %{type: :link_row, target: target}, config) do
    # Resolve target table key to Baserow table ID from config
    target_id =
      config["table_ids"][target] ||
        config["#{target}_table_id"] ||
        config[:"#{target}_table_id"]

    if target_id do
      Map.put(body, "link_row_table_id", target_id)
    else
      body
    end
  end

  defp maybe_add_link_row(body, _, _), do: body

  defp maybe_add_lookup(body, %{type: :lookup, target: target, target_field: field}) do
    body
    |> Map.put("through_field_name", to_string(target))
    |> Map.put("target_field_name", field)
  end

  defp maybe_add_lookup(body, _), do: body

  defp maybe_add_rollup(body, %{
         type: :rollup,
         target: target,
         target_field: field,
         rollup_function: func
       }) do
    body
    |> Map.put("through_field_name", to_string(target))
    |> Map.put("target_field_name", field)
    |> Map.put("rollup_function", to_string(func))
  end

  defp maybe_add_rollup(body, _), do: body

  defp maybe_add_formula(body, %{type: :formula, expression: expr}) when is_binary(expr) do
    Map.put(body, "formula", expr)
  end

  defp maybe_add_formula(body, %{type: :formula, expression: %{baserow: expr}}) do
    Map.put(body, "formula", expr)
  end

  defp maybe_add_formula(body, _), do: body

  @view_type_map %{
    grid: "grid",
    kanban: "kanban",
    calendar: "calendar",
    form: "form",
    gallery: "gallery",
    timeline: "timeline"
  }

  defp translate_view_type(type), do: Map.get(@view_type_map, type, to_string(type))

  defp translate_webhook_event(:created), do: "rows.created"
  defp translate_webhook_event(:updated), do: "rows.updated"
  defp translate_webhook_event(:deleted), do: "rows.deleted"
  defp translate_webhook_event(event), do: to_string(event)

  defp maybe_apply_filters(_config, _view_id, %{filters: filters})
       when is_list(filters) and filters != [] do
    # TODO: POST /api/database/views/{view_id}/filters/ for each filter
    :ok
  end

  defp maybe_apply_filters(_, _, _), do: :ok

  defp maybe_apply_sorts(_config, _view_id, %{sorts: sorts})
       when is_list(sorts) and sorts != [] do
    # TODO: POST /api/database/views/{view_id}/sortings/ for each sort
    :ok
  end

  defp maybe_apply_sorts(_, _, _), do: :ok

  # ── Webhook Event Parsing ─────────────────────────────────────

  @doc """
  Parse a Baserow webhook payload into a common event struct.

  Baserow sends: `%{"table_id" => ..., "event_type" => "rows.updated", "items" => [...]}`
  """
  def parse_webhook_event(payload) do
    event_type =
      case payload["event_type"] do
        "rows.created" -> :row_created
        "rows.updated" -> :row_updated
        "rows.deleted" -> :row_deleted
        other -> other
      end

    items = payload["items"] || payload["row_ids"] || []

    Enum.map(items, fn item ->
      %{
        event_id: nil,
        provider: :baserow,
        table_id: payload["table_id"],
        row_id: item["id"] || item,
        event_type: event_type,
        changed_fields: extract_changed_fields(item),
        old_values: nil,
        user_id: nil,
        timestamp: DateTime.utc_now()
      }
    end)
  end

  defp extract_changed_fields(item) when is_map(item) do
    item
    |> Map.drop(["id", "order"])
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp extract_changed_fields(_), do: %{}

  # ── Internals ─────────────────────────────────────────────────────

  defp table_id(config, :lrt), do: config["lrt_table_id"] || config[:lrt_table_id]
  defp table_id(config, :lat), do: config["lat_table_id"] || config[:lat_table_id]

  defp table_id(config, :actor_tuples),
    do: config["actor_tuples_table_id"] || config[:actor_tuples_table_id]

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

  # Store config in process dict for JWT refresh
  defp store_config(config), do: Process.put(:baserow_config, config)
  defp stored_config, do: Process.get(:baserow_config)

  @doc """
  Re-authenticate if JWT has expired. Called by Engine on 401 errors.
  Updates the stored config with a fresh JWT.
  """
  def refresh_auth(config) do
    Logger.info("[Baserow] Refreshing JWT...")

    case authenticate(config) do
      {:ok, refreshed} ->
        store_config(refreshed)
        {:ok, refreshed}

      error ->
        error
    end
  end

  # Retry: transient errors (429, 5xx, network) with exponential backoff, max 3 retries
  @max_retries 3

  defp api_get(config, path) do
    url = base_url(config) <> path

    Req.get(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      receive_timeout: 30_000,
      retry: :transient,
      retry_delay: &retry_delay/1,
      max_retries: @max_retries
    )
  end

  defp api_post(config, path, body) do
    url = base_url(config) <> path

    Req.post(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      json: body,
      receive_timeout: 60_000,
      retry: :transient,
      retry_delay: &retry_delay/1,
      max_retries: @max_retries
    )
  end

  defp api_patch(config, path, body) do
    url = base_url(config) <> path

    Req.patch(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      json: body,
      receive_timeout: 60_000,
      retry: :transient,
      retry_delay: &retry_delay/1,
      max_retries: @max_retries
    )
  end

  defp retry_delay(attempt), do: min(1000 * Integer.pow(2, attempt), 30_000)

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

  # Update select options on existing fields when our spec has options
  # that Baserow doesn't have yet. Additive only — never removes options.
  defp update_select_options(_config, _existing_by_name, []), do: :ok

  defp update_select_options(config, existing_by_name, field_specs) do
    select_specs =
      Enum.filter(field_specs, fn spec ->
        opts = spec[:opts] || %{}
        opts["select_options"] != nil
      end)

    Enum.reduce_while(select_specs, :ok, fn spec, :ok ->
      case Map.get(existing_by_name, spec.name) do
        nil ->
          {:cont, :ok}

        existing_field ->
          case maybe_add_select_options_to_field(config, existing_field, spec) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  defp maybe_add_select_options_to_field(config, existing_field, spec) do
    existing_options =
      (existing_field["select_options"] || [])
      |> MapSet.new(& &1["value"])

    desired_options = (spec[:opts] || %{})["select_options"] || []

    missing =
      desired_options
      |> Enum.reject(&MapSet.member?(existing_options, &1["value"]))

    if missing == [] do
      :ok
    else
      field_id = existing_field["id"]

      # Baserow: PATCH field with select_options appends new options
      # when you include existing ones + new ones
      all_options =
        (existing_field["select_options"] || []) ++
          Enum.map(missing, fn opt -> %{"value" => opt["value"], "color" => "light-gray"} end)

      body = %{"select_options" => all_options}

      case api_patch(config, "/api/database/fields/#{field_id}/", body) do
        {:ok, %{status: 200}} ->
          Logger.info("[Baserow] Updated #{spec.name}: added #{length(missing)} select option(s)")

          :ok

        {:ok, %{status: status, body: resp}} ->
          {:error, "Update select options for '#{spec.name}': #{status} #{inspect(resp)}"}

        {:error, reason} ->
          {:error, "Update select options for '#{spec.name}': #{inspect(reason)}"}
      end
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

  @family_options (SertantaiLegal.Scraper.Models.ehs_family() ++
                     SertantaiLegal.Scraper.Models.hr_family())
                  |> Enum.sort()

  # @type_desc_options removed — now queried dynamically via type_desc_options()

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

  @significance_options ["HIGH", "MEDIUM", "LOW"]

  defp essential_fields do
    [
      %{name: "Title", type: "long_text"},
      single_select_spec("Family", @family_options),
      %{name: "Year", type: "number", opts: %{"number_decimal_places" => 0}},
      %{name: "Number", type: "text"},
      single_select_spec("Type", type_desc_options()),
      single_select_spec("Status", @status_options),
      single_select_spec("Geographic Extent", @geo_extent_options),
      %{name: "Legislation URL", type: "url"},
      # Significance (law-level — rating + score only; counts are Baserow Rollups)
      single_select_spec("Significance", @significance_options),
      %{name: "Significance Score", type: "number", opts: %{"number_decimal_places" => 1}},
      %{name: "_source_id", type: "text"}
    ]
  end

  @function_options ["Making", "Amending", "Revoking", "Commencing", "Enacting"]
  defp duty_type_options, do: distinct_jsonb_values("duty_type")
  # Values to filter out of holder data — parser artifacts, not real actors
  @holder_exclusions MapSet.new([": He"])

  # Actor vocabulary now loaded from ActorDictionary (Zenoh queryable + YAML snapshot).
  # No more hardcoded holder_options() list.
  alias SertantaiLegal.Legal.ActorDictionary

  defp holder_options, do: ActorDictionary.canonical_labels()

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

  # ── LAT Field Specs ───────────────────────────────────────────────

  defp drrp_type_options do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT unnest(drrp_types) as val FROM legal_articles WHERE drrp_types IS NOT NULL ORDER BY val"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> ["Duty", "Responsibility", "Power", "Right", "Rule"]
    end
  end

  # duty_sub_type_options — queried from LAT data (not uk_lrt)
  defp duty_sub_type_options do
    case SertantaiLegal.Repo.query(
           "SELECT DISTINCT duty_sub_type FROM legal_articles WHERE duty_sub_type IS NOT NULL AND duty_sub_type != '' ORDER BY duty_sub_type"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [val] -> val end)
      _ -> []
    end
  end

  @doc """
  Returns Baserow field specs for the LAT table (duty-focused, aggregated).

  Each row is one complete provision (regulation/section) with all sub-parts
  concatenated. Duty Summary dropped (clause_refined echoes text verbatim).
  """
  def lat_field_specs(lrt_table_id) do
    [
      multi_select_spec("Type", drrp_type_options()),
      multi_select_spec("Duty Type", duty_sub_type_options()),
      multi_select_spec("Regulated Actors", regulated_actor_options()),
      %{name: "Provision Text", type: "long_text"},
      %{name: "Provision", type: "text"},
      # Significance (provision-level)
      single_select_spec("Significance", @significance_options),
      single_select_spec("Gravity", @significance_options),
      single_select_spec("Scope: Duty Bearer", @significance_options),
      single_select_spec("Strength", @significance_options),
      %{name: "Confidence", type: "number", opts: %{"number_decimal_places" => 2}},
      %{name: "_source_id", type: "text"},
      %{name: "Parent Law", type: "link_row", opts: %{"link_row_table_id" => lrt_table_id}}
    ]
  end

  # ── LRT Field Specs ──────────────────────────────────────────────

  # domain_options and geo_region_options now queried dynamically
  # Fitness and taxonomy options are queried from the DB at sync time,
  # not hardcoded. This accommodates evolving fractalaw taxonomy.

  defp fitness_person_options, do: distinct_array_values("fitness_person")
  defp fitness_sector_options, do: distinct_array_values("fitness_sector")
  # fitness_process/place/plant are text fields (not multi-select) in the current
  # LRT spec. Add dynamic option functions here if they become multi-select.
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

  defp tier_fields(:essential), do: []

  defp tier_fields(:standard) do
    [
      multi_select_spec("Function", @function_options),
      multi_select_spec("Duty Type", duty_type_options()),
      multi_select_spec("Purpose", purpose_options()),
      multi_select_spec("Duty Holder", holder_options()),
      multi_select_spec("Power Holder", holder_options()),
      multi_select_spec("Rights Holder", holder_options()),
      multi_select_spec("Domain", domain_options()),
      multi_select_spec("Geographic Region", geo_region_options()),
      multi_select_spec("Fitness Person", fitness_person_options()),
      multi_select_spec("Fitness Sector", fitness_sector_options()),
      %{name: "Fitness Process", type: "text"},
      %{name: "Fitness Place", type: "text"},
      %{name: "Fitness Plant", type: "text"}
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

  defp single_select_spec(name, options) do
    %{
      name: name,
      type: "single_select",
      opts: %{
        "select_options" => Enum.map(options, &%{"value" => &1, "color" => "light-gray"})
      }
    }
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
      "Legislation URL" => lrt.source_url,
      "Significance" => lrt.significance_rating,
      "Significance Score" => round_score(lrt.significance_score)
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
      "Type" => lat.drrp_types || [],
      "Duty Type" => lat.duty_sub_type || [],
      "Regulated Actors" => extract_active_actors(lat),
      "Provision Text" => lat.text,
      "Provision" => lat.provision,
      "Significance" => lat[:significance_overall],
      "Gravity" => lat[:significance_gravity],
      "Scope: Duty Bearer" => lat[:significance_scope_duty_bearer],
      "Strength" => lat[:significance_strength],
      "Confidence" => round_float(lat[:significance_confidence], 2),
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
      "Domain" => lrt.domain || [],
      "Geographic Region" => lrt.geo_region || [],
      "Fitness Person" => lrt.fitness_person || [],
      "Fitness Sector" => lrt.fitness_sector || [],
      "Fitness Process" => join_array(lrt.fitness_process),
      "Fitness Place" => join_array(lrt.fitness_place),
      "Fitness Plant" => join_array(lrt.fitness_plant)
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

  # Raw binary UUIDs from string-table queries need casting to string format
  @doc false
  def format_uuid(<<_::128>> = raw), do: Ecto.UUID.load!(raw)
  def format_uuid(uuid) when is_binary(uuid), do: uuid
  def format_uuid(nil), do: nil
end
