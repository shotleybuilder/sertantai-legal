defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Day do
  @moduledoc """
  One day's changes applied to the running label period (change
  vocabulary; CV-S09 round 1):

  - **Commencement.** A full one puts it in force; a partial one, partly in
    force while it was prospective; one for a territory alone puts it in
    force there and widens where it is in force — each a version (C13:
    CROW 2000 s.13, for England 2004, for Wales 2005).
  - **Repeal.** A whole-provision repeal takes its territory out (C1); none
    left → repealed "nowhere" (C2), or repealed with savings where it was
    in force (D3). Words repealed are a text change. A removal "in part"
    leaves it partly in force (C7) only when its text is retained or the
    removal is staged for purposes; with its words gone it is a words
    repeal, a version (Factories Act 1961 s.125(2)(j)).
  - **Text change** (substituted, inserted, renumbered, words repealed)
    where it applies: a version — `in_force_from` its day, `changed_by`
    every law changing the text that day (C5), `commenced_by` any law that
    brought the change into force apart from them. A whole-provision
    substitution or insertion fully in force ends a partial status: the
    partly-commenced text is gone (HSWA s.10, SI 2008/960).
  - **Application** (C6) narrows where it applies; not a version.
  - **Split** (C3): a territorial version takes its own territory from the
    day the versions split (`RestrictStartDate`), or when a text change
    confined to it takes effect.

  `in_force_from`, `changed_by` and `commenced_by` are empty while
  prospective or partly in force (D1). The period's `:_text_by` keeps the
  laws that made the current text whatever its status. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts
  alias SertantaiLegal.Scraper.Territory

  @doc "The period after `day`'s changes on `date` (`ctx`: `:self`, `:extent`)."
  @spec apply(map(), Date.t(), [map()], map()) :: map()
  # repealed, it comes back only when its text does: a later whole
  # substitution or insertion of it or an ancestor, where it still shows
  # text today (CV-S09 round 2: SI 2022/1378 reg.9(9), omitted 2023, back
  # with reg.9's 2024 substitution)
  def apply(%{status: s} = current, date, day, ctx) when s in [:repealed, :repealed_saved] do
    back =
      Enum.filter(
        day,
        &(&1.resolved.level == :provision and &1.resolved.operation in [:substituted, :inserted] and
            not &1.resolved.partial)
      )

    if back != [] and Map.get(ctx, :shows_text, false) do
      makers = Facts.makers(back, ctx.self)
      t = back |> Enum.map(& &1.resolved.territory) |> Enum.find(&is_binary/1)

      %{
        current
        | status: :in_force,
          territory: territory_back(ctx.extent, t),
          in_force_from: date,
          changed_by: makers,
          commenced_by: Facts.commencers(back, makers, ctx.self),
          tiers:
            Facts.tiers(
              current.tiers,
              [:status, :territory, :in_force_from, :changed_by, :commenced_by],
              back
            ),
          _text_by: makers
      }
    else
      current
    end
  end

  def apply(current, date, day, ctx) do
    self = ctx.self
    of = fn op -> Enum.filter(day, &(&1.resolved.operation == op)) end
    commenced = of.(:commenced)
    territorial = Enum.filter(commenced, &Facts.territory_only/1)

    {removals, word_repeals} = Enum.split_with(of.(:repealed), &(&1.resolved.level == :provision))

    # a removal in part: partly in force only with its text retained or
    # staged for purposes (C7); with the words gone, a words repeal
    {in_part, words_gone} =
      Enum.split_with(of.(:repealed_in_part), &(&1.resolved.retained or &1.resolved.partial))

    territory =
      current.territory
      |> Facts.after_repeals(removals)
      |> then(fn t ->
        Enum.reduce(of.(:applied), t, &Facts.apply_to(&2, &1.resolved.territory))
      end)
      |> commenced_for(territorial, current.status, ctx.extent)

    versions =
      Enum.filter(
        day,
        &((&1.resolved.operation in Facts.text_changes() or &1 in word_repeals or
             &1 in words_gone or Facts.marked_text?(&1)) and
            Facts.overlaps?(&1.resolved.territory, territory))
      )

    # an amendment to the amending law before it took effect made the text
    # too (C5, Jason 2026-10-30: REACH Art 127E, SI 2019/758 as amended by
    # SI 2019/858)
    earlier = if versions != [], do: Enum.filter(day, &Facts.earlier_amendment?/1), else: []

    # whole new text, fully in force, replaces a partly-commenced one
    replaced? =
      Enum.any?(
        versions,
        &(&1.resolved.level == :provision and &1.resolved.operation in [:substituted, :inserted] and
            not &1.resolved.partial)
      )

    status =
      cond do
        Enum.any?(commenced, &Facts.full?/1) -> :in_force
        current.status == :in_force_partial and replaced? -> :in_force
        commenced != [] and current.status == :prospective -> :in_force_partial
        in_part != [] and current.status == :in_force -> :in_force_partial
        true -> current.status
      end

    text_by =
      if versions != [], do: Facts.makers(versions ++ earlier, self), else: current._text_by

    cond do
      # repealed with savings: saved where it was in force (D3)
      territory == :gone and Enum.any?(removals, & &1.resolved.saved) ->
        %{
          current
          | tiers: Facts.tiers(current.tiers, [:status, :in_force_from, :changed_by], removals),
            status: :repealed_saved,
            in_force_from: nil,
            changed_by: Facts.by(removals, self),
            commenced_by: []
        }

      territory == :gone ->
        %{
          current
          | tiers:
              Facts.tiers(
                current.tiers,
                [:status, :territory, :in_force_from, :changed_by],
                removals
              ),
            status: :repealed,
            territory: "nowhere",
            in_force_from: nil,
            changed_by: Facts.by(removals, self),
            commenced_by: []
        }

      status in [:prospective, :in_force_partial] ->
        %{
          current
          | status: status,
            territory: territory,
            in_force_from: nil,
            changed_by: [],
            commenced_by: [],
            tiers: Facts.tiers(current.tiers, [:status, :territory], day),
            _text_by: text_by
        }

      versions != [] or
          (commenced != [] and (status != current.status or territory != current.territory)) ->
        %{
          current
          | tiers:
              Facts.tiers(
                current.tiers,
                [:status, :territory, :in_force_from, :changed_by, :commenced_by],
                versions ++ commenced ++ removals
              ),
            status: status,
            territory: territory,
            in_force_from: date,
            changed_by: text_by,
            commenced_by: Facts.commencers(versions ++ commenced, text_by, self),
            _text_by: text_by
        }

      territory != current.territory ->
        %{
          current
          | territory: territory,
            tiers: Facts.tiers(current.tiers, [:territory], removals)
        }

      true ->
        current
    end
  end

  defp territory_back(extent, t) when is_binary(extent) and is_binary(t),
    do: Facts.intersect(extent, t)

  defp territory_back(extent, t), do: extent || t

  # a commencement for one territory: in force there — from nothing while
  # prospective, else widening where it is in force — within its extent
  defp commenced_for(territory, [], _status, _extent), do: territory
  defp commenced_for(:gone, _territorial, _status, _extent), do: :gone

  defp commenced_for(territory, territorial, status, extent) do
    t = territorial |> Enum.map(&Facts.territory_only/1) |> Territory.union()
    widened = if status == :prospective, do: t, else: Territory.union([territory || t, t])
    if is_binary(extent), do: Facts.intersect(widened, extent), else: widened
  end

  @doc """
  A territorial version's split from its base (C3): on the day the versions
  split, or when a text change confined to its territory takes effect,
  from then its own territory.
  """
  @spec split(map(), Date.t(), [map()], String.t() | nil, Date.t() | nil) :: map()
  def split(period, _date, _day, nil, _version_start), do: period

  def split(%{status: s} = period, _date, _day, _v, _vs) when s in [:repealed, :repealed_saved],
    do: period

  def split(period, date, day, version, version_start) do
    on_split? = version_start != nil and Date.compare(date, version_start) == :eq

    confined? =
      Enum.any?(day, fn c ->
        c.resolved.operation in Facts.text_changes() and c.resolved.territory != nil and
          Territory.covers?(version, c.resolved.territory)
      end)

    if (on_split? or confined?) and is_binary(period.territory),
      do: %{period | territory: Facts.intersect(period.territory, version)},
      else: period
  end
end
