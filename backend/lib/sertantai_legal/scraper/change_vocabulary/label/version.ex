defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Version do
  @moduledoc """
  A territorial version's own territory in the label fold (C3): from the
  day the versions split, and when a text change confined to its territory
  narrows it. Split from `Label.Day` (CV-S09 round 9). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts
  alias SertantaiLegal.Scraper.{LatRef, Territory}

  @doc """
  On the day a territorial version splits (C3), the period as that version
  before the day's changes: its own territory, whatever narrowed the shared
  history (C14: HSWA s.28(9)[NI], inserted by an E+W+S Act, had never
  split: CV-S09 round 4). The day's changes then act on the version alone
  (CV-S09 round 9: HSWA s.14(7)[NI], split the day SI 2016/1142 repealed it
  E+W+NI, had read in force NI). The split rests on the markup's versions:
  derived.
  """
  @spec enter(map(), Date.t(), String.t() | nil, Date.t() | nil) :: map()
  def enter(period, _date, nil, _version_start), do: period
  def enter(period, _date, _version, nil), do: period

  def enter(%{status: s} = period, _date, _v, _vs) when s in [:repealed, :repealed_saved],
    do: period

  def enter(period, date, version, version_start) do
    if Date.compare(date, version_start) == :eq and period.territory != version,
      do: %{period | territory: version, tiers: Map.put(period.tiers, :territory, :derived)},
      else: period
  end

  @doc """
  The first day the versions' texts diverge (C3; CV-06 round 1, R4): a
  dated text change on `base` or under it whose change markup sits in some
  of the `versions` and not the others (HSWA s.16: s.16(1A), inserted for
  E+W+S on 2006-04-01, is in the [E+W+S] text only, though
  legislation.gov.uk starts its versions in 2015). A territory alone is no
  evidence: SI 2015/1682 reads E+W+S, yet its words are in SI 2008/1597's
  NI text (round 2). Nil when none.
  """
  @spec diverged(String.t(), [String.t()], [map()], map()) :: Date.t() | nil
  def diverged(base, versions, changes, facts),
    do: diverged(top(base, facts), versions, changes)

  @doc """
  The highest provision holding `base` that has versions (`facts`: each
  row's `:versions`): its texts part for every row under it (CV-06 round 2:
  HSWA s.16(1)(b)[E+W+S] parts when s.16 does, 2006-04-01, though its own
  words change only later).
  """
  @spec top(String.t(), map()) :: String.t()
  def top(base, facts) do
    base
    |> LatRef.ancestors()
    |> Enum.filter(&match?([_, _ | _], facts |> Map.get(&1, %{}) |> Map.get(:versions, [])))
    |> List.last()
    |> Kernel.||(base)
  end

  @doc "`diverged/4` on `base` itself (its own versions, whatever holds it)."
  @spec diverged(String.t(), [String.t()], [map()]) :: Date.t() | nil
  def diverged(_base, versions, _changes) when length(versions) < 2, do: nil

  def diverged(base, versions, changes) do
    changes
    |> Enum.filter(fn c ->
      in_versions = c |> Change.values(:markup, :in_versions) |> List.flatten()

      c.resolved.date != nil and c.resolved.operation in Facts.text_changes() and
        base in LatRef.ancestors(c.target) and in_versions != [] and
        Enum.any?(versions, &(&1 not in in_versions))
    end)
    |> Enum.map(& &1.resolved.date)
    |> Enum.min(Date, fn -> nil end)
  end

  @doc """
  A territorial version narrowed by a text change confined to its
  territory (C3); its own territory from the split is `enter/4`'s.
  """
  @spec split(map(), Date.t(), [map()], String.t() | nil, Date.t() | nil) :: map()
  def split(period, _date, _day, nil, _version_start), do: period

  def split(%{status: s} = period, _date, _day, _v, _vs) when s in [:repealed, :repealed_saved],
    do: period

  def split(period, _date, day, version, _version_start) do
    # a change confined to the version narrows it (its own territory from
    # the split is `enter/4`'s)
    # — and only when the day's other text changes stay within it too: laws
    # changing the text the same day for other territories keep the union
    # (CV-S09 round 10: HSWA s.51A(3)(b), asp 2012/8 for S and SI 2013/602
    # for E+W+NI on 2013-04-01, months before the versions split)
    text = Enum.filter(day, &(&1.resolved.operation in Facts.text_changes()))

    confined? =
      Enum.any?(text, fn c ->
        c.resolved.territory != nil and Territory.covers?(version, c.resolved.territory)
      end) and
        Enum.all?(text, fn c ->
          c.resolved.territory == nil or Territory.covers?(version, c.resolved.territory)
        end)

    narrowed = if is_binary(period.territory), do: Facts.intersect(period.territory, version)

    if confined? and narrowed != nil and narrowed != period.territory,
      do: %{period | territory: narrowed},
      else: period
  end
end
