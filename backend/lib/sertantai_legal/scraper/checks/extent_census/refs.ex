defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Refs do
  @moduledoc """
  A mention's numbers resolved to the law's own provision refs
  ("sections 3 to 5" → s.3, s.4, s.5; "paragraph 2(1) of Schedule 4" →
  sch.4.para.2(1); "Part 2" → the sections it holds), with the law's
  structure (`finder.py`'s `resolve`, `items_of`, `sub_range`,
  `expand_alpha`; #192). Shares no code with the extent reader.
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.Structure

  @num "(?:\\d+[A-Z]*(?:\\d+[A-Z]*)?|[IVXL]+\\b)"
  @sub "\\((?:[a-z]{1,4}|\\d+[A-Z]*)\\)"
  @item "(?:#{@num}(?:\\s?#{@sub})*|#{@sub}(?:#{@sub})*)"

  @token Regex.compile!("#{@item}|\\bto\\b|-", "u")
  @item_parts Regex.compile!("^(#{@num})?((?:\\s?#{@sub})*)$", "u")
  @subs ~r/\((\w+)\)/u
  @of_sch ~r/^\s*of\s+(?:Schedule\s+(\w+)|this\s+Schedule|the\s+Schedule)\b(?!\s+to\s+the\b)/u
  @of_part ~r/^\s*of\s+(?:Part\s+(\w+)|this\s+Part)\b/u
  @locator ~r/\bin\s+(section|regulation|article|rule)\s+(\d+[A-Z]*)\s*(?:,\s*$|(?:\([^()]*\)\s*)?[—–][^;]*?$)/iu
  @roman %{?I => 1, ?V => 5, ?X => 10, ?L => 50, ?C => 100}

  @type item :: {String.t(), [String.t()]} | {:range, item(), item()}

  @doc "The pattern of one numbered item (`ITEM`), for the mention patterns."
  @spec item_pattern() :: String.t()
  def item_pattern, do: @item

  @doc "`OF_SCH`: \" of Schedule 4\" after a mention."
  @spec of_sch() :: Regex.t()
  def of_sch, do: @of_sch

  @doc "`OF_PART`: \" of Part 2\" after a mention."
  @spec of_part() :: Regex.t()
  def of_part, do: @of_part

  @doc """
  A number list's items: "1, 2(1), (4) and (5)" → {"1", []}, {"2", ["1"]}, {"2", ["4"]}, {"2", ["5"]}; "3 to 5" a range.
  """
  @spec items_of(String.t()) :: [item()]
  def items_of(numbers) do
    @token
    |> Regex.scan(numbers)
    |> Enum.map(&hd/1)
    |> Enum.reduce({[], nil, false}, &item_token/2)
    |> elem(0)
    |> Enum.reverse()
  end

  defp item_token(t, {out, last, _pending}) when t in ["to", "-"], do: {out, last, true}

  defp item_token(t, {out, last, pending}) do
    case Regex.run(@item_parts, t) do
      nil -> {out, last, pending}
      caps -> placed(continue(caps, last), out, pending)
    end
  end

  defp placed(cur, [prev | rest], true), do: {[{:range, prev, cur} | rest], cur, false}
  defp placed(cur, out, pending), do: {[cur | out], cur, pending}

  defp continue(caps, last) do
    num = Enum.at(caps, 1, "")
    subs = for [_, s] <- Regex.scan(@subs, Enum.at(caps, 2, "")), do: s
    continue(num, subs, last)
  end

  defp continue("", subs, nil), do: {"", subs}

  # a continuation: (4) after 2(1) is 2(4); (b) after 18(8)(b) is 18(8)(b)
  defp continue("", [first | _] = subs, {num, last_subs}) do
    lv = levels(last_subs)

    new =
      cond do
        digit_start?(first) -> "n"
        Regex.match?(~r/\A[ivx]+\z/u, first) and "r" in lv -> "r"
        true -> "a"
      end

    idx = Enum.find_index(lv, &(&1 == new)) || length(lv)
    {num, Enum.take(last_subs, idx) ++ subs}
  end

  defp continue(num, subs, _last), do: {num, subs}

  @doc "Each sub's level: n (number), a (letter), r (roman after a letter)."
  @spec levels([String.t()]) :: [String.t()]
  def levels(subs) do
    subs
    |> Enum.reduce([], fn x, out ->
      cond do
        digit_start?(x) -> ["n" | out]
        Regex.match?(~r/\A[ivx]+\z/u, x) and "a" in out -> ["r" | out]
        true -> ["a" | out]
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  A ref with subs: fmt("s.3", ["1", "a"]) → "s.3(1)(a)".
  """
  @spec fmt(String.t(), [String.t()]) :: String.t()
  def fmt(base, subs), do: base <> Enum.map_join(subs, &"(#{&1})")

  @doc """
  The refs between two subs: "(4) to (6)", "(4) to (8A)", "(b) to (d)", "8(2)(b) to (d)".
  """
  @spec sub_range(String.t(), [String.t()], [String.t()]) :: MapSet.t(String.t())
  def sub_range(_base, [], _sb), do: MapSet.new()
  def sub_range(_base, _sa, []), do: MapSet.new()

  def sub_range(base, sa, sb) do
    pre = if length(sb) == 1, do: Enum.drop(sa, -1), else: Enum.drop(sb, -1)
    a = List.last(sa)
    b = List.last(sb)

    sub_span(
      base,
      pre,
      {a, Regex.run(~r/\A(\d+)([A-Z]*)\z/u, a)},
      {b, Regex.run(~r/\A(\d+)([A-Z]*)\z/u, b)}
    )
  end

  defp sub_span(base, pre, {_a, [_, na, ""]}, {b, [_, nb, _]}) do
    String.to_integer(na)..String.to_integer(nb)//1
    |> MapSet.new(&fmt(base, pre ++ [Integer.to_string(&1)]))
    |> MapSet.put(fmt(base, pre ++ [b]))
  end

  defp sub_span(base, pre, {a, [_ | _]}, {b, [_ | _]}),
    do: MapSet.new([fmt(base, pre ++ [a]), fmt(base, pre ++ [b])])

  defp sub_span(base, pre, {a, nil}, {b, nil}) do
    if Regex.match?(~r/\A[a-z]\z/u, a) and Regex.match?(~r/\A[a-z]\z/u, b) and a <= b do
      <<ca>> = a
      <<cb>> = b
      MapSet.new(ca..cb, &fmt(base, pre ++ [<<&1>>]))
    else
      MapSet.new()
    end
  end

  defp sub_span(_base, _pre, _a, _b), do: MapSet.new()

  @doc """
  The names from a to b: "1".."3", "II".."IV" in Roman numerals; else just the two.
  """
  @spec expand_alpha(String.t(), String.t() | nil) :: [String.t()]
  def expand_alpha(a, nil), do: [a]

  def expand_alpha(a, b) do
    cond do
      digits?(a) and digits?(b) ->
        Enum.map(String.to_integer(a)..String.to_integer(b)//1, &Integer.to_string/1)

      Regex.match?(~r/\A[IVXL]+\z/u, a) and Regex.match?(~r/\A[IVXL]+\z/u, b) ->
        Enum.map(roman(a)..roman(b)//1, &to_roman/1)

      true ->
        [a, b]
    end
  end

  @doc "A Roman numeral's value."
  @spec roman(String.t()) :: integer()
  def roman(s) do
    cs = String.to_charlist(s)

    cs
    |> Enum.zip(tl(cs) ++ [nil])
    |> Enum.reduce(0, fn {c, next}, v ->
      x = @roman[c]
      if next && @roman[next] > x, do: v - x, else: v + x
    end)
  end

  @doc "A number in Roman numerals (to L)."
  @spec to_roman(integer()) :: String.t()
  def to_roman(n) do
    [{50, "L"}, {40, "XL"}, {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"}]
    |> Enum.reduce({n, ""}, fn {v, r}, {n, out} ->
      {rem(n, v), out <> String.duplicate(r, div(n, v))}
    end)
    |> elem(1)
  end

  @doc """
  The section a locator names before a mention: "in regulation 16, paragraphs (4)" → "reg.16".
  """
  @spec locator_base(String.t()) :: String.t() | nil
  def locator_base(lead) do
    case Regex.run(@locator, lead) do
      [_, kind, n] -> if(String.downcase(kind) == "section", do: "s.", else: "reg.") <> n
      nil -> nil
    end
  end

  @doc """
  The refs a mention names. `kw` is its keyword ("section", "paragraph",
  "part" …), `numbers` its number list, `tail` the text after it and
  `lead` the text before it; `ctx` holds the sentence's own provision
  (`top`, `sch_of_own`), the Schedule a locator named (`sch_lead`) and
  the law's structure (`st`).
  """
  @spec resolve(String.t(), String.t(), String.t(), String.t(), map()) :: MapSet.t(String.t())
  def resolve(kw, numbers, tail, lead, ctx) do
    ctx =
      Map.merge(ctx, %{
        pre: if(String.starts_with?(ctx.top, "s."), do: "s.", else: "reg."),
        in_sch: String.starts_with?(ctx.top, "sch."),
        of_sch: Regex.run(@of_sch, tail),
        of_part: Regex.run(@of_part, tail),
        lead: lead
      })

    numbers
    |> items_of()
    |> Enum.reduce(MapSet.new(), fn it, refs ->
      MapSet.union(refs, item_refs(kw, ends(it), ctx))
    end)
  end

  defp ends({:range, a, b}), do: {true, a, b}
  defp ends(it), do: {false, it, it}

  defp item_refs(kw, ends, ctx) when kw in ["section", "regulation", "article", "rule"],
    do: section_refs(ends, ctx)

  defp item_refs("subsection", ends, ctx), do: own_sub_refs(ends, ctx)

  defp item_refs(
         "paragraph",
         {_, {"", [first | _]}, _} = ends,
         %{in_sch: false, pre: "reg."} = ctx
       ) do
    if digits?(first), do: own_sub_refs(ends, ctx), else: paragraph_refs(ends, ctx)
  end

  defp item_refs("paragraph", ends, ctx), do: paragraph_refs(ends, ctx)

  defp item_refs("subparagraph", {_, {num, subs}, _}, %{in_sch: true} = ctx),
    do: MapSet.new([fmt(ctx.top, if(num == "", do: subs, else: [num | subs]))])

  defp item_refs("schedule", {rng, {a, _}, {b, _}}, _ctx),
    do: MapSet.new(expand_alpha(a, if(rng, do: b)), &"sch.#{&1}")

  defp item_refs("part", ends, ctx), do: part_refs(ends, ctx)
  defp item_refs("chapter", ends, ctx), do: chapter_refs(ends, ctx)
  defp item_refs(_kw, _ends, _ctx), do: MapSet.new()

  defp section_refs({true, {a, []}, {b, []}}, ctx) do
    case Structure.between(ctx.st, ctx.pre <> a, ctx.pre <> b) do
      nil -> MapSet.new(["#{ctx.pre}#{a}..#{ctx.pre}#{b}"])
      span -> MapSet.new(span)
    end
  end

  defp section_refs({true, {a, sa}, {b, sb}}, ctx) do
    MapSet.new([fmt(ctx.pre <> a, sa), fmt(ctx.pre <> b, sb)])
    |> MapSet.union(sub_range(ctx.pre <> a, sa, sb))
  end

  defp section_refs({false, {a, sa}, _}, ctx), do: MapSet.new([fmt(ctx.pre <> a, sa)])

  # own provision's: "subsection (4)", "paragraph (2)" in an SI
  defp own_sub_refs({rng, {a, sa} = first, last}, ctx) do
    base = locator_base(ctx.lead) || ctx.top
    xs = if rng, do: [first, last], else: [first]
    refs = MapSet.new(xs, fn {_, s} -> fmt(base, if(a == "", do: s, else: [a | s])) end)
    if rng, do: MapSet.union(refs, sub_range(base, sa, elem(last, 1))), else: refs
  end

  defp paragraph_refs({rng, {a, sa}, {b, sb}}, ctx) do
    sch = paragraph_schedule(ctx)

    cond do
      not digit_start?(a) -> MapSet.new()
      sch == nil -> MapSet.new()
      rng and sa == [] and sb == [] -> paragraph_span(sch, a, b, ctx)
      rng -> paragraph_range(sch, {a, sa}, {b, sb})
      true -> MapSet.new([fmt("#{sch}.para.#{a}", sa)])
    end
  end

  defp paragraph_span(sch, a, b, ctx) do
    case Structure.between(ctx.st, "#{sch}.para.#{a}", "#{sch}.para.#{b}") do
      nil -> MapSet.new(["#{sch}.para.#{a}..#{sch}.para.#{b}"])
      span -> MapSet.new(span)
    end
  end

  defp paragraph_range(sch, {a, sa}, {b, sb}) do
    refs =
      MapSet.new([
        fmt("#{sch}.para.#{a}", sa),
        fmt("#{sch}.para.#{if b == "", do: a, else: b}", sb)
      ])

    if b == "" or b == a,
      do: MapSet.union(refs, sub_range("#{sch}.para.#{a}", sa, sb)),
      else: refs
  end

  defp paragraph_schedule(%{of_sch: of_sch, sch_of_own: own, sch_lead: lead}) do
    named =
      case of_sch do
        [_, n | _] when n != "" -> "sch.#{n}"
        [_ | _] -> own
        nil -> nil
      end

    named || lead || if(own && of_sch == nil, do: own)
  end

  defp part_refs({rng, {a, _}, {b, _}}, ctx) do
    sch =
      case ctx.of_sch do
        [_, n | _] when n != "" -> "sch.#{n}"
        _ -> nil
      end || ctx.sch_lead || if(ctx.in_sch, do: ctx.sch_of_own)

    expand_alpha(a, if(rng, do: b))
    |> Enum.reduce(MapSet.new(), fn x, refs -> MapSet.union(refs, part_held(sch, x, ctx.st)) end)
  end

  # (and the paragraphs it holds in the document, run-05)
  defp part_held(nil, x, st) do
    case Structure.held(st, "part-#{x}") do
      [] -> MapSet.new(["part-#{x}"])
      held -> MapSet.new(held)
    end
  end

  defp part_held(sch, x, st) do
    cid =
      "schedule" <>
        String.replace(binary_part(sch, 3, byte_size(sch) - 3), ".", "-") <> "-part-#{x}"

    st |> Structure.held(cid) |> MapSet.new() |> MapSet.put("#{sch}.pt.#{x}")
  end

  defp chapter_refs({rng, {a, _}, {b, _}}, ctx) do
    # (Python names a Part it cannot tell "None")
    part = chapter_part(ctx) || "None"

    expand_alpha(a, if(rng, do: b))
    |> Enum.reduce(MapSet.new(), fn x, refs ->
      cid = "part-#{part}-chapter-#{x}"

      case Structure.held(ctx.st, cid) do
        [] -> MapSet.put(refs, cid)
        held -> MapSet.union(refs, MapSet.new(held))
      end
    end)
  end

  defp chapter_part(ctx) do
    part =
      case ctx.of_part do
        [_, n | _] when n != "" -> n
        [_ | _] -> part_number(Structure.container_of(ctx.st, ctx.top, "part"))
        nil -> nil
      end

    part || part_number(Structure.container_of(ctx.st, ctx.top, "chapter"))
  end

  defp part_number(nil), do: nil
  defp part_number(cid), do: cid |> String.split("-") |> Enum.at(1)

  defp digit_start?(s), do: Regex.match?(~r/\A\d/u, s)
  defp digits?(s), do: Regex.match?(~r/\A\d+\z/u, s)
end
