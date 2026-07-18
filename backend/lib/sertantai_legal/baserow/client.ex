defmodule SertantaiLegal.Baserow.Client do
  @moduledoc """
  Pure Baserow API wrapper -- no domain knowledge.

  Handles authentication, HTTP transport, field/table/view/webhook CRUD,
  batch row operations, and Baserow-specific type translation.  All functions
  accept a `config` map containing connection details (base_url, credentials,
  jwt, table IDs).
  """

  require Logger

  @batch_size 200
  @managed_description "🚫 Managed by SertantAI — do not rename or delete"

  @view_type_map %{
    grid: "grid",
    kanban: "kanban",
    calendar: "calendar",
    form: "form",
    gallery: "gallery",
    timeline: "timeline"
  }

  # ── Authentication ───────────────────────────────────────────────

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

  # ── Connection ───────────────────────────────────────────────────

  @doc "Lightweight connection check: list fields on the LRT table."
  def test_connection(config) do
    case list_fields(config, :lrt) do
      {:ok, fields} ->
        {:ok, %{lrt_field_count: length(fields)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Row Listing ──────────────────────────────────────────────────

  @doc """
  Fetch all rows from a Baserow table, returning a Name → row_ids map.

  Paginates through all rows (200/page), extracting the primary field
  value (Name) and the Baserow row ID for each row. Used by the sync
  engine for CUD decisions and delete reconciliation.

  Returns `Name → [row_id, ...]` — a list of row_ids per Name to handle
  duplicates. Multiple syncs or format changes can create rows with the
  same Name; collecting all IDs ensures delete reconciliation catches them all.
  """
  def list_all_rows(config, table_key_or_id) do
    tid =
      if is_atom(table_key_or_id),
        do: table_id(config, table_key_or_id),
        else: table_key_or_id

    fetch_all_rows_paginated(config, tid, 1, %{})
  end

  defp fetch_all_rows_paginated(config, table_id, page, acc) do
    case api_get(
           config,
           "/api/database/rows/table/#{table_id}/?user_field_names=true&size=#{@batch_size}&page=#{page}"
         ) do
      {:ok, %{status: 200, body: %{"results" => results, "next" => next}}} ->
        new_acc =
          Enum.reduce(results, acc, fn row, map ->
            name = row["Name"]

            if name do
              Map.update(map, name, [row["id"]], fn ids -> [row["id"] | ids] end)
            else
              map
            end
          end)

        if next do
          fetch_all_rows_paginated(config, table_id, page + 1, new_acc)
        else
          {:ok, new_acc}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, "Baserow list_all_rows returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Baserow list_all_rows failed: #{inspect(reason)}"}
    end
  end

  # ── Field Operations ─────────────────────────────────────────────

  @doc "List all fields on a Baserow table."
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

  @doc "Update an existing Baserow field by ID."
  def update_field(config, field_id, updates) do
    case api_patch(config, "/api/database/fields/#{field_id}/", updates) do
      {:ok, %{status: 200}} -> :ok
      {:ok, %{status: s, body: b}} -> {:error, "Update field #{field_id}: #{s} #{inspect(b)}"}
      {:error, reason} -> {:error, "Update field #{field_id}: #{inspect(reason)}"}
    end
  end

  # ── Table Operations ─────────────────────────────────────────────

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
  Prepare a Baserow table for first sync: rename from default "Table" to
  a meaningful name, delete default empty rows, and remove default columns
  (Notes, Active, etc.) that Baserow creates automatically.

  Call this before `ensure_fields` on first sync. Idempotent -- skips
  rename if already named correctly, skips cleanup if no default fields.
  """
  def prepare_table(config, table_key, table_name) do
    with :ok <- rename_table(config, table_key, table_name),
         :ok <- clean_default_rows(config, table_key) do
      :ok
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
            # Template wants Active -- update the default's description
            active_spec = Enum.find(field_specs, &(&1.name == "Active"))
            desc = active_spec[:description] || "Active status"

            update_field(config, active_field["id"], %{
              "description" => "#{@managed_description}\n#{desc}"
            })
          else
            delete_default_field(config, existing_fields, "Active")
          end
        end

        # Handle primary field (Name) -- rename/convert to match template's primary
        name_field = Enum.find(existing_fields, &(&1["name"] == "Name" && &1["primary"]))

        if name_field && primary_spec do
          # Rename the primary field -- formula conversion happens later
          # (after all fields are created, so formula references resolve)
          updates = %{
            "name" => primary_spec.name,
            "description" => "#{@managed_description}\n#{primary_spec[:description] || ""}"
          }

          update_field(config, name_field["id"], updates)
        else
          if name_field do
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

  @doc """
  Convert the primary field to a formula after all other fields are created.
  Only needed when the template's primary field is type :formula.
  """
  def finalize_primary_formula(config, table_id, field_specs) do
    primary_spec = Enum.find(field_specs, &(&1[:primary] && &1.type == :formula))

    if primary_spec do
      case list_fields(config, table_id) do
        {:ok, fields} ->
          primary_field = Enum.find(fields, &(&1["name"] == primary_spec.name && &1["primary"]))

          if primary_field do
            expression =
              case primary_spec[:expression] do
                %{baserow: expr} -> expr
                expr when is_binary(expr) -> expr
                _ -> ""
              end

            update_field(config, primary_field["id"], %{
              "type" => "formula",
              "formula" => expression,
              "formula_type" => "text"
            })
          else
            :ok
          end

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  # ── View Operations ──────────────────────────────────────────────

  @doc "Create a view on a Baserow table from a universal view spec."
  @doc "List all views for a Baserow table. Returns a list of view maps."
  def list_views(config, table_id) do
    case api_get(config, "/api/database/views/table/#{table_id}/") do
      {:ok, %{status: 200, body: views}} when is_list(views) ->
        {:ok, views}

      {:ok, %{status: status, body: body}} ->
        {:error, "List views: #{status} #{inspect(body)}"}

      {:error, reason} ->
        {:error, "List views: #{inspect(reason)}"}
    end
  end

  @doc "Delete a Baserow view by ID."
  def delete_view(config, view_id) do
    case api_delete(config, "/api/database/views/#{view_id}/") do
      {:ok, %{status: status}} when status in [200, 204] -> :ok
      {:ok, %{status: status, body: body}} -> {:error, "Delete view: #{status} #{inspect(body)}"}
      {:error, reason} -> {:error, "Delete view: #{inspect(reason)}"}
    end
  end

  def create_view(config, table_id, view_spec) do
    body = %{
      "name" => view_spec.name,
      "type" => translate_view_type(view_spec.type)
    }

    case api_post(config, "/api/database/views/table/#{table_id}/", body) do
      {:ok, %{status: 200, body: %{"id" => view_id}}} ->
        # Resolve field names → IDs for filters, sorts, grouping
        field_map = build_field_name_map(config, table_id)
        maybe_apply_filters(config, view_id, view_spec, field_map)
        maybe_apply_sorts(config, view_id, view_spec, field_map)
        maybe_apply_grouping(config, view_id, view_spec, field_map)
        {:ok, view_id}

      {:ok, %{status: status, body: resp}} ->
        {:error, "Create view '#{view_spec.name}': #{status} #{inspect(resp)}"}

      {:error, reason} ->
        {:error, "Create view '#{view_spec.name}': #{inspect(reason)}"}
    end
  end

  # ── Webhook Operations ───────────────────────────────────────────

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

  # ── Batch Row Operations ─────────────────────────────────────────

  @doc "Create rows in batches. Returns `{:ok, mappings}` or `{:error, reason}`."
  def batch_create(config, table_key, rows) when is_list(rows) do
    batch_create(config, table_key, rows, nil)
  end

  @doc """
  Create rows with optional per-batch callback.

  If `on_batch` is provided, it's called with each batch's mappings immediately
  after that batch succeeds -- ensuring mappings are saved even if a later batch fails.
  Signature: `on_batch.(batch_mappings)`
  """
  def batch_create(config, table_key, rows, on_batch) when is_list(rows) do
    table_id = table_id(config, table_key)

    # Ensure all select option values exist before creating rows
    ensure_select_options(config, table_id, rows)

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

  @doc "Update rows in batches. Returns `{:ok, count}` or `{:error, reason}`."
  def batch_update(config, table_key, rows) when is_list(rows) do
    table_id = table_id(config, table_key)

    # Ensure all select option values exist before updating rows
    ensure_select_options(config, table_id, rows)

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

  @doc "Delete rows in batches. Returns `{:ok, count}` or `{:error, reason}`."
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

  # ── Webhook Event Parsing ────────────────────────────────────────

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

  # ── Helpers: Select Spec Builders ────────────────────────────────

  @doc false
  def single_select_spec(name, options) do
    %{
      name: name,
      type: "single_select",
      opts: %{
        "select_options" => Enum.map(options, &%{"value" => &1, "color" => "light-gray"})
      }
    }
  end

  @doc false
  def multi_select_spec(name, options) do
    %{
      name: name,
      type: "multiple_select",
      opts: %{
        "select_options" => Enum.map(options, &%{"value" => &1, "color" => "light-gray"})
      }
    }
  end

  # ── Private: Table ID Resolution ─────────────────────────────────

  @doc false
  def table_id(config, :lrt), do: config["lrt_table_id"] || config[:lrt_table_id]
  def table_id(config, :lat), do: config["lat_table_id"] || config[:lat_table_id]

  def table_id(config, :actor_tuples),
    do: config["actor_tuples_table_id"] || config[:actor_tuples_table_id]

  def table_id(config, :controls),
    do: config["controls_table_id"] || config[:controls_table_id]

  def table_id(config, :control_mappings),
    do: config["control_mappings_table_id"] || config[:control_mappings_table_id]

  def table_id(config, :evidence_patterns),
    do: config["evidence_patterns_table_id"] || config[:evidence_patterns_table_id]

  def table_id(config, :artefact_templates),
    do: config["artefact_templates_table_id"] || config[:artefact_templates_table_id]

  def table_id(config, :assessments),
    do: config["assessments_table_id"] || config[:assessments_table_id]

  def table_id(config, :personnel),
    do: config["personnel_table_id"] || config[:personnel_table_id]

  def table_id(config, :actions),
    do: config["actions_table_id"] || config[:actions_table_id]

  def table_id(config, :hierarchy),
    do: config["hierarchy_table_id"] || config[:hierarchy_table_id]

  # ── Private: HTTP Transport ──────────────────────────────────────

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

  defp api_delete(config, path) do
    url = base_url(config) <> path

    Req.delete(url,
      headers: [auth_header(config), {"Content-Type", "application/json"}],
      receive_timeout: 30_000
    )
  end

  defp retry_delay(attempt), do: min(1000 * Integer.pow(2, attempt), 30_000)

  # ── Private: Auth & Config ───────────────────────────────────────

  defp base_url(config), do: String.trim_trailing(config["base_url"] || config[:base_url], "/")

  defp credentials(config), do: config["credentials"] || config[:credentials]

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

  # ── Private: Universal -> Baserow Type Translation ───────────────

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

  # ── Private: View/Webhook Translation ────────────────────────────

  defp translate_view_type(type), do: Map.get(@view_type_map, type, to_string(type))

  defp translate_webhook_event(:created), do: "rows.created"
  defp translate_webhook_event(:updated), do: "rows.updated"
  defp translate_webhook_event(:deleted), do: "rows.deleted"
  defp translate_webhook_event(event), do: to_string(event)

  defp build_field_name_map(config, table_id) do
    case list_fields(config, table_id) do
      {:ok, fields} ->
        Map.new(fields, fn f -> {f["name"], %{id: f["id"], type: f["type"]}} end)

      _ ->
        %{}
    end
  end

  # Baserow filter types that need a field-type prefix for select fields
  @select_field_types ["single_select", "multiple_select"]

  @base_filter_type_map %{
    equal: "equal",
    not_equal: "not_equal",
    empty: "empty",
    not_empty: "not_empty",
    contains: "contains",
    higher_than: "higher_than",
    lower_than: "lower_than"
  }

  # Baserow requires "single_select_equal" instead of "equal" for single_select fields,
  # and "boolean" instead of "equal" for boolean fields.
  defp resolve_filter_type(op, field_type) do
    base = Map.get(@base_filter_type_map, op, to_string(op))

    cond do
      field_type in @select_field_types and base in ["equal", "not_equal"] ->
        "#{field_type}_#{base}"

      field_type == "boolean" and base == "equal" ->
        "boolean"

      true ->
        base
    end
  end

  defp maybe_apply_filters(config, view_id, %{filters: filters}, field_map)
       when is_list(filters) and filters != [] do
    Enum.each(filters, fn filter ->
      field_info = Map.get(field_map, filter.field)

      if field_info do
        filter_type = resolve_filter_type(filter.op, field_info.type)

        body = %{
          "field" => field_info.id,
          "type" => filter_type,
          "value" => to_string(Map.get(filter, :value, ""))
        }

        case api_post(config, "/api/database/views/#{view_id}/filters/", body) do
          {:ok, %{status: 200}} -> :ok
          other -> Logger.warning("[Baserow] Filter on #{filter.field} failed: #{inspect(other)}")
        end
      else
        Logger.warning("[Baserow] Filter field '#{filter.field}' not found")
      end
    end)
  end

  defp maybe_apply_filters(_, _, _, _), do: :ok

  defp maybe_apply_sorts(config, view_id, %{sorts: sorts}, field_map)
       when is_list(sorts) and sorts != [] do
    Enum.each(sorts, fn sort ->
      field_info = Map.get(field_map, sort.field)

      if field_info do
        body = %{
          "field" => field_info.id,
          "order" => if(sort.direction == :desc, do: "DESC", else: "ASC")
        }

        case api_post(config, "/api/database/views/#{view_id}/sortings/", body) do
          {:ok, %{status: 200}} -> :ok
          other -> Logger.warning("[Baserow] Sort on #{sort.field} failed: #{inspect(other)}")
        end
      else
        Logger.warning("[Baserow] Sort field '#{sort.field}' not found")
      end
    end)
  end

  defp maybe_apply_sorts(_, _, _, _), do: :ok

  defp maybe_apply_grouping(config, view_id, %{group_by: group_field}, field_map)
       when is_binary(group_field) do
    field_info = Map.get(field_map, group_field)

    if field_info do
      body = %{
        "field" => field_info.id,
        "order" => "ASC"
      }

      case api_post(config, "/api/database/views/#{view_id}/group_bys/", body) do
        {:ok, %{status: 200}} -> :ok
        other -> Logger.warning("[Baserow] Group by #{group_field} failed: #{inspect(other)}")
      end
    else
      Logger.warning("[Baserow] Group field '#{group_field}' not found")
    end
  end

  defp maybe_apply_grouping(_, _, _, _), do: :ok

  # ── Private: Misc Helpers ────────────────────────────────────────

  defp extract_changed_fields(item) when is_map(item) do
    item
    |> Map.drop(["id", "order"])
    |> Map.reject(fn {_k, v} -> is_nil(v) end)
  end

  defp extract_changed_fields(_), do: %{}

  defp extract_mappings(created_rows) do
    Enum.map(created_rows, fn row ->
      %{
        external_row_id: row["id"],
        # The source_id is set by the caller who knows the mapping
        source_id: row["_source_id"]
      }
    end)
  end

  @doc false
  def delete_default_field(config, existing_fields, name) do
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

    # Fetch existing rows -- if few and empty, delete them (default Baserow rows)
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

      # Table has real data or is empty -- don't touch
      _ ->
        :ok
    end
  end

  # Delete default Baserow fields that aren't in our field specs.
  # Baserow creates "Notes" (long_text), "Active" (boolean), and "Name" (text)
  # by default. We keep any that match our specs, delete the rest.
  @doc false
  def clean_default_fields(config, _table_key, existing_fields, desired_specs) do
    desired_names = MapSet.new(desired_specs, & &1.name)

    # Baserow's default fields -- only delete these, never user-created fields
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

  # Used by ensure_fields in the provider module
  @doc false
  def create_fields_sequentially(_, _, []), do: :ok

  def create_fields_sequentially(config, table_key, [spec | rest]) do
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
  # ── Dynamic Select Options ─────────────────────────────────────

  # Scan rows for select field values, ensure they exist as Baserow options.
  # Called automatically by batch_create and batch_update before posting data.
  # Idempotent — only PATCHes fields that have new, unknown values.
  @invalid_option_values MapSet.new([nil, "", "none"])

  defp ensure_select_options(_config, _table_id, []), do: :ok

  defp ensure_select_options(config, table_id, rows) do
    case list_fields(config, table_id) do
      {:ok, fields} ->
        select_fields =
          Enum.filter(fields, &(&1["type"] in ["single_select", "multiple_select"]))

        Enum.each(select_fields, fn field ->
          field_name = field["name"]

          existing_options =
            (field["select_options"] || [])
            |> MapSet.new(& &1["value"])

          # Extract unique values from rows for this field
          row_values =
            rows
            |> Enum.flat_map(fn row ->
              case Map.get(row, field_name) do
                nil -> []
                val when is_list(val) -> val
                val when is_binary(val) -> [val]
                _ -> []
              end
            end)
            |> Enum.uniq()
            |> Enum.reject(&MapSet.member?(@invalid_option_values, &1))

          missing =
            Enum.reject(row_values, &MapSet.member?(existing_options, &1))

          if missing != [] do
            all_options =
              (field["select_options"] || []) ++
                Enum.map(missing, &%{"value" => &1, "color" => "light-gray"})

            case api_patch(config, "/api/database/fields/#{field["id"]}/", %{
                   "select_options" => all_options
                 }) do
              {:ok, %{status: 200}} ->
                Logger.info(
                  "[Baserow] Added #{length(missing)} option(s) to #{field_name}: #{Enum.take(missing, 5) |> inspect()}"
                )

              {:ok, %{status: status, body: resp}} ->
                Logger.warning(
                  "[Baserow] Failed to add options to #{field_name}: #{status} #{inspect(resp)}"
                )

              {:error, reason} ->
                Logger.warning(
                  "[Baserow] Failed to add options to #{field_name}: #{inspect(reason)}"
                )
            end
          end
        end)

      {:error, reason} ->
        Logger.warning(
          "[Baserow] Could not list fields for select option check: #{inspect(reason)}"
        )
    end
  end

  # that Baserow doesn't have yet. Additive only -- never removes options.
  @doc false
  def update_select_options(_config, _existing_by_name, []), do: :ok

  def update_select_options(config, existing_by_name, field_specs) do
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

  @doc false
  def managed_description, do: @managed_description
end
