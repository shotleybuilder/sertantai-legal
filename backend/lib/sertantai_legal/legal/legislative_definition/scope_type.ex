defmodule SertantaiLegal.Legal.LegislativeDefinition.ScopeType do
  @moduledoc """
  Scope enum for legislative definitions.

  Indicates how broadly a defined term applies within its parent law:
  - :law — applies to the entire instrument
  - :part — applies to a specific Part of the instrument
  - :provision — applies to a specific section/regulation only
  """

  use Ash.Type.Enum,
    values: [
      :law,
      :part,
      :provision
    ]
end
