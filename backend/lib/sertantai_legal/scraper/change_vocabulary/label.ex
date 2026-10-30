defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label do
  @moduledoc """
  A provision's label periods folded from its resolved changes (change
  vocabulary). The changes that reach a provision: those on it, and
  provision-level changes on its ancestors — never a change on a child
  (C9). Thin orchestrator:

  - `Label.Start` — when the provision begins (its law's start, or a later
    insertion of it) and what it is then;
  - `Label.Day` — each later day's changes in date order (commencement,
    repeal, removal in part, text change, application), and a territorial
    version's split (C3);
  - `Label.Facts` — territory, the laws a field credits, tiers.

  Each period: `status`, `territory` ("nowhere": C2), `in_force_from` (when
  the current text took effect, D1), `changed_by` (the laws that made it,
  C5), `commenced_by` (the law that brought it into force apart from them —
  a commencing order; Jason 2026-10-30), and each field's tier (`:primary`
  the legal text, `:derived` legislation.gov.uk; Jason 2026-10-21). A day
  that changes no field opens no period.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.{Day, Facts, Start}
  alias SertantaiLegal.Scraper.LatRef

  @type period :: %{
          valid_from: Date.t(),
          valid_to: Date.t() | nil,
          status: atom(),
          in_force_from: Date.t() | nil,
          changed_by: [String.t()],
          commenced_by: [String.t()],
          territory: String.t() | nil,
          tiers: %{atom() => :primary | :derived | nil}
        }

  @type provision :: %{
          required(:extent) => String.t() | nil,
          required(:start) => Date.t(),
          optional(:law) => String.t(),
          optional(:prospective) => boolean(),
          optional(:valid) => Date.t() | nil,
          optional(:start_dated) => boolean(),
          optional(:start_tier) => :primary | :derived,
          optional(:version) => String.t(),
          optional(:version_start) => Date.t() | nil,
          optional(:shows_text) => boolean(),
          optional(:start_from_law) => boolean()
        }

  @private [:_text_by]

  @doc "The periods of provision `id` from resolved changes."
  @spec fold(String.t(), provision(), [Change.t()]) :: [period()]
  def fold(id, %{start: start} = provision, changes) do
    version = Map.get(provision, :version)
    version_start = Map.get(provision, :version_start)

    # a territorial version takes only the changes that can apply to it
    reaching =
      changes
      |> Enum.filter(&reaches?(&1, id))
      |> Enum.filter(&(&1.resolved.date != nil))
      |> Enum.filter(&(version == nil or Facts.overlaps?(&1.resolved.territory, version)))

    # it begins when it exists: its law's start, or a later insertion
    born = Start.start(start, reaching)

    # a commencement before it existed never reaches it (its law's own
    # record for a provision inserted later: CROW s.1A(a), CV-S09 round 2);
    # of the rest, the most specific governs
    # made by another law's undated insertion, it was never in its own
    # law's text: that law's commencements never reach it
    self = Map.get(provision, :law)

    own_law? =
      born == start and is_binary(self) and Start.undated_insertion(id, changes, self) != nil

    reaching =
      reaching
      |> Enum.reject(
        &(&1.resolved.operation == :commenced and
            (Date.compare(&1.resolved.date, born) == :lt or
               (own_law? and String.starts_with?(&1.key, self <> ":commencement:"))))
      )
      |> nearest_commencements()

    provision =
      if born == start,
        do: provision,
        else: %{provision | start: born} |> Map.put(:start_dated, true)

    later? = &(Date.compare(&1, born) == :gt)

    ctx = %{
      self: Map.get(provision, :law),
      extent: provision.extent,
      shows_text: Map.get(provision, :shows_text, false),
      valid: Map.get(provision, :valid)
    }

    # the day the versions split is a day of its own (C3)
    split_day = if version_start && later?.(version_start), do: [{version_start, []}], else: []

    days =
      (Enum.reject(reaching, &(&1.resolved.operation == :applied)) ++
         Start.applied_later(id, born, changes))
      |> Enum.filter(&later?.(&1.resolved.date))
      |> Enum.group_by(& &1.resolved.date)
      |> Map.to_list()
      |> Kernel.++(split_day)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {date, days} -> {date, List.flatten(days)} end)
      |> Enum.sort_by(&elem(&1, 0), Date)

    first = Start.period(id, provision, changes, reaching)

    days
    |> Enum.reduce([first], fn {date, day}, [current | rest] ->
      next =
        current
        |> Day.apply(date, day, ctx)
        |> Day.split(date, day, version, version_start)

      # a day that changes no label field opens no period
      if visible(next) == visible(current),
        do: [Map.merge(current, Map.take(next, @private)) | rest],
        else: [%{next | valid_from: date}, %{current | valid_to: date} | rest]
    end)
    |> Enum.reverse()
    |> Enum.map(&Map.drop(&1, @private))
  end

  defp visible(period), do: Map.drop(period, [:tiers | @private])

  # the most specific commencement governs: a provision commenced in its
  # own right takes no ancestor's (an order commencing s.2(1) "except
  # paragraph (d)" never commences (d): 2007/19 s.2(1)(d), CV-S09 batch 1);
  # otherwise the nearest ancestor's, then the whole law's
  defp nearest_commencements(reaching) do
    {commenced, rest} = Enum.split_with(reaching, &(&1.resolved.operation == :commenced))

    case Enum.group_by(commenced, &depth(&1.target)) do
      groups when map_size(groups) == 0 -> rest
      groups -> rest ++ groups[groups |> Map.keys() |> Enum.max()]
    end
  end

  defp depth("*"), do: 0
  defp depth(target), do: length(LatRef.ancestors(target))

  @doc """
  True when the change reaches provision `id`: its own changes, and
  provision-level changes on an ancestor or on the whole law (`"*"`) —
  never a child's (C9).
  """
  @spec reaches?(Change.t(), String.t()) :: boolean()
  def reaches?(%Change{target: target, resolved: r} = c, id) do
    target == id or
      (((r.level == :provision and level_stated?(r)) or Facts.earlier_amendment?(c)) and
         (target == "*" or target in tl(LatRef.ancestors(id))))
  end

  # a whole-provision change reaches what lies under it only when a source
  # says it is whole: a level no source states is the table's default, no
  # evidence (CV-S09 round 2: the markup placed CROW s.13(2)'s Addition,
  # wrapping s.1(6A)-(6C), on s.1 itself — unstated, it had reached all of s.1)
  defp level_stated?(%{sources: sources}) when is_map(sources),
    do: Map.fetch(sources, :level) != {:ok, nil}

  defp level_stated?(_r), do: true
end
