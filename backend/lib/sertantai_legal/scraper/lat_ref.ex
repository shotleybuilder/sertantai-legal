defmodule SertantaiLegal.Scraper.LatRef do
  @moduledoc """
  LAT refs as the rulesets match them (amendment-rules AR-02): a row's
  chain — the provision, its bracket ancestors, then its containers, most
  specific first — and whether a rule's ref covers a chain element (itself,
  or a range "s.41..s.43" by document order, else by number).

  Shared by both evaluators: `Commencement.Evaluator` (CR-02; moved onto
  this module at AR-04) and `Amendment.Evaluator`. Pure.
  """

  @doc """
  A row's chain, most specific first: "UK_x:s.12(3)(a)[E+W]" → ["s.12(3)(a)",
  "s.12(3)", "s.12"] ++ `ctx.ancestors.("s.12")` (containers, nearest first).
  An extent suffix and a duplicate id's disambiguator ("#2", "n1") are dropped.
  """
  @spec chain(String.t(), map()) :: [String.t()]
  def chain(section_id, ctx \\ %{}) do
    ref = bare(section_id)

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

    # every Schedule of the law ("Regulations 5 to 27 and the Schedules":
    # SI 1992/3004 reg.1(3), CV-S04) holds a Schedule's provisions
    schedules = if String.starts_with?(ref, "sch."), do: ["sch"], else: []

    brackets ++ containers ++ schedules
  end

  @doc """
  A row's section_id, then its levels as section_ids, for the labels
  (`LabelProjection`, `LabelTimeline`, the collectors): as
  `LatStatus.ancestors/1` — an extent version's tagged levels, then the
  untagged ones — but read past a disambiguator: "L:s.1(2)n1" → ["L:s.1(2)n1",
  "L:s.1(2)", "L:s.1"] (V1-03: asp 2002/3 s.1(2)n1 had no ancestors).
  `LatStatus.ancestors/1` stays the parser's.
  """
  @spec ancestors(String.t()) :: [String.t()]
  def ancestors(section_id) do
    case Regex.run(~r/\A(.+?)(\[[^\]]*\])\z/, section_id) do
      [_, untagged, tag] ->
        levels = levels(undisambiguated(untagged))
        Enum.uniq([section_id | Enum.map(levels, &(&1 <> tag))] ++ levels)

      nil ->
        Enum.uniq([section_id | levels(undisambiguated(section_id))])
    end
  end

  defp levels(id) do
    case Regex.run(~r/\A(.+)\([^()]*\)\z/, id) do
      [_, parent] -> [id | levels(parent)]
      nil -> [id]
    end
  end

  defp undisambiguated(id), do: String.replace(id, ~r/(?<=[)0-9A-Za-z])n\d+\z/, "")

  @doc "A section_id's ref: no law, no extent suffix, no disambiguator (\"UK_x:s.33(2)(a)n1\" → \"s.33(2)(a)\")."
  @spec bare(String.t()) :: String.t()
  def bare(section_id) do
    section_id
    |> String.split(":", parts: 2)
    |> List.last()
    |> String.replace(~r/\[[^\]]*\]$/, "")
    # a duplicate id's disambiguator (LR-13: "s.153(1)(n)#2", "s.33(2)(a)n1")
    |> String.replace(~r/(?<=\))(?:#\d+|n\d+)$|#\d+$/, "")
  end

  @doc """
  Does `ref` cover the chain element `el`: equal, or a range ("s.41..s.43")
  holding it — whole provisions only (or, for a range of brackets, that
  depth): by document order (`ctx.order`), else by number.
  """
  @spec covers?(String.t(), String.t(), map()) :: boolean()
  def covers?(ref, el, ctx \\ %{}) do
    case String.split(ref, "..", parts: 2) do
      [from, to] -> in_range?(el, from, to, ctx)
      [_] -> ref == el or same_part_numeral?(ref, el)
    end
  end

  # a Schedule's Part written either way: "sch.16.pt.1" is "sch.16.pt.I"
  # (orders differ: CV-S04 round 4, N4)
  @numerals ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX)

  defp same_part_numeral?(a, b) do
    String.contains?(a, ".pt.") and String.contains?(b, ".pt.") and arabic(a) == arabic(b)
  end

  defp arabic(ref) do
    Regex.replace(~r/\.pt\.([IVX]+)(?=$|[.(\[])/, ref, fn whole, numeral ->
      case Enum.find_index(@numerals, &(&1 == numeral)) do
        nil -> whole
        i -> ".pt.#{i + 1}"
      end
    end)
  end

  defp in_range?(el, from, to, ctx) do
    cond do
      String.contains?(from, "(") != String.contains?(to, "(") ->
        mixed_between?(el, from, to)

      String.contains?(el, "(") != String.contains?(from, "(") ->
        false

      true ->
        same_depth_between?(el, from, to, ctx)
    end
  end

  # ends at different depths ("paragraphs 11(2) to 13": SI 1996/396): the
  # whole provisions strictly between the ends' provisions, the end
  # provision given whole, and the parts of a provision given in part from
  # (or up to) the end's part
  defp mixed_between?(el, from, to) do
    {fp, tp, ep} = {top(from), top(to), top(el)}

    case {el == ep, from == fp} do
      {true, from_whole?} ->
        with {p, k} <- key(el), {^p, a} <- key(fp), {^p, b} <- key(tp) do
          (a < k or (from_whole? and a == k)) and (k < b or (to == tp and k == b))
        else
          _ -> false
        end

      {false, _} ->
        cond do
          ep == fp and from != fp -> part_from?(el, from)
          ep == tp and to != tp -> part_from?(to, el)
          true -> false
        end
    end
  end

  # `a` at or after `b`, both parts of one provision
  defp part_from?(a, b) do
    with {p, k} <- key(a), {^p, j} <- key(b), do: j <= k, else: (_ -> false)
  end

  defp top(ref), do: String.replace(ref, ~r/\(.*$/, "")

  defp same_depth_between?(el, from, to, ctx) do
    case ctx[:order] && ordered_between(ctx[:order], el, from, to) do
      nil -> numeric_between?(el, from, to)
      between? -> between?
    end
  end

  # by document order when the order holds all three (a law's order lists
  # whole provisions: a range of subsections, "s.10(2)..s.10(4)", goes by
  # number — CV-S04); else nil
  defp ordered_between(order, el, from, to) do
    pos = order |> Enum.with_index() |> Map.new()

    with a when is_integer(a) <- pos[from],
         b when is_integer(b) <- pos[to],
         i when is_integer(i) <- pos[el] do
      a <= i and i <= b
    else
      _ -> nil
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
end
