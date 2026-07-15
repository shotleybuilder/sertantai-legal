defmodule SertantaiLegal.Legal.SourceLink.LinkType do
  @moduledoc """
  Relationship type between a secondary source and primary legislation.

  - approved_under: formal statutory basis (e.g. "ACoP approved under HSWA s.16")
  - implements: operational mapping (e.g. "standard addresses requirements of Reg 5(1)")
  - references: informational citation (e.g. "guidance cites Fire Safety Order Art 9")
  - supplements: additional requirements beyond the Act (e.g. JSP chapters)
  - superseded_by: secondary source replaced by a legislative change
  """

  use Ash.Type.Enum,
    values: [
      :approved_under,
      :implements,
      :references,
      :supplements,
      :superseded_by
    ]
end
