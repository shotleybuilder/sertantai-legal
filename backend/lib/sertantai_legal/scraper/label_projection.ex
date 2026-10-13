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
    make a commencement partial (`ChangeFacts.partial?/3`).
  - **D1 version.** `in_force_from` is when the current text took effect:
    the latest text change (substituted, inserted, repealed, renumbered,
    amended) or commencement in force at T, else the start when it is
    evidence of commencement; `changed_by` is that change's law, nil for
    the law itself. Modifications and applications never start a version.
    Empty while prospective or partly in force.
  - **D3 status at T.** repealed (repealed_saved with savings) from a
    whole-provision repeal in force at T; prospective while a commencing
    change (commencement, the row's own insertion or substitution) has no
    entry in force at T; in_force_partial while a commencement is partial;
    else in_force.
  - **J1 start.** The row's own insertion (it didn't exist before), else the
    law's coming into force (`law_start`), else its own commencement, else
    the earliest change held; with none, no periods (a `:no_start` gap).
    Before the start: no period ("unknown").
  - **J2 today.** Where the CLML markup says repealed or prospective and
    the period containing today disagrees, the markup wins for that period
    and the disagreement is a `:markup_conflict` gap.

  Notes are never read. Pure: `today` and `law_start` are passed in.
  """

  alias SertantaiLegal.Scraper.{AmendmentNote, ChangeFacts, EffectIndex, LatStatus}
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
            change_ids: [String.t()]
          }
  end

  @type gap :: {String.t(), :no_start | :markup_conflict}

  @text_ops ~w(substituted inserted repealed renumbered amended)

  @doc """
  The law's timeline. `rows`: `section_id`, `extent_code`, `markup_status`
  (the CLML's own status: "repealed" | "prospective" | nil). `changes`: the
  register's rows for the law (`section_id`, `evidence`, `operation`,
  `effect_type`, `affecting_law`, `in_force`, `effective_from`, `savings`,
  `via`). Options: `today` (the UK date), `law_start` (the law's coming into
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

    Enum.map(Map.get(by_row, own, []), &Map.put(&1, :own, true)) ++
      for(
        a <- above,
        c <- Map.get(by_row, a, []),
        not words_level?(c),
        do: Map.put(c, :own, false)
      )
  end

  defp row_timeline(law, row, changes, law_start, today) do
    case start(changes, law_start) do
      nil ->
        {:gap, {row.section_id, :no_start}}

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
          |> merge()

        {periods, gaps} = markup_today(periods, row, today)
        {:ok, periods, gaps}
    end
  end

  # J1: {start, whether it is evidence of commencement}
  defp start(changes, law_start) do
    insertion =
      changes
      |> Enum.filter(&(&1.own and &1.operation == "inserted" and not words_level?(&1)))
      |> Enum.flat_map(&dates/1)
      |> Enum.min(Date, fn -> nil end)

    commencement =
      changes
      |> Enum.filter(&(&1.own and &1.operation == "commenced"))
      |> Enum.flat_map(&dates/1)
      |> Enum.min(Date, fn -> nil end)

    earliest = changes |> Enum.flat_map(&dates/1) |> Enum.min(Date, fn -> nil end)

    cond do
      insertion -> {insertion, true}
      law_start -> {law_start, true}
      commencement -> {commencement, true}
      earliest -> {earliest, false}
      true -> nil
    end
  end

  defp state(law, row, changes, from, to, start, evidence?) do
    in_force =
      Enum.filter(changes, &(&1.effective_from && Date.compare(&1.effective_from, from) != :gt))

    repeal =
      in_force
      |> Enum.filter(&(&1.operation == "repealed" and not words_level?(&1)))
      |> Enum.max_by(& &1.effective_from, Date, fn -> nil end)

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

        ChangeFacts.partial?(Enum.map(commencing, &effect/1), row.extent_code, from) ->
          "in_force_partial"

        true ->
          "in_force"
      end

    version =
      in_force
      |> Enum.filter(&version?/1)
      |> Enum.max_by(& &1.effective_from, Date, fn -> nil end)

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

  # a version starts with a text change (an ancestor's only when whole-
  # provision) or a commencement — never a modification
  defp version?(%{operation: op}) when op in @text_ops, do: true
  defp version?(%{operation: "commenced"}), do: true
  defp version?(_change), do: false

  # the provision's own commencement: a commencement, or its own
  # whole-provision insertion / substitution
  defp commencing?(%{operation: "commenced"}), do: true

  defp commencing?(%{own: true, operation: op} = c) when op in ~w(inserted substituted),
    do: not words_level?(c)

  defp commencing?(_change), do: false

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
    do: {a.status, a.in_force_from, a.changed_by} == {b.status, b.in_force_from, b.changed_by}

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

  defp covers?(p, date),
    do:
      Date.compare(p.valid_from, date) != :gt and
        (p.valid_to == nil or Date.compare(date, p.valid_to) == :lt)

  defp not_self(nil, _law), do: nil
  defp not_self(by, law), do: if(AmendmentNote.same_law?(by, law), do: nil, else: by)

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
end
