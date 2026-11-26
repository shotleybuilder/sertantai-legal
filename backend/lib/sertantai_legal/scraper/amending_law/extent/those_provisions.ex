defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ThoseProvisions do
  @moduledoc """
  The provisions named before "but apart from those provisions this Act does
  not extend to P": they reach P too (Animal Health Act 1981 s.97(2):
  "Sections 93 and 95(6) above apply to Northern Ireland, and Schedule 6 to
  this Act, so far as it repeals provisions of the Diseases of Animals Act
  1950 which applied to Northern Ireland, but apart from those provisions
  this Act does not extend to Northern Ireland"; Waste, Water and Climate:
  Extent reader, Decision 3, 2026-11-26). "Apply to" there is the extent
  the closing words take away. A provision qualified by the enactments it
  repeals or amends reaching P follows them (`{:same, nil, refs}`); the
  others extend also to P (`{:also, P, refs}`). The default is the closing
  words' (`Extent.Default`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ListItems, Places}

  @place_list Places.place_list()

  @form Regex.compile!(
          "^\\s*(?<plain>(?:Sections?|Regulations?|Articles?|Schedules?|Parts?)\\s+.+?)\\s+(?:above\\s+|below\\s+)?(?:apply|applies|extends?|extend)\\s+to\\s+(?<p>(?>#{@place_list}))\\s*,\\s*(?:and\\s+(?<q>.+?)\\s*,\\s*so\\s+far\\s+as\\s+(?:it|they)\\s+(?:repeals?|amends?|revokes?)\\s+[^,]*?\\bwhich\\s+(?:applied|appl(?:y|ies)|extends?|extended)\\s+to\\s+(?<p2>(?>#{@place_list}))\\s*,\\s*)?but\\s+apart\\s+from\\s+th(?:ose|ese)\\s+provisions\\s*,?\\s+this\\s+(?:Act|Order|Regulations)\\s+(?:does|shall)\\s+not\\s+extend\\s+to\\s+(?<p3>(?>#{@place_list}))\\s*\\.?\\s*$",
          "su"
        )

  @doc "The lists of the unit sentences naming the provisions apart from which the law does not reach a place."
  @spec lists([{String.t(), String.t()}], Doc.t()) :: [tuple()]
  def lists(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        %{"plain" => _} = m <- [Regex.named_captures(@form, s)],
        Places.places(m["p"]) == Places.places(m["p3"]),
        list <- lists(m, ref, doc),
        uniq: true,
        do: list
  end

  defp lists(%{"plain" => plain, "p" => p, "q" => q} = m, ref, doc) do
    also = ListItems.refs(plain, ref, doc)

    same =
      if q != "" and Places.places(m["p2"]) == Places.places(p),
        do: ListItems.refs(q, ref, doc),
        else: []

    if(also != [], do: [{:also, Places.places(p), also}], else: []) ++
      if(same != [], do: [{:same, nil, same}], else: [])
  end
end
