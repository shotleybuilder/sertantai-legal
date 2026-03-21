defmodule SertantaiLegal.Sync.ProviderBehaviour do
  @moduledoc """
  Behaviour for sync target providers (Baserow, Airtable, Notion, Zapier).

  Each provider implements push operations for syncing LRT/LAT data
  to an external database tool.
  """

  @type config :: map()
  @type field_spec :: %{name: String.t(), type: String.t(), opts: map()}
  @type row :: map()
  @type row_mapping :: %{source_id: String.t(), external_row_id: integer()}

  @doc "Test that credentials and target are reachable."
  @callback test_connection(config()) :: {:ok, map()} | {:error, String.t()}

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
end
