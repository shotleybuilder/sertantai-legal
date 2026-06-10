defmodule SertantaiLegal.Sync.SourceType do
  @moduledoc """
  Type of source record in a sync row mapping.
  """

  use Ash.Type.Enum,
    values: [
      :lrt,
      :lat,
      :actor_tuples
    ]
end
