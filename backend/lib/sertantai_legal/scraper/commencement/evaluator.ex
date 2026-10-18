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
  # specific first ("s.12(3)(a)", "s.12(3)", "s.12", "pt.2.ch.1", "pt.2")
  defp chain(provision, ctx) do
    ref =
      provision
      |> String.split(":", parts: 2)
      |> List.last()
      |> String.replace(~r/\[[^\]]*\]$/, "")
      # a duplicate id's disambiguator (LR-13: "s.153(1)(n)#2", "s.33(2)(a)n1")
      |> String.replace(~r/(?<=\))(?:#\d+|n\d+)$|#\d+$/, "")

    brackets =
      Stream.iterate(ref, &String.replace(&1, ~r/\([^()]*\)$/, ""))
      |> Enum.reduce_while([], fn r, acc ->
        if acc != [] and hd(acc) == r, do: {:halt, acc}, else: {:cont, [r | acc]}
      end)
      |> Enum.reverse()

    containers =
      case ctx[:ancestors] do
        nil -> []
        f -> f.(List.last(brackets))
      end

    brackets ++ containers
  end

  # a source document's rules (its clauses together) reaching the provision,
  # most specific only, each with its role: `:normal`; or, where the most
  # specific are all partial ("Regulation 26 … with respect to any tip which
  # was not a classified tip"), they `:complete` the next rule down, which
  # still applies as `:general` — partly in force from it, fully once both
  # have started (CR-03: Quarries Regulations reg.26)
  defp most_specific(rules, chain, ctx) do
    named? =
      Enum.any?(
        rules,
        &(is_list(&1.scope) and refs_index(&1, chain, ctx) != nil and
            not excepted?(&1, chain, ctx))
      )

    ranked = ranked(rules, chain, ctx, named?)

    case ranked do
      [] ->
        []

      _ ->
        best = ranked |> Enum.map(&elem(&1, 0)) |> Enum.min()
        top = for {^best, r} <- ranked, do: r

        below =
          rules
          |> ranked(chain, ctx, false)
          |> Enum.filter(&(elem(&1, 0) > best))

        if Enum.all?(top, &(not Rule.full?(&1))) and below != [] do
          next = below |> Enum.map(&elem(&1, 0)) |> Enum.min()
          Enum.map(top, &{&1, :completes}) ++ for({^next, r} <- below, do: {r, :general})
        else
          Enum.map(top, &{&1, :normal})
        end
    end
  end

  defp ranked(rules, chain, ctx, named?) do
    for r <- rules,
        not excepted?(r, chain, ctx),
        rank = rank(r, chain, ctx, named?),
        rank != nil,
        do: {rank, r}
  end

  defp rank(%Rule{scope: refs} = r, chain, ctx, _named?) when is_list(refs),
    do: refs_index(r, chain, ctx)

  defp rank(%Rule{scope: :rest}, _chain, _ctx, false), do: 1_000
  defp rank(%Rule{scope: :all}, _chain, _ctx, false), do: 2_000
  defp rank(_rule, _chain, _ctx, true), do: nil

  # the nearest chain position a ref of the rule reaches
  defp refs_index(%Rule{scope: refs}, chain, ctx) do
    chain
    |> Enum.with_index()
    |> Enum.find_value(fn {el, i} -> if Enum.any?(refs, &covers?(&1, el, ctx)), do: i end)
  end

  defp excepted?(%Rule{except: except}, chain, ctx),
    do: Enum.any?(chain, fn el -> Enum.any?(except, &covers?(&1, el, ctx)) end)

  defp covers?(ref, el, ctx) do
    case String.split(ref, "..", parts: 2) do
      [from, to] -> in_range?(el, from, to, ctx)
      [_] -> ref == el
    end
  end

  # ranges reach whole provisions (no brackets) — or, for a range of
  # brackets ("sch.21.para.2(1)..sch.21.para.2(3)"), provisions at that
  # depth: by document order, else by number
  defp in_range?(el, from, to, ctx) do
    if String.contains?(el, "(") != String.contains?(from, "(") do
      false
    else
      case ctx[:order] do
        nil -> numeric_between?(el, from, to)
        order -> ordered_between?(order, el, from, to)
      end
    end
  end

  defp ordered_between?(order, el, from, to) do
    pos = order |> Enum.with_index() |> Map.new()

    with a when is_integer(a) <- pos[from],
         b when is_integer(b) <- pos[to],
         i when is_integer(i) <- pos[el] do
      a <= i and i <= b
    else
      _ -> false
    end
  end

  defp numeric_between?(el, from, to) do
    with {p, k} <- key(el), {^p, a} <- key(from), {^p, b} <- key(to) do
      a <= k and k <= b
    else
      _ -> false
    end
  end

  # by its last number: "s.4A" → {"s.", {4, "A"}}; "sch.10.para.3" →
  # {"sch.10.para.", {3, ""}}; "sch.21.para.2(3)" → {"sch.21.para.2(", {3, ""}}
  defp key(ref) do
    case Regex.run(~r/^(.*?)(\d+)([A-Z]*)\)?$/, ref) do
      [_, prefix, n, letters] when prefix != "" -> {prefix, {String.to_integer(n), letters}}
      _ -> nil
    end
  end

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
  # completing rule and the general rule it completes have both started
  defp full_from(entries, extent) do
    dated = for %{date: %Date{}, purposes: nil, role: :normal} = e <- entries, do: e

    plain = for %{territory: nil, date: d} <- dated, do: d

    general = for %{role: :general, date: d} <- entries, do: d

    completed =
      for %{role: :completes, date: %Date{} = d} <- entries,
          general != [] and Enum.all?(general, &is_struct(&1, Date)),
          do: Enum.max([d | general], Date)

    territorial =
      case extent && codes(extent) do
        nil ->
          nil

        need ->
          dated
          |> Enum.filter(& &1.territory)
          |> Enum.sort_by(& &1.date, Date)
          |> Enum.reduce_while(MapSet.new(), fn e, have ->
            have = MapSet.union(have, codes(e.territory))
            if MapSet.subset?(need, have), do: {:halt, e.date}, else: {:cont, have}
          end)
          |> then(&if(is_struct(&1, Date), do: &1))
      end

    Enum.min(Enum.reject([territorial | plain ++ completed], &is_nil/1), Date, fn -> nil end)
  end

  defp codes(territory), do: territory |> String.split("+", trim: true) |> MapSet.new()

  defp later_or_nil(nil, _), do: false
  defp later_or_nil(_, nil), do: true
  defp later_or_nil(a, b), do: Date.compare(a, b) != :gt
end
