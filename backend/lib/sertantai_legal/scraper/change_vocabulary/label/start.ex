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
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.{Facts, Undated}

  # old Acts' commentary pointers (d29p…, d30p…): their Additions also mark
  # repeals and substitutions (OSRPA 1963 ss.4–16); never M_F_, which marks
  # real insertions (REACH Art 139A, CV-S09 round 4)
  @legacy ~r/^d\d+p\d+/

  @doc """
  The day the provision begins: its start, or the latest later
  whole-provision insertion reaching it — on it or an ancestor: it exists
  once it and everything holding it exist (CV-S09 round 3: HSWA
  s.51A(2E)(b), inserted 2005 inside the s.51A of 1998).
  """
  @spec start(Date.t(), [Change.t()]) :: Date.t()
  def start(start, reaching) do
    reaching
    |> Enum.filter(
      &(insertion?(&1) and Date.compare(&1.resolved.date, start) == :gt and not legacy_only?(&1))
    )
    |> Enum.map(& &1.resolved.date)
    |> Enum.max(Date, fn -> start end)
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

        # inserted into a provision its own law has not yet brought into
        # force: prospective until that law commences it (Jason 2026-10-30,
        # CV-S09 round 9: 2007/19 s.7(3)(aa), inserted 2008-04-01 into s.7,
        # in force 2008-04-06)
        own_insertion != nil and host_prospective?(commenced, self, start) ->
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
    # inserted or substituted it that day (D1). A whole insertion no source
    # dates made it too — its own (Forestry Act 1967 s.1(4)(a), SI 1999/1747)
    # or its ancestor's (HSWA s.25A(1), CPA 1987: CV-S09 round 2) — and an
    # undated substitution of it after that insertion made its text since
    # (CLP Art 25(7): inserted by Regulation 2017/542, replaced by 2020/11)
    undated = Undated.makers(id, changes)

    # on a start no source dates (C10), an undated change in its words made
    # its text too (Jason 2026-10-30: REACH Art 118(2)(c), CLP's "mixture")
    undated =
      if Map.get(provision, :start_dated, true),
        do: undated,
        else:
          undated ++
            Undated.words(id, changes) ++ Undated.ancestor_substitutions(id, changes, undated)

    made =
      Enum.filter(reaching, &(on_start?.(&1) and &1.resolved.operation in Facts.text_changes())) ++
        undated

    # an amendment to the amending law before it took effect made it too (C5)
    made =
      if made == [],
        do: [],
        else: made ++ Enum.filter(reaching, &(on_start?.(&1) and Facts.earlier_amendment?(&1)))

    text_by = Facts.by(made, self)

    # an undated whole repeal with its text gone: repealed from a start no
    # source dates (CV-S09 round 3: CLP Art 25(5), deleted by Regulation
    # (EU) 286/2011, the feed undated); repealed for one territory, in
    # force where it remains (C1)
    gone = Undated.repeals(id, changes, provision)

    # an undated maker leaves the start's own date unknown when the start
    # is only its law's (C10), never the law's commencement
    in_force? =
      status == :in_force and Map.get(provision, :start_dated, true) and
        not (undated != [] and Map.get(provision, :start_from_law, false))

    period = %{
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
        tiers(
          provision,
          own_insertion || Undated.insertion(id, changes, self),
          start_day,
          made,
          territorial
        ),
      _text_by: text_by,
      _text_from: made
    }

    period |> Undated.repealed_at_start(gone, self) |> empty_untiered()
  end

  # an empty field rests on nothing: no tier
  defp empty_untiered(period),
    do: %{
      period
      | tiers:
          Map.new(period.tiers, fn {f, t} ->
            {f, if(Map.get(period, f) in [nil, []], do: nil, else: t)}
          end)
    }

  # each field's tier from the changes behind it (CV-S09 round 2: an
  # inserted provision's start rests on its insertion's sources); a field
  # nothing changed rests on the provision's start (`:start_tier`)
  defp tiers(provision, own_insertion, start_day, made, territorial) do
    base =
      Map.new(
        ~w(status in_force_from changed_by commenced_by territory)a,
        &{&1, Map.get(provision, :start_tier)}
      )

    behind = Enum.reject([own_insertion | start_day], &is_nil/1)

    base
    |> set(:status, behind)
    |> set(:in_force_from, behind ++ made)
    |> set(:changed_by, made)
    |> set(:commenced_by, behind ++ made)
    |> set(:territory, Enum.reject([own_insertion | territorial], &is_nil/1))
  end

  defp set(tiers, _field, []), do: tiers
  defp set(tiers, field, changes), do: Facts.tiers(tiers, [field], Enum.uniq(changes))

  @doc "The nearest undated whole insertion of `id` by another law (`Label.Undated.insertion/3`)."
  @spec undated_insertion(String.t(), [Change.t()], String.t() | nil) :: Change.t() | nil
  defdelegate undated_insertion(id, changes, self), to: Undated, as: :insertion

  @doc "The law's application clauses not in force at the start (they apply on their day)."
  @spec applied_later(String.t(), Date.t(), [Change.t()]) :: [Change.t()]
  def applied_later(id, start, changes), do: changes |> applications(id, start) |> elem(1)

  # the extent, narrowed to where its insertion applies (C14) or the one
  # territory it was commenced for (C13), and by the application clauses
  # in force at the start (C6): a clause with no date, or one in the
  # provision itself, applies from its start
  defp territory(provision, own_insertion, territorial, changes, id) do
    extent = provision.extent

    # its own insertion's territory, or an undated one's (C14)
    t =
      case insertion_territory(own_insertion, changes, id, provision) do
        t when is_binary(t) and is_binary(extent) -> Facts.intersect(extent, t)
        t when is_binary(t) -> t
        _ -> extent
      end

    t =
      case Enum.map(territorial, &Facts.territory_only/1) do
        [] -> t
        ts -> narrow(t, SertantaiLegal.Scraper.Territory.union(ts))
      end

    t = version_at_start(provision) || t

    {at_start, _} = applications(changes, id, provision.start)
    Enum.reduce(at_start, t, &Facts.apply_to(&2, &1.resolved.territory))
  end

  # its insertions' territory: laws inserting it the same day for different
  # territories insert it in their union (CV-S09 round 9: HSWA s.23(4)(a),
  # SI 2005/1541 for E+W and SSI 2006/475 for S on 2006-10-01)
  defp insertion_territory(nil, changes, id, provision),
    do:
      (Undated.insertion(id, changes, Map.get(provision, :law)) || %{resolved: %{territory: nil}}).resolved.territory

  defp insertion_territory(own, changes, id, _provision) do
    same_day =
      Enum.filter(
        changes,
        &(insertion?(&1) and &1.resolved.date == own.resolved.date and
            SertantaiLegal.Scraper.ChangeVocabulary.Label.reaches?(&1, id))
      )

    ts = Enum.map(same_day, & &1.resolved.territory)

    if own.resolved.territory != nil and Enum.all?(ts, &is_binary/1),
      do: SertantaiLegal.Scraper.Territory.union(ts),
      else: own.resolved.territory
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

  # its own law commences it only after the start, never on or before
  defp host_prospective?(_commenced, nil, _start), do: false

  defp host_prospective?(commenced, self, start) do
    own = Enum.filter(commenced, &String.starts_with?(&1.key, self <> ":commencement:"))

    own != [] and Enum.all?(own, &(Date.compare(&1.resolved.date, start) == :gt))
  end

  # an insertion only a legacy markup Addition claims (its operation a
  # pointer: CV-S08, Jason 2026-10-29)
  defp legacy_only?(c),
    do: c.resolved.sources[:operation] == :markup and Regex.match?(@legacy, c.key)
end
