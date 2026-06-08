defmodule SertantaiLegal.Sync.Templates.WebhookEvent do
  @moduledoc """
  Provider-agnostic webhook event struct.

  Each provider adapter parses its native webhook payload into this
  common format. The webhook controller routes events to handlers
  based on `event_type` and `table_id`.
  """

  @type t :: %__MODULE__{
          event_id: String.t() | nil,
          provider: atom(),
          table_id: term(),
          row_id: term(),
          event_type: :row_created | :row_updated | :row_deleted,
          changed_fields: map(),
          old_values: map() | nil,
          user_id: String.t() | nil,
          timestamp: DateTime.t()
        }

  defstruct [
    :event_id,
    :provider,
    :table_id,
    :row_id,
    :event_type,
    :changed_fields,
    :old_values,
    :user_id,
    :timestamp
  ]

  @doc "Build a WebhookEvent from a map (e.g., parsed by a provider adapter)."
  def from_map(attrs) when is_map(attrs) do
    %__MODULE__{
      event_id: attrs[:event_id] || attrs["event_id"],
      provider: attrs[:provider] || attrs["provider"],
      table_id: attrs[:table_id] || attrs["table_id"],
      row_id: attrs[:row_id] || attrs["row_id"],
      event_type: attrs[:event_type] || attrs["event_type"],
      changed_fields: attrs[:changed_fields] || attrs["changed_fields"] || %{},
      old_values: attrs[:old_values] || attrs["old_values"],
      user_id: attrs[:user_id] || attrs["user_id"],
      timestamp: attrs[:timestamp] || attrs["timestamp"] || DateTime.utc_now()
    }
  end
end
