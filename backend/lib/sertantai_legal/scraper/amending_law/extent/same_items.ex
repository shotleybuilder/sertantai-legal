defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.SameItems do
  @moduledoc """
  A list's items that follow the enactments they change: "The following
  provisions of this Act do not extend to Scotland— … (e) Schedules 1 and
  2, so far as they affect any enactment which does not extend to
  Scotland"; "… extend to Northern Ireland— … (c) Schedule 1, so far as it
  amends any enactment which extends to Northern Ireland" (Further and
  Higher Education Act 1992 s.56(4), (5); Waste, Water and Climate: Extent
  reader, Decision 2, 2026-11-26). The item's qualifier names the list's
  own place and verb, so its changes go where the enactment changed does:
  the same extent (`{:same, nil, refs}`), never the list's place whole and
  never withheld. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ListItems, Places}

  @place_list Places.place_list()

  @head Regex.compile!(
          "\\bfollowing\\s+provisions\\s+of\\s+this\\s+(?:Act|Order|Regulations)\\s+(?<neg>(?:do|does|shall)\\s+not\\s+)?(?:shall\\s+)?extend\\s+(?:only\\s+)?to\\s+(?<p>(?>#{@place_list}))(?:\\s+only)?\\s*(?:,\\s*that\\s+is\\s+to\\s+say\\s*)?[—–]\\s*(?<body>.+)$",
          "su"
        )

  @item Regex.compile!(
          "^\\s*(?:and\\s*)?\\(?[a-z]{1,2}\\)?\\s+(?<subj>[A-Z].*?)\\s*,?\\s+so\\s+far\\s+as\\s+(?:it|they)\\s+(?:affects?|amends?|repeals?)\\s+any\\s+enactment\\s+which\\s+(?<neg>(?:does|do)\\s+not\\s+)?extends?\\s+to\\s+(?<p>(?>#{@place_list}))\\s*\\.?\\s*$",
          "su"
        )

  @doc "The same-extent lists of the unit sentences' qualified items."
  @spec lists([{String.t(), String.t()}], Doc.t()) :: [{:same, nil, [String.t()]}]
  def lists(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        %{"body" => body} = head <- [Regex.named_captures(@head, s)],
        item <- String.split(body, ";"),
        %{"subj" => subj} = m <- [Regex.named_captures(@item, item)],
        polarity(m) == polarity(head) and Places.places(m["p"]) == Places.places(head["p"]),
        refs = ListItems.refs(subj, ref, doc),
        refs != [],
        uniq: true,
        do: {:same, nil, refs}
  end

  @doc "The lists with the provisions `same` reads taken out of every unread one."
  @spec without_unread([tuple()], [{:same, nil, [String.t()]}]) :: [tuple()]
  def without_unread(lists, []), do: lists

  def without_unread(lists, same) do
    read = Enum.flat_map(same, &elem(&1, 2))

    Enum.flat_map(lists, fn
      {:unread, nil, refs} -> if (left = refs -- read) == [], do: [], else: [{:unread, nil, left}]
      list -> [list]
    end) ++ same
  end

  defp polarity(%{"neg" => neg}), do: neg != ""
end
