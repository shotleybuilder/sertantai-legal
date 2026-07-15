defmodule SertantaiLegal.Legal.SecondarySource.SourceType do
  @moduledoc """
  Type of secondary source document.

  - acop: Approved Code of Practice (HSE L-series)
  - guidance: Approved guidance (HSE HSG-series)
  - standard: Published standard (ISO, BSI, EN)
  - jsp: Joint Service Publication (MoD)
  - industry_code: Industry body code of practice
  """

  use Ash.Type.Enum,
    values: [
      :acop,
      :guidance,
      :standard,
      :jsp,
      :industry_code
    ]
end
