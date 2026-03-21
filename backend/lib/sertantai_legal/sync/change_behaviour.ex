defmodule SertantaiLegal.Sync.ChangeBehaviour do
  @moduledoc """
  What to do when rows leave sync scope (filter change or entitlement downgrade).

  - delete: remove rows from target (default)
  - retain: keep rows but stop updating them
  """

  use Ash.Type.Enum,
    values: [
      :delete,
      :retain
    ]
end
