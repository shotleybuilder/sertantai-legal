defmodule SertantaiLegal.Legal.SecondarySource.ProvisionSectionType do
  @moduledoc """
  Structural type enum for secondary source provisions.

  Covers the document structures found in ACoPs, JSPs, standards,
  and guidance notes. Distinct from the legislation SectionType enum
  which has statute-specific values (article, commencement, signed).
  """

  use Ash.Type.Enum,
    values: [
      :volume,
      :part,
      :chapter,
      :section,
      :clause,
      :heading,
      :paragraph,
      :sub_paragraph,
      :schedule,
      :annex,
      :table,
      :figure,
      :note
    ]
end
