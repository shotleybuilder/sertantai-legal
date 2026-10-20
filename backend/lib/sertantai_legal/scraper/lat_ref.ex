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

    brackets ++ containers
  end

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
      [_] -> ref == el
    end
  end

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
end
