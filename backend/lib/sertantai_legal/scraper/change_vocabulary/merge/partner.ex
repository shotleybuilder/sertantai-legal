defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Partner do
  @moduledoc """
  The one event an id-less record (the amending law's text, legacy or
  unmatched markup) is a record of, among the candidates near it by the
  same amending law (CV-S07 round 2, `docs/CHANGE-IDENTITY-DESIGN.md`).
  The candidates are grouped into events by effect id, stages together
  (`Candidates.base/1`), then narrowed in order:

  1. **the day:** a dated record keeps an event with a stage of its day, or
     a staged event (it joins its first stage); a single record of another
     day is another event (Coronavirus Act 2020 s.78: sunset 2022, NI
     continuation 2024);
  2. **the amending provision:** where both sides name it (the law text's
     key, the feed's affecting provisions, the markup note's citation),
     they must be related, always (HSWA s.50(3): feed art.16(4)(a) never
     with markup citing 16(4)(b));
  3. **the operation family** (text change, removal), unless one side has
     none (the feed's "amended": HSWA s.52(1)), or both name the same
     amending provision (the markup's Addition for a repeal: HSWA s.84(5),
     Jason 2026-10-28);
  4. several left: **the exact operation** (NISR 2015/339 reg.34(2)(b):
     "add" and "substitute");
  5. several left: **a body effect over a heading effect**, unless the
     record is itself a heading change (SI 2019/696 Sch.12 para 21(a)).

  One event left is the partner; none or several, the record stays apart
  (a visible gap). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Candidates
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LatRef

  @doc "The placements of the one event `orphan` records, or nil."
  @spec choose(Change.t(), [Change.t()]) :: [Change.t()] | nil
  def choose(orphan, candidates) do
    # a note one of whose pieces joined an effect is that effect's event
    # (HSWA s.50(3): note c19974541 on s.50(3), (a) and (b), one piece joined
    # the feed's effect — round 4)
    joined_notes =
      for c <- candidates,
          not match?({:note, _}, Candidates.event(c)),
          d <- Change.values(c, :markup, :note_digest),
          into: %{},
          do: {d, Candidates.event(c)}

    events =
      candidates
      |> Enum.group_by(fn c ->
        case Candidates.event(c) do
          {:note, d} -> Map.get(joined_notes, d, {:note, d})
          e -> e
        end
      end)
      |> Map.values()
      |> Enum.filter(&same_day?(orphan, &1))
      |> by_provision(orphan)
      |> Enum.filter(&family?(orphan, &1))
      # (the family waived for one amending provision, its own still first:
      # HSWA s.53(1), round 3)
      |> narrow(&(Merge.family(operation(main(&1))) == Merge.family(operation(orphan))))
      |> narrow(&(plain(operation(main(&1))) == plain(operation(orphan))))
      |> narrow(&agrees?(orphan, main(&1)))
      |> narrow(&(Enum.any?(&1, fn c -> heading?(c) end) == heading?(orphan)))
      # (an effect placed here only because its finer place has no row ranks
      # below one placed here: REACH art.14(2), round 3)
      |> narrow(&(not Enum.any?(&1, fn c -> Change.values(c, :feed, :finer_unheld) != [] end)))
      # (then the event on the record's own provision before one above or
      # below it: a whole-paragraph markup is the paragraph's effect, not a
      # point's — REACH art.14(2), round 5)
      |> narrow(&Enum.any?(&1, fn c -> c.target == orphan.target end))

    case events do
      [one] -> one
      _ -> nil
    end
  end

  @doc """
  The event's placement the record joins: of its day, else its main record
  (the effect's own key); then on the record's provision, else where the
  markup placed it, else the nearest.
  """
  @spec placement([Change.t()], Change.t()) :: Change.t()
  def placement(placements, orphan) do
    pool =
      case Enum.filter(placements, &same_date?(orphan, &1)) do
        [] -> Enum.filter(placements, &(&1.key == Candidates.base(&1.key)))
        dated -> dated
      end

    pool = if pool == [], do: placements, else: pool

    Enum.find(pool, &(&1.target == orphan.target)) ||
      Enum.find(pool, &Merge.marked?/1) ||
      Enum.min_by(pool, &abs(depth(&1.target) - depth(orphan.target)))
  end

  # (a removal in part is a removal) the exact operation first; then the
  # markup's Addition for a substitution (`Conflicts` `@agree`) — only a
  # markup insertion meets a substitution, never the reverse (COSHH reg.2(1)
  # by SI 2009/716: a markup Substitution keeps the substituted event, round 4)
  defp agrees?(a, b) do
    {x, y} = {plain(operation(a)), plain(operation(b))}

    x == y or (x == :inserted and y == :substituted and markup_op?(a)) or
      (y == :inserted and x == :substituted and markup_op?(b))
  end

  defp plain(:repealed_in_part), do: :repealed
  defp plain(op), do: op

  defp markup_op?(c),
    do:
      Change.values(c, :law_text, :operation) == [] and Change.values(c, :feed, :operation) == []

  # a narrowing applies only where it leaves one or more
  defp narrow(events, keep) when length(events) > 1 do
    case Enum.filter(events, keep) do
      [] -> events
      kept -> kept
    end
  end

  defp narrow(events, _keep), do: events

  defp same_day?(orphan, placements) do
    case Change.value(orphan, :law_text, :date) do
      %Date{} ->
        staged?(placements) or Enum.any?(placements, &(same_date?(orphan, &1) != false))

      _ ->
        true
    end
  end

  # one effect in stages (`id@date` keys beside its own)
  defp staged?(placements), do: placements |> Enum.map(& &1.key) |> Enum.uniq() |> length() > 1

  # true / false where both are dated, nil where either isn't
  defp same_date?(orphan, c) do
    case {Change.value(orphan, :law_text, :date), Change.value(c, :feed, :date)} do
      {%Date{} = a, %Date{} = b} -> Date.compare(a, b) == :eq
      _ -> nil
    end
  end

  # the amending provision must agree where both sides name it — unless the
  # record's only name is its note's (a pointer) and the law's own text
  # places one event on the record's provision, the same day: the note cites
  # the wrong paragraph (CV-S09 round 6: HSWA s.55(6)(b), note "art. 18(3)"
  # of SI 2008/960, whose art.18(4) the law's text shows making the change)
  defp by_provision(events, orphan) do
    case Enum.filter(events, &provision?(orphan, &1)) do
      [] when events != [] ->
        if key_refs(orphan.key) == [] and Change.values(orphan, :law_text, :by) == [] do
          case Enum.filter(events, &stated_here?(&1, orphan)) do
            [one] -> [one]
            _ -> []
          end
        else
          []
        end

      kept ->
        kept
    end
  end

  defp stated_here?(placements, orphan),
    do:
      Enum.any?(placements, fn c ->
        c.target == orphan.target and
          (Change.values(c, :law_text, :by) != [] or Change.values(c, :feed, :by) != []) and
          dated_alike?(orphan, c)
      end)

  # both dated, the same day (the record's date by its law, or its own
  # commencement found)
  defp dated_alike?(orphan, c) do
    a = Change.value(orphan, :law_text, :date) || Change.value(orphan, :commencement, :date)
    b = Change.value(c, :feed, :date) || Change.value(c, :commencement, :date)
    match?(%Date{}, a) and match?(%Date{}, b) and Date.compare(a, b) == :eq
  end

  defp provision?(orphan, placements) do
    case {refs(orphan), affecting(placements)} do
      {[], _} -> true
      {_, []} -> true
      {refs, named} -> related?(refs, named)
    end
  end

  defp family?(orphan, placements) do
    {a, b} = {Merge.family(operation(orphan)), Merge.family(operation(main(placements)))}

    a == b or a == nil or b == nil or
      (refs(orphan) != [] and affecting(placements) != [] and
         related?(refs(orphan), affecting(placements)))
  end

  # the event's own record (the effect's key), else its first
  defp main(placements),
    do: Enum.find(placements, hd(placements), &(&1.key == Candidates.base(&1.key)))

  defp heading?(c),
    do: Change.value(c, :feed, :heading) == true or Change.value(c, :markup, :heading) == true

  @doc """
  The amending provisions a record names: the law text's own (its key is
  "law:element id"), else the provisions its note cites (markup).
  """
  @spec refs(Change.t()) :: [String.t()]
  def refs(%Change{key: key} = orphan) do
    case key_refs(key) do
      [] -> Change.values(orphan, :markup, :affecting) |> List.flatten()
      refs -> refs
    end
  end

  @doc "The amending provision a law-text record's key names (\"law:element id\"), as refs; [] for another key."
  @spec key_refs(String.t()) :: [String.t()]
  def key_refs(key) do
    with [_, id] <- String.split(AmendingLaw.provision_key(key), ":", parts: 2),
         ref when ref != nil <- Order.ref(id) do
      [ref]
    else
      _ -> []
    end
  end

  # the provisions an event's records name: the feed's, or a note's
  defp affecting(placements),
    do:
      Enum.flat_map(placements, fn c ->
        List.flatten(Change.values(c, :feed, :affecting) ++ Change.values(c, :markup, :affecting))
      end)

  # one amending provision within the other: brackets ("para. 8(a)(i)" in
  # "para. 8"), a Schedule's Part or paragraph in the Schedule
  # ("sch.15.pt.1" in "sch.15", round 3); an Order's articles are named
  # "art." by a note and "reg." by the feed (SSI 2010/428, round 3)
  defp related?(refs, named),
    do:
      Enum.any?(named, fn a ->
        Enum.any?(refs, &(within?(a, &1) or within?(&1, a)))
      end)

  defp within?(a, b), do: canonical(a) in Enum.map(chain(b), &canonical/1)

  defp chain(ref) do
    bare = String.replace(ref, ~r/\(.*$/, "")
    parts = String.split(bare, ".")

    dotted =
      for n <- 2..length(parts)//2,
          n <= length(parts),
          do: parts |> Enum.take(n) |> Enum.join(".")

    Enum.uniq(
      LatRef.ancestors(ref) ++
        dotted ++ (dotted |> Enum.map(&String.replace(&1, ~r/\.pt\.[^.]+/, "")))
    )
  end

  defp canonical(ref), do: String.replace(ref, ~r/^(?:art|reg|rule)\./, "p.")

  defp operation(c),
    do:
      Change.value(c, :law_text, :operation) || Change.value(c, :markup, :operation) ||
        Change.value(c, :feed, :operation)

  defp depth(ref), do: length(LatRef.ancestors(ref))
end
