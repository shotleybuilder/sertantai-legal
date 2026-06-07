defmodule SertantaiLegal.Sync.ProviderBehaviour do
  @moduledoc """
  Behaviour for sync target providers (Baserow, Airtable, NocoDB, etc.).

  Two levels of operations:
  1. **Row operations** — CRUD on existing tables (existing, used by Engine.run)
  2. **Schema operations** — create tables, fields, views, webhooks (new, used by TemplateApplicator)

  Each provider also declares its capabilities so templates can degrade
  gracefully when a feature isn't supported.
  """

  @type config :: map()
  @type field_spec :: %{name: String.t(), type: String.t(), opts: map()}
  @type row :: map()
  @type row_mapping :: %{source_id: String.t(), external_row_id: integer()}

  # ── Capabilities ──────────────────────────────────────────────

  @doc """
  Declare provider capabilities.

  Returns a map describing what this provider supports, used by
  TemplateApplicator to gate feature creation.
  """
  @callback capabilities() :: %{
              view_types: [atom()],
              field_level_permissions: boolean(),
              webhooks: boolean(),
              webhook_includes_old_values: boolean(),
              webhook_includes_user_id: boolean(),
              batch_size: pos_integer()
            }

  # ── Connection ────────────────────────────────────────────────

  @doc "Test that credentials and target are reachable."
  @callback test_connection(config()) :: {:ok, map()} | {:error, String.t()}

  # ── Row operations (existing) ─────────────────────────────────

  @doc "List existing fields on the target table."
  @callback list_fields(config(), table_key :: atom()) :: {:ok, [map()]} | {:error, String.t()}

  @doc "Create missing fields on the target table to match our schema."
  @callback ensure_fields(config(), table_key :: atom(), [field_spec()]) ::
              :ok | {:error, String.t()}

  @doc "Create rows in the target, returning mappings of source_id → external_row_id."
  @callback batch_create(config(), table_key :: atom(), [row()]) ::
              {:ok, [row_mapping()]} | {:error, String.t()}

  @doc "Update existing rows in the target by external_row_id."
  @callback batch_update(config(), table_key :: atom(), [row()]) ::
              {:ok, integer()} | {:error, String.t()}

  @doc "Delete rows from the target by external_row_id."
  @callback batch_delete(config(), table_key :: atom(), [integer()]) ::
              {:ok, integer()} | {:error, String.t()}

  # ── Schema operations (new — for TemplateApplicator) ──────────

  @doc "Create a new table in the provider's database/workspace. Returns the provider's table ID."
  @callback create_table(config(), name :: String.t()) ::
              {:ok, term()} | {:error, String.t()}

  @doc "Create a field on an existing table. Returns the provider's field ID."
  @callback create_field(config(), table_id :: term(), field_spec()) ::
              {:ok, term()} | {:error, String.t()}

  @doc "Create a view on an existing table. Returns the provider's view ID."
  @callback create_view(config(), table_id :: term(), view_spec :: map()) ::
              {:ok, term()} | {:error, String.t()}

  @doc "Register a webhook on a table. Returns the provider's webhook ID."
  @callback create_webhook(config(), table_id :: term(), webhook_spec :: map()) ::
              {:ok, term()} | {:error, String.t()}

  @optional_callbacks [
    create_table: 2,
    create_field: 3,
    create_view: 3,
    create_webhook: 3,
    capabilities: 0
  ]
end
