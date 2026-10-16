defmodule SertantaiLegal.Scraper.LabelProjection do
  @moduledoc """
  A provision's labels as a timeline (lat-refactor LR-24): from its changes
  in the register (`lat_change_log_rows`), one period per state —
  `valid_from` .. `valid_to` (exclusive; nil = open) with `status`,
  `in_force_from` and `changed_by`. "As at T" is a lookup (`as_at/2`);
  "today" is the UK date. Nothing is stored that goes stale with time:
  known future dates are already periods.

  Rules (Jason, 2026-10-13):

  - **Changes that count.** The row's own changes, its ancestors'
    whole-provision changes (not words-level), and whole-instrument changes
    (they reach every row). A change counts at its `effective_from` (the
    latest dated in-force entry: fully in force); its earlier entries
    make a commencement partial (`EffectFacts.partial?/3`).
  - **D1 version.** `in_force_from` is when the current text took effect:
    the latest text change (substituted, inserted, repealed, renumbered,
    amended) or commencement in force at T, else the start when it is
    evidence of commencement; `changed_by` is that change's law, nil for
    the law itself. Modifications and applications never start a version.
    Empty while prospective or partly in force.
  - **D3 status at T.** repealed (repealed_saved with savings) from a
    whole-provision repeal in force at T reaching the row's whole extent (a
    repeal for part of it narrows the territory: LR-26); prospective while a commencing
    change (commencement, the row's own insertion or substitution) has no
    entry in force at T; in_force_partial while a commencement is partial;
    else in_force.
  - **J1 start.** The row's own insertion (it didn't exist before), else the
    law's coming into force (`law_start`, decided by `LawStart`, LR-33), else its own commencement, else
    the earliest change held on the row (not a whole-instrument one); with
    none, no periods (a `:no_start` gap).
    Before the start: no period ("unknown").
  - **J2 today.** Where the CLML markup says repealed or prospective and
    the period containing today disagrees, the markup wins for that period
    and the disagreement is a `:markup_conflict` gap.
  - **J5 inserted.** A row a note points to as inserted or substituted
    (`inserted_pointer`; the note is only a pointer) whose insertion the
    register doesn't date never takes the law's start: its start is the
    earliest change held, else unknown (`:insertion_not_in_register`).
  - **T1 undated.** A row with a text change no source dates
    (`undated_change`) has no `in_force_from` / `changed_by` in its in-force
    periods: empty `in_force_from` with status in_force means "changed,
    date unknown" (with prospective / partial it means not fully in force).
  - **LR-26 D1′ territory.** Today's period: extent minus excluded extent
    (the parse's reviewed calculation); earlier periods roll an exclusion
    back only when every claim behind it is a dated single-date removal,
    else unknown; later periods narrow by dated territorial repeals (staged:
    unknown). Nothing left: status repealed, territory nil ("nowhere").
    `rows` also carry `excluded_extent` and `claims` (territory_provenance).
  - **J4 outstanding.** A repeal in force but not yet applied to the
    revised text (`applied: false`) counts from its date; the row is listed
    as an `:outstanding_effect` (source-side: legislation.gov.uk's backlog).

  Notes are never read. Pure: `today` and `law_start` are passed in.
  """

  alias SertantaiLegal.Scraper.{
    EffectFacts,
    EffectIndex,
    EffectTerritory,
    LatStatus,
    NotePointer,
    Territory
  }

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defmodule Period do
    @moduledoc "One state of a provision, valid from `valid_from` until `valid_to` (exclusive; nil = open)."
    @enforce_keys [:law_name, :section_id, :valid_from, :status]
    defstruct [
      :law_name,
      :section_id,
      :valid_from,
      :valid_to,
      :status,
      :in_force_from,
      :changed_by,
      :territory,
      change_ids: []
    ]

    @type t :: %__MODULE__{
            law_name: String.t(),
            section_id: String.t(),
            valid_from: Date.t(),
            valid_to: Date.t() | nil,
            status: String.t(),
            in_force_from: Date.t() | nil,
            changed_by: String.t() | nil,
            territory: String.t() | nil,
            change_ids: [String.t()]
          }
  end

  @type gap ::
          {String.t(),
           :no_start | :insertion_not_in_register | :markup_conflict | :outstanding_effect}

  @text_ops ~w(substituted inserted repealed renumbered amended)

  # a repeal "in part", "(except s. 31)", "in so far as …" isn't a repeal of
  # the provision (Jason, LR-06: "revoked in part")
  @in_part ~r/\bin part\b|\bpartially\b|\bexcept\b|\bso far as\b|\bto the extent\b/i

  @doc """
  The law's timeline. `rows`: `section_id`, `extent_code`, `markup_status`
  (the CLML's own status: "repealed" | "prospective" | nil). `changes`: the
  register's rows for the law (`section_id`, `evidence`, `operation`,
  `effect_type`, `affecting_law`, `in_force`, `effective_from`, `savings`,
  `via`, and optionally `prospective` / `applied`). Options: `today` (the UK date), `law_start` (the law's coming into
  force, `uk_lrt.md_coming_into_force_date`).
  """
  @spec timeline(String.t(), [map()], [map()], keyword()) :: %{
          periods: [Period.t()],
          gaps: [gap()]
        }
  def timeline(law_name, rows, changes, opts) do
    today = Keyword.fetch!(opts, :today)
    law_start = Keyword.get(opts, :law_start)

    by_row =
      changes
      |> Enum.filter(& &1.section_id)
      |> Enum.map(&normalise/1)
      |> Enum.group_by(& &1.section_id)

    {periods, gaps} =
      Enum.reduce(rows, {[], []}, fn row, {ps, gs} ->
        case row_timeline(law_name, row, relevant(row, by_row), law_start, today) do
          {:ok, p, g} -> {[p | ps], g ++ gs}
          {:gap, g} -> {ps, [g | gs]}
        end
      end)

    %{periods: periods |> Enum.reverse() |> List.flatten(), gaps: Enum.reverse(gaps)}
  end

  @doc """
  The UK date now: "today" for the timeline. In-force dates are UK dates;
  at 00:30 BST, UTC is still the previous day. BST runs from 01:00 UTC on
  the last Sunday of March to 01:00 UTC on the last Sunday of October.
  """
  @spec uk_today(DateTime.t()) :: Date.t()
  def uk_today(now \\ DateTime.utc_now()) do
    y = now.year
    starts = DateTime.new!(last_sunday(y, 3), ~T[01:00:00], "Etc/UTC")
    ends = DateTime.new!(last_sunday(y, 10), ~T[01:00:00], "Etc/UTC")
    bst? = DateTime.compare(now, starts) != :lt and DateTime.compare(now, ends) == :lt
    now |> DateTime.add(if(bst?, do: 3600, else: 0)) |> DateTime.to_date()
  end

  defp last_sunday(year, month) do
    last = Date.new!(year, month, Date.days_in_month(Date.new!(year, month, 1)))
    Date.add(last, -rem(Date.day_of_week(last), 7))
  end

  @doc "Each provision's period containing `date` (section_id → period); absent when unknown."
  @spec as_at([Period.t()], Date.t()) :: %{String.t() => Period.t()}
  def as_at(periods, date) do
    for p <- periods,
        Date.compare(p.valid_from, date) != :gt,
        p.valid_to == nil or Date.compare(date, p.valid_to) == :lt,
        into: %{},
        do: {p.section_id, p}
  end

  # the row's own changes, its ancestors' whole-provision ones; each tagged
  # with whether it is the row's own
  defp relevant(row, by_row) do
    [own | above] = LatStatus.ancestors(row.section_id)

    # a whole-instrument words-level change (a blanket "words substituted")
    # applies where the words occur, not to every row: it counts like an
    # ancestor's
    Map.get(by_row, own, [])
    |> Enum.reject(&("instrument" in (&1.via || []) and words_level?(&1)))
    |> Enum.map(&Map.put(&1, :own, true))
    |> Kernel.++(
      for(
        a <- above,
        c <- Map.get(by_row, a, []),
        not words_level?(c),
        do: Map.put(c, :own, false)
      )
    )
  end

  defp row_timeline(law, row, changes, law_start, today) do
    # J5: a note saying the provision was inserted (a pointer), or (LR-30) an
    # insertion of it or an ancestor that no source dates, withholds the
    # law's start: the provision didn't exist from then
    withheld? = Map.get(row, :inserted_pointer) || undated_insertion?(row, changes)
    law_start = if withheld?, do: nil, else: law_start

    case start(row, changes, law_start) do
      nil ->
        {:gap, {row.section_id, if(withheld?, do: :insertion_not_in_register, else: :no_start)}}

      {start, evidence?} ->
        bounds =
          changes
          |> Enum.flat_map(&dates/1)
          |> Enum.filter(&(Date.compare(&1, start) == :gt))
          |> Enum.concat([start])
          |> Enum.uniq()
          |> Enum.sort(Date)

        periods =
          bounds
          |> Enum.zip(tl(bounds) ++ [nil])
          |> Enum.map(fn {from, to} ->
            state(law, row, changes, from, to, start, evidence?)
          end)
          |> territories(row, changes, today)
          |> undated(row)
          |> merge()

        {periods, gaps} = markup_today(periods, row, today)

        {:ok, periods,
         gaps ++
           outstanding(periods, changes, row, today) ++
           if(Map.get(row, :undated_change), do: [{row.section_id, :undated_change}], else: [])}
    end
  end

  # J1: {start, whether it is evidence of commencement}
  defp start(row, changes, law_start) do
    insertion = insertion_date(row, changes)

    commencement =
      changes
      |> Enum.filter(&(&1.own and &1.operation == "commenced"))
      |> Enum.flat_map(&dates/1)
      |> Enum.min(Date, fn -> nil end)

    # a whole-instrument change says nothing about when this provision existed
    earliest =
      changes
      |> Enum.reject(&("instrument" in (&1.via || [])))
      |> Enum.flat_map(&dates/1)
      |> Enum.min(Date, fn -> nil end)

    cond do
      insertion -> {insertion, true}
      law_start -> {law_start, true}
      commencement -> {commencement, true}
      earliest -> {earliest, false}
      true -> nil
    end
  end

  # the row's insertion date: its own, else its nearest inserted ancestor's
  # (it came with that ancestor; LR-30)
  defp insertion_date(row, changes) do
    dated =
      for c <- changes,
          insertion?(c),
          for_row?(c, Map.get(row, :extent_code)),
          d <- dates(c),
          do: {c.section_id, d}

    row.section_id
    |> LatStatus.ancestors()
    |> Enum.find_value(fn sid ->
      dated
      |> Enum.filter(&(elem(&1, 0) == sid))
      |> Enum.map(&elem(&1, 1))
      |> Enum.min(Date, fn -> nil end)
    end)
  end

  # LR-30: an insertion of the row or an ancestor that no source dates (change
  # markup, or the amending law's record) while none is dated — not a
  # prospective one (not yet in force: approved as prospective from the law's
  # start)
  defp undated_insertion?(row, changes) do
    mine = Enum.filter(changes, &(insertion?(&1) and for_row?(&1, Map.get(row, :extent_code))))

    not Enum.any?(mine, &(dates(&1) != [])) and
      Enum.any?(mine, &(dates(&1) == [] and Map.get(&1, :prospective) != true))
  end

  defp insertion?(c), do: c.operation == "inserted" and not words_level?(c)

  defp state(law, row, changes, from, to, start, evidence?) do
    in_force =
      Enum.filter(changes, &(&1.effective_from && Date.compare(&1.effective_from, from) != :gt))

    repeal =
      in_force
      |> Enum.filter(&(&1.operation == "repealed" and not words_level?(&1)))
      |> Enum.filter(&covers_row?(&1, row.extent_code))
      |> latest()

    commencing = Enum.filter(changes, &commencing?/1)

    started? =
      Enum.any?(commencing, fn c -> Enum.any?(dates(c), &(Date.compare(&1, from) != :gt)) end)

    status =
      cond do
        repeal && repeal.savings != [] ->
          "repealed_saved"

        repeal ->
          "repealed"

        commencing != [] and not started? ->
          "prospective"

        EffectFacts.partial?(Enum.map(commencing, &effect/1), row.extent_code, from) ->
          "in_force_partial"

        true ->
          "in_force"
      end

    version =
      in_force
      |> Enum.filter(
        &(version?(&1) and for_row?(&1, row.extent_code) and
            (&1.operation != "repealed" or covers_row?(&1, row.extent_code)))
      )
      |> latest()

    {in_force_from, by, ids} =
      cond do
        status in ~w(prospective in_force_partial) ->
          {nil, nil, []}

        version ->
          {version.effective_from, not_self(version.affecting_law, law), [version.evidence]}

        evidence? ->
          {start, nil, []}

        true ->
          {nil, nil, []}
      end

    %Period{
      law_name: law,
      section_id: row.section_id,
      valid_from: from,
      valid_to: to,
      status: status,
      in_force_from: in_force_from,
      changed_by: by,
      change_ids: Enum.uniq(ids ++ if(repeal, do: [repeal.evidence], else: []))
    }
  end

  # a repeal makes the row repealed only where it reaches the row's whole
  # extent; one for part of it narrows the territory (LR-26). Its extent: the
  # territorial application, else the change's extent; none, or "same as
  # affected" (the feed spells it S+A+M+E+A+S+A+F+F+E+C+T+E+D), is the row's
  defp covers_row?(c, row_extent) do
    if Regex.match?(@in_part, c.effect_type || ""), do: false, else: extent_covers?(c, row_extent)
  end

  # LR-32: a change for one territory never dates another territory's
  # version (extent versions share an xml id, so a ref join reaches each:
  # ssi 2006/181's S insertion reached 1995/25 s.114(2)(a)(ix)[E+W]); a
  # change whose territory overlaps the row's still dates it
  defp for_row?(c, row_extent) do
    case {change_extent(c), row_extent} do
      {nil, _} -> true
      {_, nil} -> true
      {extent, row} -> not Territory.disjoint?(extent, row)
    end
  end

  defp extent_covers?(c, row_extent) do
    case change_extent(c) do
      nil -> true
      extent -> Territory.covers?(extent, row_extent)
    end
  end

  defp change_extent(c) do
    [Map.get(c, :territorial_application), Map.get(c, :effect_extent)]
    |> Enum.reject(&(&1 in [nil, ""] or same_as_affected?(&1)))
    |> List.first()
    |> Territory.normalize()
    |> Kernel.||(qualified_extent(c))
  end

  # in-force entries that each name a territory ("for E.", "for W."): the
  # change reaches their union
  defp qualified_extent(c) do
    ts =
      for e <- c.in_force,
          do: e.qualification && EffectTerritory.qualifier_territory(e.qualification)

    if ts != [] and Enum.all?(ts), do: Territory.union(ts)
  end

  defp same_as_affected?(code),
    do:
      code
      |> String.replace(~r/[^A-Za-z]/, "")
      |> String.upcase()
      |> String.starts_with?("SAMEAS")

  # a version starts with a text change (an ancestor's only when whole-
  # provision; a repeal only where it reaches the row's whole extent) or a
  # commencement — never a modification
  defp version?(%{operation: op}) when op in @text_ops, do: true
  defp version?(%{operation: "commenced"}), do: true
  defp version?(_change), do: false

  # the provision's own commencement: a commencement, or its own
  # whole-provision insertion / substitution
  # — and only when it says something about when: a dated entry, or a
  # genuinely prospective change (not yet applied to the text). Change markup
  # no effect explains (undated) and an applied change with no date say
  # nothing (1990/43 s.78B(2))
  defp commencing?(c), do: commencing_kind?(c) and informative?(c)

  defp commencing_kind?(%{operation: "commenced"}), do: true

  defp commencing_kind?(%{own: true, operation: op} = c) when op in ~w(inserted substituted),
    do: not words_level?(c)

  defp commencing_kind?(_change), do: false

  defp informative?(c),
    do: dates(c) != [] or (Map.get(c, :prospective) == true and Map.get(c, :applied) != true)

  # consecutive periods with the same labels become one
  defp merge(periods) do
    periods
    |> Enum.chunk_while(
      nil,
      fn
        p, nil ->
          {:cont, p}

        p, acc ->
          if same?(p, acc),
            do:
              {:cont,
               %{
                 acc
                 | valid_to: p.valid_to,
                   change_ids: Enum.uniq(acc.change_ids ++ p.change_ids)
               }},
            else: {:cont, acc, p}
      end,
      fn
        nil -> {:cont, nil}
        acc -> {:cont, acc, nil}
      end
    )
  end

  defp same?(a, b),
    do:
      {a.status, a.in_force_from, a.changed_by, a.territory} ==
        {b.status, b.in_force_from, b.changed_by, b.territory}

  # J2: the markup's repealed / prospective wins the period containing today
  defp markup_today(periods, %{markup_status: markup} = row, today)
       when markup in ["repealed", "prospective"] do
    current = Enum.find_index(periods, &covers?(&1, today))

    case current && Enum.at(periods, current) do
      %Period{status: status} = p when status != markup ->
        if markup == "repealed" and status == "repealed_saved" do
          {periods, []}
        else
          fixed = %{p | status: markup, in_force_from: nil, changed_by: nil}
          {List.replace_at(periods, current, fixed), [{row.section_id, :markup_conflict}]}
        end

      _ ->
        {periods, []}
    end
  end

  defp markup_today(periods, _row, _today), do: {periods, []}

  # LR-26 D1′ (Jason 2026-10-13: "we have to publish what we know is true"):
  # each period's territory. Today's period: the row's extent minus its
  # excluded extent (the parse's reviewed calculation). Earlier periods: the
  # extent, with an exclusion rolled back before its date only when every
  # claim behind it is a dated removal with one date; else unknown (nil).
  # Later periods: today's territory narrowed by dated territorial repeals
  # from their dates; a staged one is unknown. Nothing left: status
  # repealed, territory nil ("nowhere"); a repealed period has no territory.
  defp territories(periods, row, changes, today) do
    extent = Territory.normalize(Map.get(row, :extent_code))
    excluded = Territory.normalize(Map.get(row, :excluded_extent))
    by_ev = Map.new(changes, &{&1.evidence, &1})
    claims = Map.get(row, :claims) || []

    now =
      if excluded,
        do: Territory.subtract(extent || "E+W+S+NI", excluded) || :nowhere,
        else: extent

    # a provision not yet in force anywhere: its whole extent is "excluded"
    # because nothing is live, not because a repeal took it — no territory
    # fact; unknown in every period, never "nowhere"
    not_commenced? =
      excluded != nil and excluded == extent and
        (Map.get(row, :markup_status) == "prospective" or
           Enum.any?(periods, &(covers?(&1, today) and &1.status == "prospective")))

    rollback =
      cond do
        not_commenced? -> :unknown
        extent == nil or extent_change?(changes) -> :unknown
        excluded == nil -> []
        claims != [] and Enum.all?(claims, &removal_date(&1, by_ev)) -> claims
        true -> :unknown
      end

    Enum.map(periods, fn p ->
      t =
        cond do
          extent == nil or not_commenced? ->
            nil

          covers?(p, today) ->
            now

          Date.compare(p.valid_from, today) == :gt ->
            later(now, changes, row, today, p.valid_from)

          rollback == :unknown ->
            nil

          true ->
            earlier(extent, excluded, rollback, by_ev, p.valid_from)
        end

      cond do
        p.status in ~w(repealed repealed_saved) ->
          %{p | territory: nil}

        t == :nowhere ->
          %{p | status: "repealed", territory: nil, in_force_from: nil, changed_by: nil}

        true ->
          %{p | territory: t}
      end
    end)
  end

  # before today: the extent minus the exclusions whose (removal) claims are
  # in force at the period's start
  defp earlier(extent, nil, _claims, _by_ev, _from), do: extent

  defp earlier(extent, excluded, claims, by_ev, from) do
    live =
      for c <- claims,
          d = removal_date(c, by_ev),
          Date.compare(d, from) != :gt,
          t = Territory.normalize(c.territory),
          t != nil,
          do: t

    case live do
      [] -> extent
      ts -> Territory.subtract(extent, intersect(excluded, Territory.union(ts))) || :nowhere
    end
  end

  # after today: territorial repeals (whole provision, not "in part") from
  # their dates; a staged one (several dates) is unknown
  defp later(nil, _changes, _row, _today, _from), do: nil
  defp later(:nowhere, _changes, _row, _today, _from), do: :nowhere

  defp later(now, changes, row, today, from) do
    repeals =
      for c <- changes,
          c.operation == "repealed",
          not words_level?(c),
          not Regex.match?(@in_part, c.effect_type || ""),
          d = c.effective_from,
          d != nil,
          Date.compare(d, today) == :gt,
          Date.compare(d, from) != :gt,
          do: c

    Enum.reduce_while(repeals, now, fn c, t ->
      cond do
        t == :nowhere -> {:halt, :nowhere}
        length(Enum.uniq(dates(c))) > 1 -> {:halt, nil}
        covers_row?(c, Map.get(row, :extent_code)) -> {:cont, :nowhere}
        ext = change_extent(c) -> {:cont, Territory.subtract(t, ext) || :nowhere}
        true -> {:cont, t}
      end
    end)
  end

  # a claim's removal date: its effect is a dated repeal with one date
  defp removal_date(%{effect_id: id}, by_ev) when is_binary(id) do
    case by_ev[id] do
      %{operation: "repealed"} = c ->
        case Enum.uniq(dates(c)) do
          [d] -> d
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp removal_date(_claim, _by_ev), do: nil

  defp extent_change?(changes),
    do:
      Enum.any?(
        changes,
        &Regex.match?(~r/\bextent (?:extended|restricted|changed)\b/i, &1.effect_type || "")
      )

  defp intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "") || a

  # T1 (Jason 2026-10-13: "a text change we cannot date should communicate
  # that fact"): the row has a text change no source dates (undated change
  # markup; an amendment note naming a law with no dated change on the row),
  # so no in-force period can say since when its current text applies —
  # in_force_from and changed_by are empty while the status stands
  defp undated(periods, %{undated_change: true}) do
    for p <- periods do
      if p.status in ~w(in_force), do: %{p | in_force_from: nil, changed_by: nil}, else: p
    end
  end

  defp undated(periods, _row), do: periods

  # J4: repealed today by a repeal legislation.gov.uk hasn't applied to the
  # revised text yet — the status stands (the law outranks the derived
  # text); listed as a source-side "outstanding effect"
  defp outstanding(periods, changes, row, today) do
    current = Enum.find(periods, &covers?(&1, today))

    unapplied? =
      current && current.status in ~w(repealed repealed_saved) &&
        Enum.any?(changes, fn c ->
          c.evidence in current.change_ids and Map.get(c, :applied) == false and
            c.operation == "repealed"
        end)

    if unapplied?, do: [{row.section_id, :outstanding_effect}], else: []
  end

  defp covers?(p, date),
    do:
      Date.compare(p.valid_from, date) != :gt and
        (p.valid_to == nil or Date.compare(date, p.valid_to) == :lt)

  defp not_self(nil, _law), do: nil
  defp not_self(by, law), do: if(NotePointer.same_law?(by, law), do: nil, else: by)

  defp dates(c) do
    entries = for e <- c.in_force, d = e.date, d != nil, do: d
    Enum.uniq(entries ++ List.wrap(c.effective_from))
  end

  defp words_level?(c),
    do: EffectIndex.words_level?(%Effect{type: c.effect_type || "", affecting: nil})

  defp effect(c),
    do: %Effect{type: c.effect_type || "", affecting: c.affecting_law, in_force: c.in_force}

  # register rows as maps: in-force entries with atom keys and dates
  defp normalise(c) do
    entries =
      for e <- c.in_force || [] do
        e = Map.new(e, fn {k, v} -> {to_string(k), v} end)

        %{
          date: date(e["date"]),
          qualification: e["qualification"],
          prospective: e["prospective"],
          applied: e["applied"]
        }
      end

    %{c | in_force: entries}
    |> Map.put(:effective_from, date(c.effective_from))
    |> Map.put(:savings, c.savings || [])
  end

  defp date(nil), do: nil
  defp date(%Date{} = d), do: d
  defp date(s) when is_binary(s), do: Date.from_iso8601!(s)

  # The change that took effect last. On the same day: the change itself
  # before its commencement (changed_by names the law that made the change,
  # not the order that commenced it: anaw 2017/3 s.42(1A)), then a stable
  # order (law, effect id), so the label never depends on the order changes
  # arrive in (LR-29: same-day ties gave different labels run to run)
  defp latest([]), do: nil

  defp latest(changes),
    do:
      Enum.max_by(changes, fn c ->
        {if(c.effective_from, do: Date.to_gregorian_days(c.effective_from), else: -1),
         if(c.operation == "commenced", do: 0, else: 1), c.affecting_law || "", c.evidence || ""}
      end)
end
