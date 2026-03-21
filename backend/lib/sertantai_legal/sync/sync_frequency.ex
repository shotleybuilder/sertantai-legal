defmodule SertantaiLegal.Sync.SyncFrequency do
  @moduledoc """
  How often a sync configuration runs.
  """

  use Ash.Type.Enum,
    values: [
      :manual,
      :daily,
      :weekly
    ]
end
