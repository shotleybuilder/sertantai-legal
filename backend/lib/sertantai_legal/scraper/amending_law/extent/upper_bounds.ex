defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.UpperBounds do
  @moduledoc """
  Extensions whose qualifier only narrows within the place they name, read
  as that place: its upper bound (Waste, Water and Climate: Extent reader,
  Decision 2, 2026-11-26). Where a change lands is then narrowed by the
  amended provision's own extent, and a purpose limit is fractalaw's
  tagging, never a reader's split (RULES, conditionals).

  - "Section 4(2) … and so much of sections 4(10) and 27 … as relates to
    enactments extending to England and Wales shall extend also to England
    and Wales" (Natural Heritage (Scotland) Act 1991 s.28(5)) → "Section
    4(2) … and sections 4(10) and 27 … shall extend also to England and
    Wales": the enactments named are the place's own;
  - "Sections 61 and 62 and Schedule 8 extend also to Scotland, but only so
    far as required for the purposes of regulations …" (Water Act 2014
    s.93(2)) → "… extend also to Scotland.".

  Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Places

  @places Places.place_names()

  @so_much Regex.compile!(
             "\\bso\\s+much\\s+of\\s+(.+?)\\s+as\\s+relates?\\s+to\\s+(?:any\\s+)?enactments?\\s+(?:extending|which\\s+extends?)\\s+to\\s+(#{@places})\\s+((?:shall\\s+)?extends?\\s+also\\s+to\\s+\\2)\\b",
             "u"
           )

  @only_so_far Regex.compile!(
                 "\\b(extends?\\s+also\\s+to\\s+(?:#{@places}))\\s*,\\s*but\\s+only\\s+(?:in\\s+)?so\\s+far\\s+as\\s+(?:is\\s+)?(?:required|necessary)\\s+for\\s+the\\s+purposes\\s+of\\b[^.;]*",
                 "u"
               )

  @doc "The text with each upper-bound extension made plain."
  @spec resolve(String.t()) :: String.t()
  def resolve(text) do
    text
    |> then(&Regex.replace(@so_much, &1, "\\1 \\3"))
    |> then(&Regex.replace(@only_so_far, &1, "\\1"))
  end
end
