defmodule SertantaiLegal.Legal.SecondarySource.DocumentStatus do
  @moduledoc """
  Publication status of a secondary source.

  - current: actively in force
  - withdrawn: no longer valid (replaced or removed)
  - superseded: replaced by a newer edition (supersedes_id links to successor)
  """

  use Ash.Type.Enum,
    values: [
      :current,
      :withdrawn,
      :superseded
    ]
end
