defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Version do
  @moduledoc """
  A territorial version's own territory in the label fold (C3): from the
  day the versions split, and when a text change confined to its territory
  narrows it. Split from `Label.Day` (CV-S09 round 9). Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts
  alias SertantaiLegal.Scraper.Territory

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
    confined? =
      Enum.any?(day, fn c ->
        c.resolved.operation in Facts.text_changes() and c.resolved.territory != nil and
          Territory.covers?(version, c.resolved.territory)
      end)

    narrowed = if is_binary(period.territory), do: Facts.intersect(period.territory, version)

    if confined? and narrowed != nil and narrowed != period.territory,
      do: %{period | territory: narrowed},
      else: period
  end
end
