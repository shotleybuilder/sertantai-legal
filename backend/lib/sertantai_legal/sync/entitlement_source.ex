defmodule SertantaiLegal.Sync.EntitlementSource do
  @moduledoc """
  How an entitlement was granted.

  - tier_sync: pushed from hub when subscription changes
  - manual: manually granted by admin
  - trial: temporary trial access
  """

  use Ash.Type.Enum,
    values: [
      :tier_sync,
      :manual,
      :trial
    ]
end
