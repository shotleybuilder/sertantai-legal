defmodule SertantaiLegal.Sync.ApplicabilityStatus do
  @moduledoc """
  Per-law applicability status for an organization.

  - yes: law applies to this org
  - no: law does not apply
  - excluded: explicitly excluded (stronger than no — never show)
  - unreviewed: no decision yet
  """

  use Ash.Type.Enum,
    values: [
      :yes,
      :no,
      :excluded,
      :unreviewed
    ]
end
