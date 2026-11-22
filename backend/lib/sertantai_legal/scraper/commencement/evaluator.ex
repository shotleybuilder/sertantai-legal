defmodule SertantaiLegal.Scraper.Commencement.Evaluator do
  @moduledoc """
  When a provision came into force, and how far, from commencement rules
  alone (commencement-rules CR-02). Every consumer asks it: a labelled
  law's provisions, an amending provision, a by-order row. Pure.

  - **Which rules reach the provision.** A rule's scope covers it by its own
    ref, a bracket ancestor ("s.12" for "s.12(3)(a)"), a container
    `ctx.ancestors` gives ("pt.2" for "s.12"), a range ("s.1..s.5"), `:rest`
    or `:all`; `except` leaves refs out.
  - **Within one source the most specific rule wins**: the nearest ref, then
    `:rest` (what the source's other rules don't name), then `:all` (which,
    like `:rest`, doesn't reach what another rule of the source names). So
    "s.62 on 23 March 2027; otherwise on Royal Assent" dates s.62 once.
    Where the most specific are all partial ("Regulation 26 … with respect
    to any tip which was not a classified tip", "… in relation to Wales on
    1 October"), the next rule down still applies, partly: fully in force
    once both have started.
  - **Across sources every covering rule applies, in date order**: an
    order's "remaining provisions" reaches a provision an earlier order
    brought in for specified purposes; it is fully in force from the first
    full entry (Gemini 2026-10-18).
  - **Full**: no purposes, and no territory — or territories that together
    cover the provision's extent (`ctx.extent`: England in 2017 and Wales in
    2019 bring an E+W provision fully into force in 2019). With no extent
    known a territorial entry stays partial.
  - **When**: dates; made / passed + an offset (`ctx.made`, `ctx.passed`);
    exit day 2020-01-31, IP completion day 2020-12-31 (LR-33's); `with`
    another provision (`ctx.with`, ref → date); `appointed` and `unread`
    are undated and listed in `undated`.

  `ctx`: `made`, `passed`, `extent`, `ancestors` (top ref → containers,
  nearest first), `order` (refs in document order, for ranges), `with`.
  """

  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.LatRef

  @named_days %{exit_day: ~D[2020-01-31], ip_completion_day: ~D[2020-12-31]}

  @type entry :: %{
          date: Date.t() | nil,
          territory: String.t() | nil,
          purposes: Rule.purposes(),
          rule: Rule.t(),
          role: :normal | :general | :completes
        }
  @type result :: %{
          entries: [entry()],
          full_from: Date.t() | nil,
          partial_from: Date.t() | nil,
          undated: [Rule.t()]
        }

  @doc "The provision's in-force entries (date order), when it was fully and partly in force, and its undated rules."
  @spec evaluate([Rule.t()], String.t(), map()) :: result()
  def evaluate(rules, provision, ctx \\ %{}) do
    chain = chain(provision, ctx)

    entries =
      rules
      # a Schedule's introducing provision is no date of its own
      # (`Commencement.ScheduleEffect`; read by the amending-law reader)
      |> Enum.reject(&(&1.treatment == :schedule_effect))
      |> Enum.group_by(& &1.source.law)
      |> Enum.flat_map(fn {_source, rs} -> most_specific(rs, chain, ctx) end)
      |> Enum.map(fn {r, role} ->
        %{
          date: date(r.when, ctx),
          territory: r.territory,
          purposes: r.purposes,
          rule: r,
          role: role
        }
      end)
      |> Enum.sort_by(& &1.date, &later_or_nil/2)

    full_from = full_from(entries, ctx[:extent])

    first =
      entries |> Enum.map(& &1.date) |> Enum.reject(&is_nil/1) |> Enum.min(Date, fn -> nil end)

    %{
      entries: entries,
      full_from: full_from,
      partial_from:
        if(first && (full_from == nil or Date.compare(first, full_from) == :lt), do: first),
      undated: for(%{date: nil, rule: r} <- entries, do: r)
    }
  end

  @doc """
  The result as register in-force entries (CR-06): each partial start
  before the provision was fully in force, qualified in the changes feed's
  words (`Rule.qualification/2`; a general rule a partial one completes is
  "for certain purposes" until both have started), then the full start,
  unqualified. `[%{date, qualification}]`, date order.
  """
  @spec in_force(result()) :: [%{date: Date.t(), qualification: String.t() | nil}]
  def in_force(%{entries: entries, full_from: full}) do
    partial =
      for e <- entries,
          e.date != nil,
          full == nil or Date.compare(e.date, full) == :lt,
          do: %{date: e.date, qualification: partial_words(e)}

    full_entry = if full, do: [%{date: full, qualification: nil}], else: []

    Enum.uniq(partial ++ full_entry)
  end

  # before the full start every entry is partial: an unqualified one is a
  # general rule a partial one completes
  defp partial_words(e),
    do: Rule.qualification(e.territory, e.purposes) || "for certain purposes"

  @doc "The provision's status on `date`: fully or partly in force, prospective (a rule reaches it, not yet), or unknown (none does, or only an unread one)."
  @spec status(result(), Date.t()) :: :in_force | :in_force_partial | :prospective | :unknown
  def status(%{entries: entries, full_from: full, partial_from: partial}, date) do
    cond do
      full && Date.compare(full, date) != :gt -> :in_force
      partial && Date.compare(partial, date) != :gt -> :in_force_partial
      Enum.any?(entries, &(&1.rule.when != :unread)) -> :prospective
      true -> :unknown
    end
  end

  # the provision, its bracket ancestors, then its containers — most
  # specific first (`LatRef.chain/2`)
  defp chain(provision, ctx), do: LatRef.chain(provision, ctx)

  # a source document's rules (its clauses together) reaching the provision,
  # most specific only, each with its role: `:normal`; or, where the most
  # specific are all partial ("Regulation 26 … with respect to any tip which
  # was not a classified tip"), they `:complete` the next rule down, which
  # still applies as `:general` — partly in force from it, fully once both
  # have started (CR-03: Quarries Regulations reg.26)
  defp most_specific(rules, chain, ctx) do
    # each rule scored once for the provision (whether excepted, and the
    # nearest chain position its refs reach), never once per pass: 2003
    # c.21's 1,532 rules over 3,967 rows were covered three times a row
    scored = for r <- rules, do: {r, excepted?(r, chain, ctx), refs_index(r, chain, ctx)}

    case ranked(scored, named?(scored)) do
      [] -> []
      ranked -> pick(ranked, scored)
    end
  end

  # a rule naming the provision, not excepting it
  defp named?(scored),
    do:
      Enum.any?(scored, fn {r, excepted?, i} ->
        is_list(r.scope) and i != nil and not excepted?
      end)

  # the best-ranked rules; where none is full, with the next rank's rules
  # they complete
  defp pick(ranked, scored) do
    best = ranked |> Enum.map(&elem(&1, 0)) |> Enum.min()
    top = for {^best, r} <- ranked, do: r
    below = scored |> ranked(false) |> Enum.filter(&(elem(&1, 0) > best))

    if Enum.all?(top, &(not Rule.full?(&1))) and below != [] do
      next = below |> Enum.map(&elem(&1, 0)) |> Enum.min()
      Enum.map(top, &{&1, :completes}) ++ for({^next, r} <- below, do: {r, :general})
    else
      Enum.map(top, &{&1, :normal})
    end
  end

  defp ranked(scored, named?) do
    for {r, false, i} <- scored,
        rank = rank(r, i, named?),
        rank != nil,
        do: {rank, r}
  end

  defp rank(%Rule{scope: refs}, i, _named?) when is_list(refs), do: i
  defp rank(%Rule{scope: :rest}, _i, false), do: 1_000
  defp rank(%Rule{scope: :all}, _i, false), do: 2_000
  defp rank(_rule, _i, true), do: nil

  # the nearest chain position a ref of the rule reaches (nil: none, or a
  # rule naming no refs)
  defp refs_index(%Rule{scope: refs}, chain, ctx) when is_list(refs) do
    chain
    |> Enum.with_index()
    |> Enum.find_value(fn {el, i} -> if Enum.any?(refs, &covers?(&1, el, ctx)), do: i end)
  end

  defp refs_index(_rule, _chain, _ctx), do: nil

  defp excepted?(%Rule{except: except}, chain, ctx),
    do: Enum.any?(chain, fn el -> Enum.any?(except, &covers?(&1, el, ctx)) end)

  defp covers?(ref, el, ctx), do: LatRef.covers?(ref, el, ctx)

  defp date({:date, d}, _ctx), do: d

  defp date({:after, basis, {n, unit}}, ctx) do
    case ctx[basis] do
      nil -> nil
      base when unit == :day -> Date.add(base, n)
      base -> Date.shift(base, month: n)
    end
  end

  defp date({:named_day, day}, _ctx), do: Map.fetch!(@named_days, day)

  defp date({:with, ref}, ctx) do
    case ctx[:with] do
      nil -> nil
      f -> f.(ref)
    end
  end

  defp date(_appointed_or_unread, _ctx), do: nil

  # fully in force: the first entry with no purposes and no territory, the
  # date territorial entries together first cover the extent, or the date a
  # completing rule and the general rule it completes have both started —
  # for the general rule's place where it holds one (Water Act 2014
  # s.10(1): England's by SI 2017/462, Wales's still to come)
  defp full_from(entries, extent) do
    dated = for %{date: %Date{}, purposes: nil, role: :normal} = e <- entries, do: e
    stages = dated ++ completed(entries)
    plain = for %{territory: nil, date: d} <- stages, do: d
    territorial = covered(Enum.filter(stages, & &1.territory), extent)

    Enum.min(Enum.reject([territorial | plain], &is_nil/1), Date, fn -> nil end)
  end

  defp completed(entries) do
    general = for %{role: :general} = e <- entries, do: e
    dates = Enum.map(general, & &1.date)

    for %{role: :completes, date: %Date{} = d} <- entries,
        general != [] and Enum.all?(dates, &is_struct(&1, Date)),
        do: %{date: Enum.max([d | dates], Date), territory: place(general)}
  end

  # the general rules' place: nil (everywhere) unless each holds one
  defp place(general) do
    if Enum.any?(general, &is_nil(&1.territory)),
      do: nil,
      else: general |> Enum.map(& &1.territory) |> Enum.join("+")
  end

  # the date territorial stages together first cover the extent
  defp covered(_stages, nil), do: nil

  defp covered(stages, extent) do
    need = codes(extent)

    stages
    |> Enum.sort_by(& &1.date, Date)
    |> Enum.reduce_while(MapSet.new(), fn e, have ->
      have = MapSet.union(have, codes(e.territory))
      if MapSet.subset?(need, have), do: {:halt, e.date}, else: {:cont, have}
    end)
    |> then(&if(is_struct(&1, Date), do: &1))
  end

  defp codes(territory), do: territory |> String.split("+", trim: true) |> MapSet.new()

  defp later_or_nil(nil, _), do: false
  defp later_or_nil(_, nil), do: true
  defp later_or_nil(a, b), do: Date.compare(a, b) != :gt
end
