defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ExceptSame do
  @moduledoc """
  A default's leading exception of the changes that follow their
  enactments: "Except for the repeals and amendments contained in
  paragraphs 3 and 4 of Schedule 1, and the related entries in Schedule 2,
  to this Act, which have the same extent as the Acts there repealed and
  amended, this Act extends to Scotland only." (Deer (Amendment) (Scotland)
  Act 1996 s.14(4); Waste, Water and Climate: Extent reader, Decision 3,
  2026-11-26). The provisions named follow the enactment they change
  (`{:same, nil, refs}`); a Schedule's "related entries" are only some of
  it, so that Schedule is withheld (`{:unread, nil, [schedule]}`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ListItems

  @form ~r/^\s*Except\s+for\s+the\s+(?:repeals?|amendments?|revocations?)(?:\s*(?:,|and|or)\s*(?:repeals?|amendments?|revocations?))*\s+(?:contained\s+in|made\s+by|in)\s+(?<items>.+?)\s*,\s*which\s+ha(?:s|ve)\s+the\s+same\s+extent\s+as\s+the\s+(?:Acts?|enactments?|instruments?)\b[^,]*,\s*this\s+(?:Act|Order|Regulations)\s+(?:shall\s+)?extends?\s+/su

  @related ~r/\s*,?\s*(?:and\s+)?the\s+related\s+entries\s+in\s+Schedule\s+(\d+[A-Z]*)\s*,?/u

  @doc "The same-extent and withheld lists of a default's leading same-extent exception."
  @spec lists([{String.t(), String.t()}], Doc.t()) :: [tuple()]
  def lists(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        %{"items" => items} <- [Regex.named_captures(@form, s)],
        list <- lists(items, ref, doc),
        uniq: true,
        do: list
  end

  defp lists(items, ref, doc) do
    related = for [_, n] <- Regex.scan(@related, items), do: "sch.#{n}"

    same =
      items
      |> String.replace(@related, " ")
      |> String.replace(~r/\s*,?\s*to\s+this\s+(?:Act|Order|Regulations)\s*$/u, "")
      |> ListItems.refs(ref, doc)

    if(same != [], do: [{:same, nil, same}], else: []) ++
      if(related != [], do: [{:unread, nil, related}], else: [])
  end
end
