defmodule SertantaiLegal.Sync.SecondaryApplicabilitySource do
  @moduledoc """
  How a secondary source applicability decision was made.

  - manual: human reviewer via API/UI
  - inherited: auto-populated because parent law is applicable
  - screener: automated sector/certification-based screening
  """

  use Ash.Type.Enum,
    values: [
      :manual,
      :inherited,
      :screener
    ]
end
