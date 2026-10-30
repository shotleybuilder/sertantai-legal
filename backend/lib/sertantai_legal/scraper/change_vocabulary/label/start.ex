defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Start do
  @moduledoc """
  A provision's first label period (change vocabulary; CV-S09 round 1):
  when it begins and what it is then.

  - **When.** The provision's start (its law's commencement), unless a
    whole-provision insertion on it or on an ancestor came later: then the
    insertion's date — a provision is labelled from when it exists, never
    from its law's start (KI-insert: SI 2009/1348 reg.19B, inserted 2011,
    had been labelled from 2009). A legacy markup Addition alone never
    moves it (its operation is a pointer: OSRPA 1963 ss.4–16).
  - **Status.** The markup's Prospective holds as at the text's valid day:
    a made version marks everything prospective before its commencement
    (NISR 1997/248). Then its own insertion (partly in force at a first
    stage for purposes: TCPA 1990 s.78(4BA)); a commencement on the start
    day — partly in force for a partial one (SI 1992/3004 reg.20(2)), in
    force unless a later commencement reaches it; a later commencement
    alone: prospective.
  - **Territory.** The extent, narrowed to its insertion's territory (C14)
    or to the one territory a commencement is for (C13), and by the law's
    application clauses in force then (C6).
  - `in_force_from` the start, `changed_by` the laws that made the text in
    force at the start (D1), `commenced_by` the law that brought it into
    force apart from them (Jason 2026-10-30) — all empty unless in force.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts

  @legacy ~r/^(?:d\d+p\d+|M_F_)/

  @doc """
  The day the provision begins: its start, or a later whole-provision
  insertion reaching it (on it or an ancestor), the earliest.
  """
  @spec start(Date.t(), [Change.t()]) :: Date.t()
  def start(start, reaching) do
    reaching
    |> Enum.filter(
      &(insertion?(&1) and Date.compare(&1.resolved.date, start) == :gt and not legacy_only?(&1))
    )
    |> Enum.map(& &1.resolved.date)
    |> Enum.min(Date, fn -> start end)
  end

  @doc """
  The first period of `id` from `start`, with `:_text_by` (the laws that
  made the text, whatever its status — dropped by `Label.fold/3`).
  """
  @spec period(String.t(), map(), [Change.t()], [Change.t()]) :: map()
  def period(id, %{start: start} = provision, changes, reaching) do
    self = Map.get(provision, :law)
    later? = &(Date.compare(&1.resolved.date, start) == :gt)
    on_start? = &(Date.compare(&1.resolved.date, start) == :eq)

    own_insertion = Enum.find(reaching, &(insertion?(&1) and on_start?.(&1)))
    started? = Enum.any?(reaching, &(insertion?(&1) and not later?.(&1)))
    commenced = Enum.filter(reaching, &(&1.resolved.operation == :commenced))
    start_day = Enum.filter(commenced, on_start?)
    later_commencement? = Enum.any?(commenced, later?)
    territorial = Enum.filter([own_insertion | start_day], &(&1 && Facts.territory_only(&1)))

    status =
      cond do
        markup_prospective?(provision, own_insertion, start_day) ->
          :prospective

        own_insertion != nil ->
          if Facts.full?(own_insertion), do: :in_force, else: :in_force_partial

        territorial != [] ->
          :in_force

        Enum.any?(start_day, &Facts.full?/1) and not later_commencement? ->
          :in_force

        start_day != [] and not later_commencement? ->
          :in_force_partial

        Enum.any?(start_day, &(not Facts.full?(&1))) ->
          :in_force_partial

        not started? and later_commencement? ->
          :prospective

        true ->
          :in_force
      end

    # the text in force at the start: the original, or the law that
    # inserted or substituted it that day (D1); its own whole insertion
    # made it, whether or not any source dates it (Forestry Act 1967
    # s.1(4)(a), inserted by SI 1999/1747)
    made =
      Enum.filter(changes, fn c ->
        (c.target == id and insertion?(c) and c.resolved.date == nil) or
          (c in reaching and on_start?.(c) and c.resolved.operation in Facts.text_changes())
      end)

    text_by = Facts.by(made, self)
    in_force? = status == :in_force and Map.get(provision, :start_dated, true)

    %{
      valid_from: start,
      valid_to: nil,
      status: status,
      in_force_from: if(in_force?, do: start),
      changed_by: if(status == :in_force, do: text_by, else: []),
      commenced_by:
        if(status == :in_force,
          do: Facts.commencers(start_day ++ made, text_by, self),
          else: []
        ),
      territory: territory(provision, own_insertion, territorial, changes, id),
      tiers:
        Map.new(
          ~w(status in_force_from changed_by commenced_by territory)a,
          &{&1, Map.get(provision, :start_tier)}
        ),
      _text_by: text_by
    }
  end

  @doc "The law's application clauses not in force at the start (they apply on their day)."
  @spec applied_later(String.t(), Date.t(), [Change.t()]) :: [Change.t()]
  def applied_later(id, start, changes), do: changes |> applications(id, start) |> elem(1)

  # the extent, narrowed to where its insertion applies (C14) or the one
  # territory it was commenced for (C13), and by the application clauses
  # in force at the start (C6): a clause with no date, or one in the
  # provision itself, applies from its start
  defp territory(provision, own_insertion, territorial, changes, id) do
    extent = provision.extent

    t =
      case own_insertion && own_insertion.resolved.territory do
        t when is_binary(t) and is_binary(extent) -> Facts.intersect(extent, t)
        t when is_binary(t) -> t
        _ -> extent
      end

    t =
      case Enum.map(territorial, &Facts.territory_only/1) do
        [] -> t
        ts -> narrow(t, SertantaiLegal.Scraper.Territory.union(ts))
      end

    t = narrow(t, version_at_start(provision))

    {at_start, _} = applications(changes, id, provision.start)
    Enum.reduce(at_start, t, &Facts.apply_to(&2, &1.resolved.territory))
  end

  # a version that has already split at the start is its own territory (C3)
  defp version_at_start(%{version: v, version_start: %Date{} = d, start: start})
       when is_binary(v),
       do: if(Date.compare(start, d) != :lt, do: v)

  defp version_at_start(_provision), do: nil

  defp narrow(t, nil), do: t
  defp narrow(nil, n), do: n
  defp narrow(t, n), do: Facts.intersect(t, n)

  defp applications(changes, id, start) do
    changes
    |> Enum.filter(
      &(&1.resolved.operation == :applied and
          SertantaiLegal.Scraper.ChangeVocabulary.Label.reaches?(&1, id))
    )
    |> Enum.split_with(fn c ->
      c.resolved.date == nil or Change.value(c, :law_text, :clause) == id or
        not later?(c, start)
    end)
  end

  defp later?(c, start), do: Date.compare(c.resolved.date, start) == :gt

  # the markup's Prospective says what was not in force on the day the
  # text is valid at: a commencement of it after that day supersedes it
  defp markup_prospective?(provision, own_insertion, start_day) do
    Map.get(provision, :prospective, false) and
      case Map.get(provision, :valid) do
        %Date{} = valid ->
          not Enum.any?(
            Enum.reject([own_insertion | start_day], &is_nil/1),
            &(Date.compare(&1.resolved.date, valid) == :gt)
          )

        _ ->
          true
      end
  end

  defp insertion?(c), do: c.resolved.operation == :inserted and c.resolved.level == :provision

  # an insertion only a legacy markup Addition claims (its operation a
  # pointer: CV-S08, Jason 2026-10-29)
  defp legacy_only?(c),
    do: c.resolved.sources[:operation] == :markup and Regex.match?(@legacy, c.key)
end
