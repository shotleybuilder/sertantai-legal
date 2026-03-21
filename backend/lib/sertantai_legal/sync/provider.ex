defmodule SertantaiLegal.Sync.Provider do
  @moduledoc """
  Supported sync target providers.
  """

  use Ash.Type.Enum,
    values: [
      :baserow,
      :airtable,
      :notion,
      :zapier
    ]
end
