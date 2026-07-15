defmodule SertantaiLegal.Legal.SecondarySource.TextSource do
  @moduledoc """
  How the provision text was obtained.

  - full_text: complete text extracted from public document (ACoPs, guidance, JSPs)
  - summary: AI-generated obligation summary (paywalled standards — no full text stored)
  - heading_only: only the heading/clause number is stored (minimal records)
  """

  use Ash.Type.Enum,
    values: [
      :full_text,
      :summary,
      :heading_only
    ]
end
