defmodule SertantaiLegal.Legal.SecondarySource.StructureType do
  @moduledoc """
  Document structure hint for the provision parser.

  - volumes: multi-volume (e.g. JSP 375 Vol 1, Vol 3)
  - parts: part-based (e.g. ACoP with Part 1, Part 2)
  - clauses: clause-numbered (e.g. ISO 45001 cl.4, cl.5)
  - sections: section-based (e.g. HSG with numbered sections)
  """

  use Ash.Type.Enum,
    values: [
      :volumes,
      :parts,
      :clauses,
      :sections
    ]
end
