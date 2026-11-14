defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPlacement do
  @moduledoc """
  Where a change in the revised text's markup lands (CV-S03, agreed with
  Jason 2026-10-23: every change id accounted for). Given the provisions
  the markup reader placed it on (`Readers.Markup.read/3` targets) and what
  we hold of the law — its LAT rows, whether its LAT holds schedules — a
  change is:

  - `:placed` — on rows we hold;
  - `:placed_versions` — on a provision we hold as territorial versions
    (C3: `s.23` → `s.23[E+W]`, `s.23[S]`);
  - `:placed_ancestor` — deeper than our rows: under a held row, whose
    words it changes;
  - `:whole_law` — a legacy change spanning the law (`*`);
  - `{:unplaced, reason}`:
    - `:schedule_not_parsed` — in a schedule or an EU annex (K1, the v0.1
      limit);
    - `:outside_provisions` — no row id above it (the law's title, its
      introductory text);
    - `:group_row_missing` — in a Part, Chapter or cross-heading's own
      heading or text, and we hold no row for the group;
    - `:id_not_converted` — under an id that names no row (the reader's
      fault);
    - `:row_missing` — on a provision in the text with no row of its own
      nor any held ancestor;
    - `:outside_lat_scope` — a scoped law (`LatScope` fragments, as CLML
      ids in `held.scope`) unplaced beyond its fragments: we read a law for
      the scope we hold, from our rows to the law (Jason 2026-11-09,
      Environmental Protection: Markup reader, Decision 1).

  A change on several provisions is placed when every one is; else it
  takes the first unplaced reason. Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LatRef

  @type outcome ::
          :placed
          | :placed_versions
          | :placed_ancestor
          | :whole_law
          | {:unplaced, atom()}

  @faults [:id_not_converted, :row_missing, :group_row_missing]

  @group ~r/^(?:part|chapter|title|crossheading|division|subpart)-/
  # an id still named nowhere that begins "section-" is an EU Section (a
  # domestic section id is always named)

  @doc """
  Where a change lands, from its targets, the CLML ids above each of its
  elements (`ids`, one list per element, outermost first) and what we hold
  (`rows`, `schedules?`).
  """
  @spec classify([String.t()], [[String.t()]], %{
          required(:rows) => MapSet.t(),
          required(:schedules?) => boolean(),
          optional(:scope) => [String.t()] | nil
        }) :: outcome()
  def classify(targets, ids, held) do
    case placed(targets, ids, held) do
      {:unplaced, why} = unplaced ->
        if fault?(why), do: scoped(targets, ids, held, unplaced), else: unplaced

      outcome ->
        outcome
    end
  end

  # a fault in a scoped law: wholly beyond its fragments, outside our scope;
  # partly, placed by its targets within (each fragment named as a ref; a
  # held row or a missing row under a fragment is within), the rest outside
  # (Fire and OH&S: Markup reader, the Fire Precautions Act 1971)
  defp scoped(_targets, _ids, %{scope: nil}, unplaced), do: unplaced
  defp scoped(_targets, _ids, held, unplaced) when not is_map_key(held, :scope), do: unplaced

  defp scoped(targets, ids, held, unplaced) do
    cond do
      outside_scope?(ids, held.scope) -> {:unplaced, :outside_lat_scope}
      within = within_scope(targets, held) -> placed(within, ids, held)
      true -> unplaced
    end
  end

  # the targets a scoped law holds or names within a fragment; nil when a
  # fragment names no ref, when none is within, or when all are
  defp within_scope(targets, held) do
    refs = Enum.map(held.scope, &Order.ref/1)

    within =
      if Enum.all?(refs, & &1),
        do:
          Enum.filter(
            targets,
            &(target(&1, held) != {:unplaced, :row_missing} or under?(&1, refs))
          )

    if within not in [nil, [], targets], do: within
  end

  defp under?(target, refs) do
    own = base(target)
    Enum.any?(refs, &(&1 == own or &1 in LatRef.ancestors(own)))
  end

  # no element sits in or under a fragment
  defp outside_scope?(ids, scope),
    do: not Enum.any?(List.flatten(ids), fn id -> Enum.any?(scope, &in_fragment?(id, &1)) end)

  defp in_fragment?(id, fragment), do: id == fragment or String.starts_with?(id, fragment <> "-")

  defp placed([], ids, held), do: nowhere(ids, held)

  defp placed(targets, _ids, held) do
    outcomes = Enum.map(targets, &target(&1, held))

    case Enum.find(outcomes, &match?({:unplaced, _}, &1)) do
      nil -> Enum.min_by(outcomes, &rank/1)
      unplaced -> unplaced
    end
  end

  defp rank(:placed), do: 0
  defp rank(:placed_versions), do: 1
  defp rank(:placed_ancestor), do: 2
  defp rank(:whole_law), do: 3

  defp target("*", _held), do: :whole_law

  defp target(ref, held) do
    bases = MapSet.new(held.rows, &base/1)

    cond do
      MapSet.member?(held.rows, ref) -> :placed
      MapSet.member?(bases, ref) -> :placed_versions
      not held.schedules? and schedule?(ref) -> {:unplaced, :schedule_not_parsed}
      Enum.any?(LatRef.ancestors(ref), &MapSet.member?(bases, &1)) -> :placed_ancestor
      true -> {:unplaced, :row_missing}
    end
  end

  # placed nowhere: why
  defp nowhere(ids, held) do
    all = List.flatten(ids)

    cond do
      all == [] ->
        {:unplaced, :outside_provisions}

      not held.schedules? and Enum.any?(all, &(&1 =~ ~r/^(?:schedule|annex)-/)) ->
        {:unplaced, :schedule_not_parsed}

      Enum.any?(
        ids,
        &(List.last(&1, "") =~ @group or String.starts_with?(List.last(&1, ""), "section-"))
      ) ->
        {:unplaced, :group_row_missing}

      true ->
        {:unplaced, :id_not_converted}
    end
  end

  defp schedule?(ref), do: String.starts_with?(ref, ["sch.", "annex."])

  defp base(ref), do: String.replace(ref, ~r/\[[^\]]+\]$/, "")

  @doc "True for a reason that is our fault (pass needs none)."
  @spec fault?(atom()) :: boolean()
  def fault?(reason), do: reason in @faults

  @doc """
  A markup key against the law's feed: `:in_feed` (an effect id the feed
  holds), `:not_in_feed` (an effect id it doesn't), `:legacy` (no effect
  id). A count for CV-S07, not a gate.
  """
  @spec against_feed(String.t(), MapSet.t()) :: :in_feed | :not_in_feed | :legacy
  def against_feed("key-" <> _ = key, feed_ids),
    do: if(MapSet.member?(feed_ids, key), do: :in_feed, else: :not_in_feed)

  def against_feed(_key, _feed_ids), do: :legacy
end
