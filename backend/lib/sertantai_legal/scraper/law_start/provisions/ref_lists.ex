defmodule SertantaiLegal.Scraper.LawStart.Provisions.RefLists do
  @moduledoc """
  Lists and ranges of numbers a sentence names ("regulations 17 to 21", "Articles 45(4)(d) and (5)(a) and 48", "Parts II to IV"), as refs. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.Provisions.Words

  # "45(4)(d) and (5)(a) and 48", "17 to 21", "3, 4, 17, 21 and 23"
  @doc "A list's numbers as refs under `prefix` (\"45(4)(d) and (5)(a) and 48\", \"17 to 21\")."
  @spec list_refs(String.t(), String.t(), [map()]) :: [String.t()]
  def list_refs(list, prefix, rows) do
    at = number_prefix(prefix, rows)

    tokens =
      Regex.scan(~r/(to|–|-(?=\s*\d))|(\d+[A-Z]*)((?:\([^)]+\))*)|((?:\([^)]+\))+)/, list)

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, brackets], {acc, _last, range?} ->
          ref = "#{at}#{n}#{brackets}"

          acc =
            if range? and acc != [],
              do: acc ++ range_refs(List.last(acc), ref, rows),
              else: acc ++ [ref]

          {acc, n, false}

        # "5(1) to (4)": a bracket range within the number (Petroleum Act
        # 1998 s.52(1), CV-S04)
        [_, "", "", "", brackets], {acc, last, true} when is_binary(last) and acc != [] ->
          {acc ++ bracket_range(List.last(acc), "#{at}#{last}#{brackets}"), last, false}

        [_, "", "", "", brackets], {acc, last, range?} when is_binary(last) ->
          {acc ++ [sibling(List.last(acc), "#{at}#{last}", brackets)], last, range?}

        _, state ->
          state
      end)

    refs
  end

  # a bracket alone after a reference is its sibling at the same kind of
  # level, the deepest of the reference's: "12(2)(a) and (b)" is 12(2)(b)
  # (SI 2021/1095 reg.1(2)), "45(4)(d) and (5)(a)" 45(5)(a), "11(1)(a) and
  # (5)" 11(5) (NISR 2008/231 reg.1(4))
  defp sibling(previous, number, brackets) when is_binary(previous) do
    levels = Regex.scan(~r/\(([^)]+)\)/, String.replace_prefix(previous, number, ""))
    [_, first] = Regex.run(~r/^\(([^)]+)\)/, brackets)

    case levels
         |> Enum.map(&List.last/1)
         |> Enum.with_index()
         |> Enum.filter(&same_kind?(elem(&1, 0), first)) do
      [] ->
        number <> brackets

      kept ->
        {_, i} = List.last(kept)
        number <> Enum.map_join(Enum.take(levels, i), &"(#{List.last(&1)})") <> brackets
    end
  end

  defp sibling(_previous, number, brackets), do: number <> brackets

  defp same_kind?(a, b), do: digits?(a) == digits?(b)

  defp digits?(level), do: level =~ ~r/^\d/

  # "s.5(1)" to "s.5(4)": the members after the first, one bracket deep,
  # numbers or letters (the held rows decide which exist)
  defp bracket_range(first, last) do
    with [_, base, a] <- Regex.run(~r/^(.*)\(([0-9]+|[a-z])\)$/, first),
         [_, ^base, b] <- Regex.run(~r/^(.*)\(([0-9]+|[a-z])\)$/, last),
         {from, to} when from < to <- {ordinal(a), ordinal(b)} do
      for i <- (from + 1)..to, do: "#{base}(#{member(i, a)})"
    else
      _ -> [last]
    end
  end

  defp ordinal(<<c>>) when c in ?a..?z, do: c

  defp ordinal(n), do: String.to_integer(n)

  defp member(i, <<c>>) when c in ?a..?z, do: <<i>>

  defp member(i, _), do: Integer.to_string(i)

  # the provisions from `first` to `last` in document order
  defp range_refs(first, last, rows) do
    bases = rows |> Enum.map(&Words.provision(&1.section_id)) |> Enum.uniq()
    from = Enum.find_index(bases, &(&1 == Words.provision(first)))
    to = Enum.find_index(bases, &(&1 == Words.provision(last)))

    if from && to && to >= from, do: Enum.slice(bases, (from + 1)..to//1), else: [last]
  end

  @roman ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX)

  # "1, 3 and 5", "1 to 3", "II to IV": each Part (CV-S04: DRA 2014 s.50(1))
  @doc "A list of Parts, ranges expanded (\"1 to 3\", \"II to IV\")."
  @spec part_list(String.t()) :: [String.t()]
  def part_list(list) do
    list
    |> String.split(~r/\s*(?:,|and)\s*/, trim: true)
    |> Enum.flat_map(fn item ->
      with [a, b] <- String.split(item, ~r/\s+to\s+/),
           {i, j} when is_integer(i) and is_integer(j) and i <= j <- {number(a), number(b)} do
        Enum.map(i..j, &Integer.to_string/1)
      else
        _ -> [item]
      end
    end)
  end

  defp number(p) do
    case Integer.parse(p) do
      {i, ""} -> i
      _ -> Enum.find_index(@roman, &(&1 == String.upcase(p))) |> then(&(&1 && &1 + 1))
    end
  end

  @doc "Whether two Part numbers are the same, by figure or numeral."
  @spec same_part?(String.t() | nil, String.t()) :: boolean()
  def same_part?(nil, _p), do: false

  def same_part?(part, p) do
    up = String.upcase(p)
    part = String.upcase(part)
    part == up or part == roman(up) or roman(part) == up
  end

  defp roman(s) do
    case Integer.parse(s) do
      {i, ""} when i in 1..20 -> Enum.at(@roman, i - 1)
      _ -> s
    end
  end

  @doc "Words with their spaces squashed."
  @spec squash(String.t() | nil) :: String.t() | nil
  def squash(nil), do: nil

  def squash(s), do: s |> String.replace(~r/\s+/, " ") |> String.trim()

  # "UK_x:reg.1(2)" → "UK_x:reg.1"
  # how the law's rows number a provision: "art.Article 5" for EU law's
  # articles, else "art.5" ("Articles 1 and 2 shall apply from …": EUR
  # 2016/879 art.5)
  defp number_prefix(prefix, rows) do
    if Enum.any?(rows, &String.starts_with?(&1.section_id, prefix <> ".Article ")),
      do: prefix <> ".Article ",
      else: prefix <> "."
  end
end
