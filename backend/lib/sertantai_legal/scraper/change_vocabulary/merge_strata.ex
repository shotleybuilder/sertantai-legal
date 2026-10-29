defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeStrata do
  @moduledoc """
  The merge check's strata (change vocabulary CV-S07, Jason 2026-10-28):
  each text change of one law's merged changes in at most one of three —

  - `:J`, joined: two or more of the feed, the markup and the amending
    law's text state it (their operation claims) — an over-join risk: did
    one change take two events' claims?
  - `:U`, unjoined: the conflict report's `:unjoined` (`Conflicts`): the
    law's text alone beside legislation.gov.uk's record of a likely same
    event — a split risk, the census items;
  - `:C`, candidates: one source alone states it, beside a change another
    source alone states, by the same law, of the same operation family
    (`Merge.family/1`), on the same provision or one above or below it — a
    split the report doesn't flag (feed beside markup). A U item's twins
    are checked with it, never again here.

  The rest (one source, nothing beside it) took no merge decision.
  Commencements are not text changes and are not classed. `join_rate/1`:
  how many law-text and markup changes met a feed effect. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Conflicts, Merge}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Candidates
  alias SertantaiLegal.Scraper.LatRef

  @type stratum :: :J | :U | :C

  @sources [:feed, :markup, :law_text]

  @doc "One law's text changes in a stratum, each with it."
  @spec classify([Change.t()]) :: [{Change.t(), stratum()}]
  def classify(changes) do
    report = Conflicts.report(changes)
    unjoined = for %{kind: :unjoined} = u <- report, into: MapSet.new(), do: {u.key, u.target}

    twins =
      for %{kind: :unjoined, twins: ts} <- report,
          {key, target, _} <- ts,
          into: MapSet.new(),
          do: {key, target}

    text = Enum.filter(changes, &text?/1)

    for c <- text,
        s = stratum(c, text, unjoined, twins),
        s != nil,
        do: {c, s}
  end

  defp stratum(c, text, unjoined, twins) do
    id = {c.key, c.target}

    cond do
      length(sources(c)) >= 2 -> :J
      MapSet.member?(unjoined, id) -> :U
      MapSet.member?(twins, id) -> nil
      Enum.any?(text, &beside?(c, &1)) -> :C
      true -> nil
    end
  end

  # another source alone, by the same law, of the same family, above, at or below
  defp beside?(c, d) do
    d != c and length(sources(d)) == 1 and sources(d) != sources(c) and
      by(d) == by(c) and by(c) != nil and
      Merge.family(operation(d)) == Merge.family(operation(c)) and near?(c.target, d.target)
  end

  @doc """
  Of the law-text and markup changes, how many met a feed effect (the feed
  states them too): `%{law_text: {met, all}, markup: {met, all}}`.
  """
  @spec join_rate([Change.t()]) :: %{atom() => {non_neg_integer(), non_neg_integer()}}
  def join_rate(changes) do
    text = Enum.filter(changes, &text?/1)

    Map.new([:law_text, :markup], fn s ->
      stated = Enum.filter(text, &(s in sources(&1)))
      {s, {Enum.count(stated, &(:feed in sources(&1))), length(stated)}}
    end)
  end

  @doc """
  Keys placed under more than `max` top provisions (an over-join's shape:
  one effect's key on unrelated articles — REACH, round 4 J batch 3): each
  `{key, tops}`. A range ("ss. 11-13") spreads legitimately; a tell-tale to
  read, never a failure by itself.
  """
  @spec spread([Change.t()], pos_integer()) :: [{String.t(), [String.t()]}]
  def spread(changes, max \\ 3) do
    changes
    |> Enum.filter(&text?/1)
    |> Enum.group_by(&Candidates.base(&1.key), &top(&1.target))
    |> Enum.map(fn {key, tops} -> {key, Enum.uniq(tops)} end)
    |> Enum.filter(fn {_, tops} -> length(tops) > max end)
  end

  defp top(target),
    do: target |> LatRef.ancestors() |> List.last() |> String.replace(~r/\(.*$/, "")

  @doc "The sources stating the change (an operation claim), of the feed, markup and law text."
  @spec sources(Change.t()) :: [atom()]
  def sources(%Change{} = c), do: Enum.filter(@sources, &(Change.values(c, &1, :operation) != []))

  defp text?(c), do: Merge.family(operation(c)) in [:text, :removal] and sources(c) != []

  defp operation(%Change{resolved: %{operation: op}}) when not is_nil(op), do: op
  defp operation(c), do: Enum.find_value(@sources, &Change.value(c, &1, :operation))

  defp by(%Change{resolved: %{by: by}}) when is_binary(by), do: by

  defp by(c),
    do:
      Change.value(c, :feed, :by) || Change.value(c, :markup, :cited) ||
        Change.value(c, :law_text, :by)

  defp near?(a, b), do: a == b or a in LatRef.ancestors(b) or b in LatRef.ancestors(a)
end
