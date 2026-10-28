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
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LatRef

  @doc "The placements of the one event `orphan` records, or nil."
  @spec choose(Change.t(), [Change.t()]) :: [Change.t()] | nil
  def choose(orphan, candidates) do
    events =
      candidates
      |> Enum.group_by(&Candidates.base(&1.key))
      |> Map.values()
      |> Enum.filter(&same_day?(orphan, &1))
      |> Enum.filter(&provision?(orphan, &1))
      |> Enum.filter(&family?(orphan, &1))
      |> narrow(&(operation(main(&1)) == operation(orphan)))
      |> narrow(&(heading?(orphan) or not Enum.any?(&1, fn c -> heading?(c) end)))

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
  def refs(orphan) do
    with [_, id] <- String.split(orphan.key, ":", parts: 2),
         ref when ref != nil <- Order.ref(id) do
      [ref]
    else
      _ -> Change.values(orphan, :markup, :affecting) |> List.flatten()
    end
  end

  # the provisions an event's records name: the feed's, or a note's
  defp affecting(placements),
    do:
      Enum.flat_map(placements, fn c ->
        List.flatten(Change.values(c, :feed, :affecting) ++ Change.values(c, :markup, :affecting))
      end)

  defp related?(refs, named),
    do:
      Enum.any?(named, fn a ->
        Enum.any?(refs, &(a in LatRef.ancestors(&1) or &1 in LatRef.ancestors(a)))
      end)

  defp operation(c),
    do:
      Change.value(c, :law_text, :operation) || Change.value(c, :markup, :operation) ||
        Change.value(c, :feed, :operation)

  defp depth(ref), do: length(LatRef.ancestors(ref))
end
