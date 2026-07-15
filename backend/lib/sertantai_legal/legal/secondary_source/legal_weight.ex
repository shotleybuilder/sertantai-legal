defmodule SertantaiLegal.Legal.SecondarySource.LegalWeight do
  @moduledoc """
  Legal weight of a secondary source — drives control prioritisation.

  - reverse_burden: ACoPs — follow it or prove your alternative is at least as good
  - regard_had_to: HSE guidance — courts/enforcers consider it
  - contractual: JSPs, client requirements — binding via contract, not statute
  - state_of_art: Standards (ISO, BS) — defines reasonable practicability
  - best_practice: Industry codes — expected but not enforceable
  """

  use Ash.Type.Enum,
    values: [
      :reverse_burden,
      :regard_had_to,
      :contractual,
      :state_of_art,
      :best_practice
    ]
end
