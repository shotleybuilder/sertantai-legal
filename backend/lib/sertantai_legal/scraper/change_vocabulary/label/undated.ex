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
  - an undated whole repeal with its text gone: repealed (CLP Art 25(5)),
    unless the feed holds it prospective and unapplied (Ports Act 1991 s.29).

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

  @doc """
  `changes` with each undated whole repeal by a law made after `start`
  dated: at that law's first dated record on its target or anything
  holding it, else its making (`made_of`) — never from a start before the
  repealer existed (Environmental Protection: Label fold, Decision 7: EPA
  ss.30–50, s.143, repealed by EA 1995 Sch.24 with no source dating it).
  The date is the fold's, a lower bound: tiered derived.
  """
  # only where its text no longer shows, as an undated repeal at the start
  # (`repeals/3`): a row still showing its text was never repealed by it
  @spec date_late_repeals([Change.t()], map()) :: [Change.t()]
  def date_late_repeals(changes, %{start: start} = provision) do
    made_of = Map.get(provision, :made_of, %{})

    if map_size(made_of) > 0 and not Map.get(provision, :shows_text, true),
      do: Enum.map(changes, &date_late_repeal(&1, changes, start, made_of)),
      else: changes
  end

  defp date_late_repeal(
         %Change{resolved: %{date: nil, operation: :repealed, level: :provision, by: by}} = c,
         changes,
         start,
         made_of
       )
       when is_binary(by) do
    with %Date{} = made <- Map.get(made_of, by),
         :gt <- Date.compare(made, start),
         %Date{} = d <- first_record(by, c.target, changes) || made do
      %{c | resolved: %{c.resolved | date: d, tiers: Map.put(c.resolved.tiers, :date, :derived)}}
    else
      _ -> c
    end
  end

  defp date_late_repeal(c, _changes, _start, _made_of), do: c

  defp first_record(by, target, changes) do
    held = [target, "*" | SertantaiLegal.Scraper.LatRef.ancestors(target)]

    changes
    |> Enum.filter(&(&1.resolved.by == by and &1.resolved.date != nil and &1.target in held))
    |> Enum.map(& &1.resolved.date)
    |> Enum.min(Date, fn -> nil end)
  end

  @doc """
  Undated whole-provision repeals of it or an ancestor, where its text no
  longer shows — never one the feed holds prospective and unapplied: it
  repealed nothing yet (Ports Act 1991 s.29, a heading row, by the Local
  Government Act 2003 Sch.8 commenced by order: it read repealed from 1991).
  """
  @spec repeals(String.t(), [Change.t()], map()) :: [Change.t()]
  def repeals(id, changes, provision) do
    if Map.get(provision, :shows_text, true),
      do: [],
      else:
        Enum.filter(
          changes,
          &(&1.resolved.date == nil and &1.resolved.operation == :repealed and
              &1.resolved.level == :provision and
              Label.reaches?(&1, id) and not pending?(&1))
        )
  end

  @doc """
  The nearest whole insertion of `id` (or an ancestor) by another law that
  no source dates: the provision was not in its law's own text, so that
  law's commencements never reach it (CV-S09 round 3: HSWA s.34(6),
  inserted by the Gas Act 1986, had read commenced in 1975). nil if none.
  """
  @spec insertion(String.t(), [Change.t()], String.t() | nil) :: Change.t() | nil
  # an own undated substitution beside it doesn't hide it (CV-S09 round 5:
  # CLP Art 25(7), inserted by 2017/542 then replaced by 2020/11, lost its
  # start's tiers)
  def insertion(id, changes, self) do
    id
    |> whole(changes)
    |> Enum.filter(&insertion?/1)
    |> nearest()
    |> Enum.find(&(stated_insertion?(&1) and &1.resolved.by not in [nil, self]))
  end

  @doc "The undated whole changes that made its text: its own undated substitutions, else the nearest undated whole insertion."
  @spec makers(String.t(), [Change.t()]) :: [Change.t()]
  def makers(id, changes) do
    undated = whole(id, changes)

    case Enum.filter(undated, &(&1.target == id and &1.resolved.operation == :substituted)) do
      [] -> Enum.filter(undated, &insertion?/1) |> nearest()
      substitutions -> substitutions
    end
  end

  # the undated whole-provision changes reaching it — never one the feed
  # holds prospective and unapplied: not in the text, it made nothing yet
  # (PRA 2002 s.95's insertion of HSWA s.51A(2A)–(2B), never in force:
  # CV-06 round 2, R10)
  defp whole(id, changes),
    do:
      Enum.filter(
        changes,
        &(&1.resolved.date == nil and &1.resolved.level == :provision and
            Label.reaches?(&1, id) and not pending?(&1))
      )

  defp pending?(c),
    do:
      Change.values(c, :feed, :prospective) == [true] and
        Change.values(c, :feed, :applied) == [false]

  @doc """
  Its own undated words-level text changes — a words repeal among them, as
  on a dated day (CV-S09 round 5: CLP Art 54, paras 3–4 deleted by EU
  2019/1243).
  """
  @spec words(String.t(), [Change.t()]) :: [Change.t()]
  def words(id, changes),
    do:
      Enum.filter(
        changes,
        &(&1.target == id and &1.resolved.date == nil and &1.resolved.level == :words and
            &1.resolved.operation in [:repealed | Facts.text_changes()])
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
