defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.QualifiedItems do
  @moduledoc """
  The lettered items of an extent sentence that qualify their provisions
  ("(c) section 31 and Schedule 6, so far as they amend any enactment which
  extends to the Channel Islands …, extend to …"; "(d) subsections (4) and
  (5) above and Schedules 12 and 13, so far as they relate to— (i) …"):
  their provisions withheld (`{:unread, nil, refs}`), never left to the
  default the sentence ends with ("… but save as aforesaid, this Act
  extends to England and Wales only": Criminal Law Act 1977 s.65(10), CV-S05
  round 12 NEW-1). Only in that shape, a sentence ending in its default
  "save as aforesaid" (never an exception list: "This Act, except— (a) Part I
  … so far as may be necessary …, does not extend to Northern Ireland" keeps
  Part I's default, HSWA s.84(1)); only the qualified pieces of an item
  ("sections 23, 24, … and this section, … section 64(1) and Schedule 5 so
  far as they relate to …": s.64(1) and Sch.5, Criminal Justice Act 1972
  s.66). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ListItems

  @item ~r/[—–;]\s*(?:and\s*)?\(?[a-z]{1,2}\)?\s+(?<subj>(?:(?:sub)?sections?|Schedules?|Parts?|Chapters?|paragraphs?|regulations?|articles?)\s+[^;—–]*?),?\s+(?:so\s+far|in\s+so\s+far|insofar)\s+as\b/u

  @other_law ~r/\b(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4}/u

  @doc "The provisions withheld by each qualified lettered item of the unit sentences."
  @spec lists([{String.t(), String.t()}], Doc.t()) :: [{:unread, nil, [String.t()]}]
  def lists(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        s =~ ~r/\bsave\s+as\s+aforesaid\b[^.]*\bextends?\s+to\b/iu,
        [subj] <- Regex.scan(@item, s, capture: ["subj"]),
        not Regex.match?(@other_law, subj),
        refs = ListItems.read(subj <> " so far as", ref, doc).unread,
        refs != [],
        uniq: true,
        do: {:unread, nil, refs}
  end
end
