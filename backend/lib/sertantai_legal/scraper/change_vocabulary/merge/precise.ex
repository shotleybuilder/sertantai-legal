defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Precise do
  @moduledoc """
  One effect id is one event, wherever its sources place it (change
  vocabulary, CV-S07; split from `Merge`, CV-S08). The markup places it
  precisely (the evidence table's target order): a markup change with no
  feed claims of its own takes the event's feed facts (date, law,
  territory) from the feed's change of the same id — on a provision above
  it, or beside it. A feed change with the markup's below it is the
  coarser record and goes.

  A change the markup places only by its note ref claims no level: a note
  is a pointer (CV-S08 round 1: commencement stages, whole provisions
  repealed as dots, a Part modified, all made "words"). The one exception
  is a note on a provision beside the one the feed names — the "and" SI
  2019/734 omits from Forestry Act 1967 s.1(4)(a), which the feed records
  on s.1(4)(b): the change there is in its words.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Candidates
  alias SertantaiLegal.Scraper.LatRef

  @doc "The changes with each event's markup placements given its feed facts."
  @spec precise([Change.t()]) :: [Change.t()]
  def precise(changes) do
    # where the feed names each event (its stages, `id@date`, included)
    fed =
      for c <- changes,
          Change.values(c, :feed, :by) != [],
          reduce: %{},
          do: (acc -> Map.update(acc, Candidates.base(c.key), [c.target], &[c.target | &1]))

    changes
    |> Enum.group_by(& &1.key)
    |> Enum.flat_map(fn {key, group} ->
      {marked, fed_only} = Enum.split_with(group, &marked?/1)
      # the event's facts, from the first change of it the feed records
      facts =
        case Enum.find(group, &(Change.values(&1, :feed, :by) != [])) do
          nil -> []
          c -> Enum.filter(c.claims, &(&1.source in [:feed, :law])) |> fed_at(c)
        end

      fed_targets = Map.get(fed, Candidates.base(key), [])

      marked =
        Enum.map(marked, fn m ->
          m =
            if Change.values(m, :feed, :by) == [],
              do: %{m | claims: m.claims ++ here(facts, m.target)},
              else: m

          if Change.values(m, :markup, :operation) == [] and beside?(m.target, fed_targets),
            do: %{m | claims: m.claims ++ Claim.new(:markup, :level, :words, m.key)},
            else: m
        end)

      kept =
        Enum.reject(fed_only, fn f ->
          Enum.any?(marked, &(f.target in tl(LatRef.ancestors(&1.target))))
        end)

      marked ++ kept
    end)
  end

  @doc "True when the CLML change markup places the change."
  @spec marked?(Change.t()) :: boolean()
  def marked?(c),
    do: Change.values(c, :markup, :operation) != [] or Change.values(c, :markup, :placed) != []

  # where the feed placed the facts (its level speaks for that provision only)
  defp fed_at(claims, c) do
    if Enum.any?(claims, &(&1.attribute == :placed)),
      do: claims,
      else: claims ++ Claim.new(:feed, :placed, c.target, c.key)
  end

  # the facts on the markup's provision: the feed's placement only when elsewhere
  defp here(facts, target),
    do:
      Enum.reject(facts, &(&1.source == :feed and &1.attribute == :placed and &1.value == target))

  # the feed names a sibling of the target, never the target or a provision
  # above it
  defp beside?(target, fed_targets) do
    above = LatRef.ancestors(target)

    fed_targets != [] and Enum.all?(fed_targets, &(&1 not in above)) and
      Enum.any?(fed_targets, &(parent(&1) != nil and parent(&1) == parent(target)))
  end

  defp parent(target) do
    case LatRef.ancestors(target) do
      [_, parent | _] -> parent
      _ -> nil
    end
  end
end
