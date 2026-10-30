defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Undated do
  @moduledoc """
  What the label fold makes of whole changes no source dates (CV-S09
  rounds 2–3), for a provision's start (`Label.Start`):

  - an undated whole insertion (its own, or its nearest ancestor's) made
    its text — by another law, its own law's commencements never reach it
    (HSWA s.25A(1), s.34(6));
  - its own undated substitution after that made its text since (CLP Art
    25(7)); on a start no source dates, an undated words change too (REACH
    Art 118(2)(c));
  - an undated whole repeal with its text gone: repealed (CLP Art 25(5)).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Label}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts

  @doc "The first period with undated whole repeals applied: repealed, or in force where it remains (C1)."
  @spec repealed_at_start(map(), [Change.t()], String.t() | nil) :: map()
  def repealed_at_start(period, [], _self), do: period

  def repealed_at_start(period, gone, self) do
    case Facts.after_repeals(period.territory, gone) do
      :gone ->
        %{
          period
          | status: :repealed,
            territory: "nowhere",
            in_force_from: nil,
            changed_by: Facts.by(gone, self),
            commenced_by: [],
            tiers: Facts.tiers(period.tiers, [:status, :territory, :changed_by], gone)
        }

      t ->
        %{period | territory: t, tiers: Facts.tiers(period.tiers, [:territory], gone)}
    end
  end

  @doc "Undated whole-provision repeals of it or an ancestor, where its text no longer shows."
  @spec repeals(String.t(), [Change.t()], map()) :: [Change.t()]
  def repeals(id, changes, provision) do
    if Map.get(provision, :shows_text, true),
      do: [],
      else:
        Enum.filter(
          changes,
          &(&1.resolved.date == nil and &1.resolved.operation == :repealed and
              &1.resolved.level == :provision and
              Label.reaches?(&1, id))
        )
  end

  @doc """
  The nearest whole insertion of `id` (or an ancestor) by another law that
  no source dates: the provision was not in its law's own text, so that
  law's commencements never reach it (CV-S09 round 3: HSWA s.34(6),
  inserted by the Gas Act 1986, had read commenced in 1975). nil if none.
  """
  @spec insertion(String.t(), [Change.t()], String.t() | nil) :: Change.t() | nil
  def insertion(id, changes, self) do
    id
    |> makers(changes)
    |> Enum.find(&(stated_insertion?(&1) and &1.resolved.by not in [nil, self]))
  end

  @doc "The undated whole changes that made its text: its own undated substitutions, else the nearest undated whole insertion."
  @spec makers(String.t(), [Change.t()]) :: [Change.t()]
  def makers(id, changes) do
    undated =
      Enum.filter(
        changes,
        &(&1.resolved.date == nil and &1.resolved.level == :provision and
            Label.reaches?(&1, id))
      )

    case Enum.filter(undated, &(&1.target == id and &1.resolved.operation == :substituted)) do
      [] -> Enum.filter(undated, &insertion?/1) |> nearest()
      substitutions -> substitutions
    end
  end

  @doc "Its own undated words-level text changes."
  @spec words(String.t(), [Change.t()]) :: [Change.t()]
  def words(id, changes),
    do:
      Enum.filter(
        changes,
        &(&1.target == id and &1.resolved.date == nil and &1.resolved.level == :words and
            &1.resolved.operation in Facts.text_changes())
      )

  # the insertion on the nearest provision: its own, else its closest ancestor's
  defp nearest([]), do: []

  defp nearest(insertions) do
    deepest = insertions |> Enum.map(&depth(&1.target)) |> Enum.max()
    Enum.filter(insertions, &(depth(&1.target) == deepest))
  end

  defp depth("*"), do: 0
  defp depth(target), do: length(SertantaiLegal.Scraper.LatRef.ancestors(target))

  @doc """
  On a start no source dates, the nearest undated whole substitution of an
  ancestor made its text, unless its own undated makers already did (CV-S09
  round 4: REACH Art 40(1)(a), Art 40(1) substituted by CLP).
  """
  @spec ancestor_substitutions(String.t(), [Change.t()], [Change.t()]) :: [Change.t()]
  def ancestor_substitutions(_id, _changes, [_ | _]), do: []

  def ancestor_substitutions(id, changes, []) do
    changes
    |> Enum.filter(
      &(&1.resolved.date == nil and &1.resolved.operation == :substituted and
          &1.resolved.level == :provision and &1.target != id and Label.reaches?(&1, id))
    )
    |> nearest()
  end

  defp insertion?(c), do: c.resolved.operation == :inserted and c.resolved.level == :provision

  # an insertion the law's text or the feed states: a legacy markup Addition
  # alone credits its law (CV-S08, Jason 2026-10-29: number wrapped =
  # inserted; Forestry Act 1967 s.1(4)(a)) but is no proof the provision
  # was never in its own law — it also marks substitutions (EPA 1975
  # Sch.15 "for subsection (1) substitute" on HSWA s.15(1): CV-S09 round 4)
  defp stated_insertion?(c), do: insertion?(c) and c.resolved.sources[:operation] != :markup
end
