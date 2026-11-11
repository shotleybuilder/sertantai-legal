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
  # a container's insertion (a Part or Chapter heading, its changes on
  # "*") later than the row's own dated record never moves it: the row was
  # there before the heading (Decision 5: EA 1995 s.11 in Pt I Ch 1A,
  # inserted by WSI 2013/755)
  @spec start(Date.t(), [Change.t()]) :: Date.t()
  def start(start, reaching) do
    own =
      for c <- reaching,
          c.target != "*",
          c.resolved.operation in [:commenced, :inserted],
          do: c.resolved.date

    reaching
    |> Enum.filter(
      &(insertion?(&1) and Date.compare(&1.resolved.date, start) == :gt and not legacy_only?(&1) and
          not container_after_own?(&1, own))
    )
    |> Enum.map(& &1.resolved.date)
    |> Enum.max(Date, fn -> start end)
  end

  defp container_after_own?(%Change{target: "*"} = c, own),
    do: Enum.any?(own, &(Date.compare(&1, c.resolved.date) == :lt))

  defp container_after_own?(_c, _own), do: false

  @doc """
  `provision` begun at its own law's clause commencing it (or anything
  holding it) before the law's general start, once the law is made (the
  agent pass, Environmental Protection: Label fold: WSI 2026/103 Part 7 the
  day after making, its general start 2027-10-01; SSI 2025/165 reg.1(3)).
  """
  @spec early_own(map(), [Change.t()]) :: map()
  def early_own(%{law: law, start: %Date{} = start} = provision, reaching) when is_binary(law) do
    made = Map.get(provision, :made)

    early =
      for c <- reaching,
          c.resolved.operation == :commenced and
            String.starts_with?(c.key, law <> ":commencement:"),
          Date.compare(c.resolved.date, start) == :lt,
          made == nil or Date.compare(c.resolved.date, made) != :lt,
          do: c.resolved.date

    # only where its start is its law's: a row's own later start (inserted
    # 1999 into the Forestry Act 1967, golden) is never moved back
    if early != [] and Map.get(provision, :start_dated, true) and
         Map.get(provision, :start_from_law, false),
       do: %{provision | start: Enum.min(early, Date)},
       else: provision
  end

  def early_own(provision, _reaching), do: provision

  @doc """
  The day a provision another law inserted, no source dating it, begins:
  that law's first dated record reaching it (the feed's records of EPA
  Part IIA by EA 1995, from 1996-02-01), else that law's making
  (`provision.made_of`), never before `born` (Environmental Protection:
  Label fold, Decision 1).
  """
  @spec inserter_born(Date.t(), Change.t(), String.t(), [Change.t()], map()) :: Date.t()
  def inserter_born(born, %Change{resolved: %{by: by}}, id, changes, provision) do
    # on it or anything holding it: a record there shows its text existed
    held = [id, "*" | SertantaiLegal.Scraper.LatRef.ancestors(id)]

    dated =
      for c <- changes,
          c.resolved.by == by and c.resolved.date != nil and c.target in held,
          do: c.resolved.date

    case Enum.min(dated, Date, fn -> provision |> Map.get(:made_of, %{}) |> Map.get(by) end) do
      %Date{} = d -> Enum.max([born, d], Date)
      nil -> born
    end
  end

  @doc """
  A territorial version with no insertion of its own begins no earlier than
  its sibling's dated insertion of the same number, the day it began in
  that version unknown (`:start_undated`; Decision 4: EPA s.106(4A)[E+W],
  inserted in the S text by SSI 2002/541).
  """
  @spec sibling_born(String.t(), Date.t(), [Change.t()], [Change.t()], map()) :: {Date.t(), map()}
  def sibling_born(id, born, reaching, changes, provision) do
    base = String.replace(id, ~r/\[[^\]]+\]$/, "")
    # its number or one holding it (s.106(4B)(a), inserted as s.106(4B))
    held = SertantaiLegal.Scraper.LatRef.ancestors(base)

    sibling =
      for c <- changes,
          Map.get(provision, :version) != nil and c.target in held and insertion?(c),
          c.resolved.date != nil and Date.compare(c.resolved.date, born) == :gt,
          do: c.resolved.date

    if sibling == [] or Enum.any?(reaching, &(insertion?(&1) and &1.target in held)),
      do: {born, provision},
      else: {Enum.min(sibling, Date), Map.put(provision, :start_undated, true)}
  end

  @doc """
  The first period of `id` from `start`, with `:_text_by` (the laws that
  made the text, whatever its status — dropped by `Label.fold/3`).
  """
  @spec period(String.t(), map(), [Change.t()], [Change.t()]) :: map()
  def period(id, %{start: start} = provision, changes, reaching) do
    self = Map.get(provision, :law)
    f = start_facts(reaching, start)
    status = status(provision, f, self, start)
    made = makers(id, provision, changes, reaching, start)
    text_by = Facts.by(made.all, self)

    # an undated whole repeal with its text gone: repealed from a start no
    # source dates (CV-S09 round 3: CLP Art 25(5), deleted by Regulation
    # (EU) 286/2011, the feed undated); repealed for one territory, in
    # force where it remains (C1)
    gone = Undated.repeals(id, changes, provision)

    # an undated maker leaves the start's own date unknown when the start
    # is only its law's (C10), never the law's commencement
    in_force? =
      status == :in_force and start_known?(provision, made.undated) and
        not by_order_undated?(provision, f)

    period =
      %{
        valid_from: start,
        valid_to: nil,
        status: status,
        in_force_from: if(in_force?, do: start),
        territory: territory(provision, f.own_insertion, f.territorial, changes, id),
        tiers:
          tiers(
            provision,
            f.own_insertion || Undated.insertion(id, changes, self),
            f.start_day,
            made.all,
            f.territorial
          ),
        _text_by: text_by,
        _text_from: made.all
      }
      |> Map.merge(credits(status, text_by, f.start_day ++ made.all, self))

    period |> Undated.repealed_at_start(gone, self) |> empty_untiered()
  end

  # what reaches it on and after the start
  defp start_facts(reaching, start) do
    later? = &(Date.compare(&1.resolved.date, start) == :gt)
    on_start? = &(Date.compare(&1.resolved.date, start) == :eq)
    own_insertion = Enum.find(reaching, &(insertion?(&1) and on_start?.(&1)))
    commenced = Enum.filter(reaching, &(&1.resolved.operation == :commenced))
    start_day = Enum.filter(commenced, on_start?)

    %{
      own_insertion: own_insertion,
      started?: Enum.any?(reaching, &(insertion?(&1) and not later?.(&1))),
      commenced: commenced,
      start_day: start_day,
      later_commencement?: Enum.any?(commenced, later?),
      territorial: Enum.filter([own_insertion | start_day], &(&1 && Facts.territory_only(&1)))
    }
  end

  defp status(provision, f, self, start) do
    cond do
      markup_prospective?(provision, f.own_insertion, f.start_day) -> :prospective
      f.own_insertion != nil -> insertion_status(f, self, start)
      f.territorial != [] -> :in_force
      true -> commencement_status(f)
    end
  end

  # inserted into a provision its own law has not yet brought into force:
  # prospective until that law commences it (Jason 2026-10-30, CV-S09 round
  # 9: 2007/19 s.7(3)(aa), inserted 2008-04-01 into s.7, in force 2008-04-06)
  defp insertion_status(f, self, start) do
    cond do
      host_prospective?(f.commenced, self, start) -> :prospective
      Facts.full?(f.own_insertion) -> :in_force
      true -> :in_force_partial
    end
  end

  defp commencement_status(%{start_day: []} = f),
    do: if(not f.started? and f.later_commencement?, do: :prospective, else: :in_force)

  defp commencement_status(%{later_commencement?: false} = f),
    do: if(Enum.any?(f.start_day, &Facts.full?/1), do: :in_force, else: :in_force_partial)

  # full on the start day, then commenced again later: prospective unless
  # an insertion started it
  defp commencement_status(f) do
    cond do
      Enum.any?(f.start_day, &(not Facts.full?(&1))) -> :in_force_partial
      f.started? -> :in_force
      true -> :prospective
    end
  end

  # the text in force at the start: the original, or the law that inserted
  # or substituted it that day (D1). A whole insertion no source dates made
  # it too — its own (Forestry Act 1967 s.1(4)(a), SI 1999/1747) or its
  # ancestor's (HSWA s.25A(1), CPA 1987: CV-S09 round 2) — and an undated
  # substitution of it after that insertion made its text since (CLP Art
  # 25(7): inserted by Regulation 2017/542, replaced by 2020/11) … never one
  # by a law made after the start: it dates nothing (EPA s.126, substituted
  # by 1999 c.28 with no source dating it)
  defp makers(id, provision, changes, reaching, start) do
    on_start? = &(Date.compare(&1.resolved.date, start) == :eq)
    undated = id |> Undated.makers(changes) |> Enum.reject(&made_after?(&1, provision, start))

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
    earlier = Enum.filter(reaching, &(on_start?.(&1) and Facts.earlier_amendment?(&1)))
    %{undated: undated, all: if(made == [], do: [], else: made ++ earlier)}
  end

  # changed_by and commenced_by: only in force
  defp credits(:in_force, text_by, behind, self),
    do: %{changed_by: text_by, commenced_by: Facts.commencers(behind, text_by, self)}

  defp credits(_status, _text_by, _behind, _self), do: %{changed_by: [], commenced_by: []}

  # the start's own day is known: dated, not a version's borrowed start,
  # and not its law's start with an undated maker (C10)
  defp start_known?(provision, undated),
    do:
      Map.get(provision, :start_dated, true) and not Map.get(provision, :start_undated, false) and
        not (undated != [] and Map.get(provision, :start_from_law, false))

  # left by its own law to an order we don't hold, nothing dating the start
  # itself (no insertion, no commencement that day): its in-force date is
  # unknown (Decision 8, the parked J6)
  defp by_order_undated?(provision, f),
    do: Map.get(provision, :by_order, false) and f.own_insertion == nil and f.start_day == []

  defp made_after?(c, provision, start) do
    case provision |> Map.get(:made_of, %{}) |> Map.get(c.resolved.by) do
      %Date{} = made -> Date.compare(made, start) == :gt
      _ -> false
    end
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

  # its own insertion names no territory: the nearest one holding it that
  # does (C14; the agent pass, Environmental Protection: Label fold: SI
  # 1999/2228 reg.3B(10)(b), reg.3B inserted for England only)
  defp insertion_territory(%Change{resolved: %{territory: nil}} = own, changes, id, _provision) do
    held = SertantaiLegal.Scraper.LatRef.ancestors(id)

    changes
    |> Enum.filter(
      &(insertion?(&1) and &1.target in held and is_binary(&1.resolved.territory) and
          &1.resolved.date != nil and Date.compare(&1.resolved.date, own.resolved.date) != :gt)
    )
    |> Enum.max_by(&length(SertantaiLegal.Scraper.LatRef.ancestors(&1.target)), fn -> own end)
    |> then(& &1.resolved.territory)
  end

  defp insertion_territory(own, changes, id, _provision) do
    same_day =
      Enum.filter(
        changes,
        &(insertion?(&1) and &1.resolved.date == own.resolved.date and
            SertantaiLegal.Scraper.ChangeVocabulary.Label.reaches?(&1, id))
      )

    ts = Enum.map(same_day, & &1.resolved.territory)

    if own.resolved.territory != nil and ts != [] and Enum.all?(ts, &is_binary/1),
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

  @doc """
  True for an insertion only a legacy markup Addition claims (its operation
  a pointer: CV-S08, Jason 2026-10-29) — unless the amending law's text or
  the feed states it too (FA 1961 s.10A, inserted by EMASA 1972: CV-06
  round 2, S7).
  """
  @spec legacy_only?(Change.t()) :: boolean()
  def legacy_only?(c),
    do:
      c.resolved.sources[:operation] == :markup and Regex.match?(@legacy, c.key) and
        Change.values(c, :law_text, :operation) == [] and
        Change.values(c, :feed, :operation) == []
end
