defmodule SertantaiLegal.Sync.ApplicabilitySource do
  @moduledoc """
  How an applicability decision was made.

  - enhesa_import: pre-populated from Enhesa CSV Answer field
  - manual: human reviewer via API/UI
  - screener: automated Fitness-based screener
  """

  use Ash.Type.Enum,
    values: [
      :enhesa_import,
      :manual,
      :screener
    ]
end
