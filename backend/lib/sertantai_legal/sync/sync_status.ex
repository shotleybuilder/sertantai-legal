defmodule SertantaiLegal.Sync.SyncStatus do
  @moduledoc """
  Status of a sync configuration's last/current sync.
  """

  use Ash.Type.Enum,
    values: [
      :idle,
      :queued,
      :syncing,
      :completed,
      :failed
    ]
end
