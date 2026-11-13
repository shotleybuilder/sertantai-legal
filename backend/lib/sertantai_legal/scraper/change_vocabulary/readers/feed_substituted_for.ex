defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedSubstitutedFor do
  @moduledoc """
  The provisions a changes-feed effect's Type says new text was
  substituted for ("substituted for Art. 15(1)", over "Art. 15(1)(1A)":
  REACH by SI 2019/556 reg. 25, "for paragraph 1 substitute— 1 … 1A …"),
  set against the provisions the effect lands on: one the Type names is
  substituted; one beside it, under a number the Type does not name, is
  new text — inserted (Fire and OH&S: Feed reader).

  The Type's provisions are read as their numbers in order ("Sch. 12
  para. 34(5)(6)" → 12, 34, 5, 6), a range as its two ends. A target is
  named when its numbers follow the Type's and its last is one the Type
  writes there or after, or lies within a range ("s. 2(3)-(5)" names
  (4), never (5A)). Whatever is not surely apart is taken as named: a
  target deeper than the Type goes, a number that cannot be set against a
  range's ends.

  Nothing is read from a Type naming no provisions ("substituted for
  words"), from an amendment to an earlier amending provision, nor where
  the Type names none of the provisions the effect lands on ("substituted
  for s. 39 40" over "s. 39A-39E": nothing says which was the old text).
  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb

  @for ~r/\bsubstituted\s+for\b\.?\s*(.+)$/i
  # what was replaced along with the provisions, naming none
  @also ~r/\s+and\s+(?:words?|cross-?\s?headings?)\s*$/i
  @token ~r/^\s*(?:(?:ss|s|regs|reg|arts|art|sch|paras|para|pt)\b\.?|(?<n>\d+[a-z]*)|\((?<p>[a-z0-9]+)\)|(?<dash>-)|,|and\b)/

  @typep named :: {:one, String.t()} | {:range, String.t(), String.t()}

  @doc """
  The `targets` (row refs) the Type does not name among the provisions
  substituted for: the new numbers, inserted. Empty unless the Type names
  at least one of the targets.
  """
  @spec inserted(String.t() | nil, [String.t()]) :: [String.t()]
  def inserted(type, targets) do
    with [_ | _] = old <- substituted_for(type),
         {[_ | _], [_ | _] = fresh} <- Enum.split_with(targets, &named?(numbers(&1), old)) do
      fresh
    else
      _ -> []
    end
  end

  # the provisions the Type names after "substituted for", in order; none
  # where it names anything else
  @spec substituted_for(String.t() | nil) :: [named()]
  defp substituted_for(nil), do: []

  defp substituted_for(type) do
    with false <- EffectVerb.earlier_amendment?(type),
         [_, text] <- Regex.run(@for, type),
         {:ok, tokens} <- tokens(text |> String.replace(@also, "") |> String.downcase(), []) do
      ranges(tokens)
    else
      _ -> []
    end
  end

  # the text as numbers and dashes, in order; :error for any other word
  defp tokens(text, acc) do
    case {String.trim(text), Regex.run(@token, text, capture: ["n", "p", "dash"])} do
      {"", _} -> {:ok, Enum.reverse(acc)}
      {_, nil} -> :error
      {_, found} -> tokens(rest(text), token(found) ++ acc)
    end
  end

  defp rest(text), do: Regex.replace(@token, text, "", global: false)

  defp token(["", "", ""]), do: []
  defp token(["", "", _dash]), do: [:to]
  defp token(["", p, _]), do: [p]
  defp token([n, _, _]), do: [n]

  # "3", :to, "5" → {:range, "3", "5"}
  defp ranges([a, :to, b | rest]) when is_binary(a) and is_binary(b),
    do: [{:range, a, b} | ranges(rest)]

  defp ranges([:to | rest]), do: ranges(rest)
  defp ranges([a | rest]), do: [{:one, a} | ranges(rest)]
  defp ranges([]), do: []

  # a row ref's numbers in order: "sch.12.para.34(5)" → 12, 34, 5
  defp numbers(ref) do
    ~r/\d+[a-z]*|\(([a-z0-9]+)\)/
    |> Regex.scan(String.downcase(ref))
    |> Enum.map(&List.last/1)
  end

  # the target's numbers follow the Type's, its last written there or after
  defp named?(numbers, old) when length(numbers) > length(old) or numbers == [], do: true

  defp named?(numbers, old) do
    {path, [last]} = Enum.split(numbers, -1)
    {lead, at} = Enum.split(old, length(path))

    not follows?(path, lead) or Enum.any?(at, &within?(last, &1))
  end

  defp follows?(path, lead), do: Enum.map(path, &{:one, &1}) == lead

  defp within?(number, {:one, one}), do: number == one

  defp within?(number, {:range, from, to}) do
    case Enum.map([from, number, to], &rank(&1, kind(from, to))) do
      [a, n, b] when nil not in [a, n, b] -> a <= n and n <= b
      _ -> true
    end
  end

  # how a range's ends count: numbers ("3", "5A"), roman numerals, letters
  defp kind(from, to) do
    cond do
      Enum.all?([from, to], &(&1 =~ ~r/^\d/)) -> :number
      Enum.all?([from, to], &(&1 =~ ~r/^[ivx]+$/)) -> :roman
      true -> :letter
    end
  end

  defp rank(number, :number) do
    case Integer.parse(number) do
      {n, suffix} -> {n, suffix}
      :error -> nil
    end
  end

  defp rank(number, :roman), do: if(number =~ ~r/^[ivx]+$/, do: roman(number))
  defp rank(number, :letter), do: if(number =~ ~r/^[a-z]+$/, do: number)

  @roman %{?i => 1, ?v => 5, ?x => 10}

  # "iv" → 4: a numeral before a greater one is taken from it
  defp roman(number) do
    values = number |> String.to_charlist() |> Enum.map(&Map.fetch!(@roman, &1))

    values
    |> Enum.zip(tl(values) ++ [0])
    |> Enum.reduce(0, fn {v, next}, sum -> if v < next, do: sum - v, else: sum + v end)
  end
end
