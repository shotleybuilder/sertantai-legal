defmodule SertantaiLegal.Scraper.Amendment.CheckStrata do
  @moduledoc """
  The amendment reader check's strata (change vocabulary CV-S06, the
  revised check, Jason 2026-10-28): each change the amending law's text
  states falls in one of three, from one law's merged changes —

  - `:A`, agreeing: legislation.gov.uk states it too, joined, with no value
    conflict on what this reader reads (operation, level, amending law);
  - `:D`, disagreeing: a value conflict on one of those, or the law's text
    alone states it beside legislation.gov.uk's record of a likely same
    event left apart (`Conflicts` `:unjoined`) — the census items;
  - `:L`, the law's text only, with nothing beside it.

  Dates (CV-S04) and territory (CV-S05) are other readers', so a date
  conflict alone leaves a change in `:A`. `agreement/1` counts, over every
  both-sourced change, how often the law's text and legislation.gov.uk say
  the same on each attribute. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.CheckSample
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Conflicts}
  alias SertantaiLegal.Scraper.LatRef

  @type stratum :: :A | :D | :L

  # what this reader reads; a conflict on any of them is a disagreement
  @judged [:operation, :level, :by]

  # a primary value and a derived one that say the same thing (`Conflicts`)
  @agree [{:operation, :substituted, :inserted}]

  @doc "One law's changes the law's text states, each with its stratum."
  @spec classify([Change.t()]) :: [{Change.t(), stratum()}]
  def classify(changes) do
    unjoined =
      for %{kind: :unjoined} = u <- Conflicts.report(changes),
          into: MapSet.new(),
          do: {u.key, u.target}

    for c <- changes,
        Change.values(c, :law_text, :operation) != [],
        do: {c, stratum(c, unjoined)}
  end

  defp stratum(c, unjoined) do
    cond do
      conflict?(c) or MapSet.member?(unjoined, {c.key, c.target}) -> :D
      CheckSample.stated_by(c) == "both" -> :A
      true -> :L
    end
  end

  defp conflict?(%Change{resolved: nil}), do: false

  defp conflict?(%Change{resolved: r}),
    do: Enum.any?(r.conflicts, fn {attribute, _, _} -> attribute in @judged end)

  @doc """
  Over the both-sourced changes: per attribute (operation, level, amending
  law, target), `{agree, compared}` — compared where both sides state it.
  The target agrees where the law's text placed the change where it sits
  (or placed nothing apart).
  """
  @spec agreement([Change.t()]) :: %{atom() => {non_neg_integer(), non_neg_integer()}}
  def agreement(changes) do
    both =
      Enum.filter(
        changes,
        &(Change.values(&1, :law_text, :operation) != [] and CheckSample.stated_by(&1) == "both")
      )

    zero = Map.new(@judged ++ [:target], &{&1, {0, 0}})

    for c <- both, {attribute, same} <- compare(c), reduce: zero do
      acc -> Map.update!(acc, attribute, fn {a, n} -> {a + if(same, do: 1, else: 0), n + 1} end)
    end
  end

  defp compare(c) do
    values =
      for attribute <- @judged,
          text = Change.values(c, :law_text, attribute),
          derived = Change.values(c, :feed, attribute) ++ Change.values(c, :markup, attribute),
          text != [] and derived != [],
          do: {attribute, Enum.any?(text, &agrees?(c, attribute, &1, derived))}

    placed = Change.value(c, :law_text, :placed)
    values ++ [{:target, placed in [nil, c.target]}]
  end

  defp agrees?(c, attribute, v, derived),
    do:
      Enum.any?(derived, fn d ->
        d == v or {attribute, v, d} in @agree or placed_above?(c, attribute, v, d)
      end)

  # words the law's text changes in a provision above are a whole provision here
  defp placed_above?(c, :level, :words, :provision) do
    case Change.value(c, :law_text, :placed) do
      nil -> false
      placed -> placed in tl(LatRef.ancestors(c.target))
    end
  end

  defp placed_above?(_c, _attribute, _v, _d), do: false
end
