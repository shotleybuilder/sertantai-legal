defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Copies do
  @moduledoc """
  The new provisions a joined change makes below it carry the event
  (Decision 2, Jason with Gemini 2026-11-06, Maritime Safety: Merge). An
  amendment substituting words in a provision can make new paragraphs
  below it: 2009 c.25 Sch.21 para.34, "in subsection (6), for 'where' to
  the end substitute — (a) … (b) … (c) …", on MSA 1995 s.271(6). The
  law's text states the words change on s.271(6) and each new paragraph
  inserted. The parent joins legislation.gov.uk's one effect, whose markup
  wraps the new paragraphs too. Each new paragraph stays its own change
  (`Merge`: a whole provision made below another change is never folded
  into it), but it is the same event:

  - it takes the event's key, its own kept as an alias;
  - it takes the event's feed `date`, `partial` and `qualification`
    claims, with a feed `placed` claim naming the parent's provision (the
    feed's claims speak for that provision);
  - nothing else is carried: its operation, level and territory are the
    law text's, and its own commencement claims stay and win where they
    speak (`law-text-wins`).

  Only a law-text change whose key is an alias of a fed change on a
  provision above it. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.LatRef

  @carried [:date, :partial, :qualification]

  @doc "The changes, each law-text copy below its key's joined event carrying that event."
  @spec carry([Change.t()]) :: [Change.t()]
  def carry(changes) do
    events = events(changes)

    Enum.map(changes, fn c ->
      if Change.values(c, :feed, :by) == [], do: carry_one(c, Map.get(events, c.key, [])), else: c
    end)
  end

  # law-text key → the fed changes holding it as an alias
  defp events(changes) do
    for c <- changes,
        Change.values(c, :feed, :by) != [],
        a <- c.aliases,
        a != c.key,
        reduce: %{},
        do: (acc -> Map.update(acc, a, [c], &[c | &1]))
  end

  defp carry_one(c, []), do: c

  defp carry_one(c, events) do
    case Enum.filter(events, &(&1.target in tl(LatRef.ancestors(c.target)))) do
      [event] -> take(c, event)
      _ -> c
    end
  end

  defp take(c, event) do
    dated =
      for %Claim{source: :feed, attribute: a} = claim <- event.claims, a in @carried, do: claim

    %{
      c
      | key: event.key,
        aliases: Enum.uniq([event.key | c.aliases]),
        claims: c.claims ++ dated ++ Claim.new(:feed, :placed, event.target, event.key)
    }
  end
end
