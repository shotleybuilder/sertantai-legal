defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedSubstitutedFor do
  @moduledoc """
  The provisions a changes-feed effect's Type says new text was
  substituted for ("substituted for Art. 15(1)", over "Art. 15(1)(1A)":
  REACH by SI 2019/556 reg. 25, "for paragraph 1 substitute— 1 … 1A …"),
  set against the provisions the effect lands on: one the Type names is
  substituted; one under a number the Type does not name is new text —
  inserted (Fire and OH&S, and Waste, Water and Climate: Feed reader).

  The Type's provisions are read as their numbers in order ("Sch. 12
  para. 34(5)(6)" → 12, 34, 5, 6), a range as its two ends. A target is
  named when its numbers follow the Type's and its last is one the Type
  writes there or after, or lies within a range ("s. 2(3)-(5)" names
  (4), never (5A)). A range of letters counts as the law numbers a long
  list: a to z, then aa to zz, then aaa ("(a)-(aaa)" names (qq)).
  Whatever is not surely apart is taken as named: a target deeper than
  the Type goes, a number that cannot be set against a range's ends.

  A Type restating only the tail ("(3)(4) substituted for (3)" over "reg.
  5(3)(4)"; "substituted for para. 6A(2)(b)" under a Schedule) names the
  target's own last parts. A Type naming none of the targets ("substituted
  for s. 39 40" over "s. 39A-39E") makes each of them new.

  New text in place of what is no provision ("substituted for words",
  "… for full stop", "… for words in s. 26(1)": S.R. 2010/59 reg. 3(k)(l)
  by S.R. 2012/177 reg. 4(5), "for "." substitute— (k) … (l) …") makes
  every provision the effect names new, where the feed lands on the
  provisions its text ends with.

  Nothing is read from an amendment to an earlier amending provision, nor
  from a Type naming anything else. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb

  @for ~r/\bsubstituted\s+for\b\.?\s*(.+)$/i
  # what was replaced or put in along with the provisions, naming none
  @also ~r/\s+and\s+(?:words?|semi-?\s?colon|cross-?\s?headings?)\s*$/i
  # what is no provision, and the provision it was in
  @words ~r/^(?:words?|word\(s\)|full stop)(?:\s+in\s+(.+))?$/i
  # the tail of the target's own number, restated alone
  @tail ~r/^\s*(?:\(|paras?\b)/i
  # (a Part under a letter or roman numeral, "Pt. C", is in no row ref's
  # numbers)
  @token ~r/^\s*(?:pt\.?\s+[a-z]+\b(?!\))|(?:ss|s|regs|reg|arts|art|sch|paras|para|pt)\b\.?|(?<n>\d+[a-z]*)|\((?<p>[a-z0-9]+)\)|(?<dash>-)|,|and\b)/

  @typep named :: {:one, String.t()} | {:range, String.t(), String.t()}
  @typep old ::
           {:provisions, [named()], tail? :: boolean()} | {:words, [named()] | nil} | nil

  @doc """
  The `targets` (row refs) that are new text, inserted: those the Type
  does not name among the provisions substituted for, and every one put in
  place of words — where `text`, the effect's affected provisions, ends
  with the provisions it lands on.
  """
  @spec inserted(String.t() | nil, [String.t()], String.t() | nil) :: [String.t()]
  def inserted(type, targets, text \\ nil) do
    case old(type) do
      {:provisions, old, tail?} -> Enum.reject(targets, &named?(numbers(&1), old, tail?))
      {:words, within} -> Enum.filter(targets, &(lands?(text, &1) and not same?(&1, within)))
      nil -> []
    end
  end

  @doc """
  The provisions the Type says were substituted for, as it writes them
  ("substituted for s. 21(8)(a)-(c)" → "s. 21(8)(a)-(c)"); nil where it
  names none, words, or an earlier amending provision's.
  """
  @spec replaced(String.t() | nil) :: String.t() | nil
  def replaced(type) do
    case old(type) do
      {:provisions, _named, false} -> after_for(type)
      _ -> nil
    end
  end

  @doc """
  Whether `text` (provisions as the feed writes them: "s. 21(8)(a) (b)")
  names the provision `ref`, or may: only a provision surely apart from
  those written is not named.
  """
  @spec names?(String.t() | nil, String.t()) :: boolean()
  def names?(text, ref) do
    case read(text) do
      [_ | _] = named -> named?(numbers(ref), named, false)
      [] -> true
    end
  end

  # what the Type says the new text took the place of: provisions, in
  # order (whether as a tail alone), or words (in a provision, when said)
  @spec old(String.t() | nil) :: old()
  defp old(type) do
    with text when is_binary(text) <- after_for(type),
         nil <- words(text),
         [_ | _] = named <- read(text) do
      {:provisions, named, String.match?(text, @tail)}
    else
      {:words, _} = words -> words
      _ -> nil
    end
  end

  defp after_for(nil), do: nil

  defp after_for(type) do
    with false <- EffectVerb.earlier_amendment?(type),
         [_, text] <- Regex.run(@for, type) do
      String.replace(text, @also, "")
    else
      _ -> nil
    end
  end

  defp words(text) do
    case Regex.run(@words, String.trim(text)) do
      [_] -> {:words, nil}
      [_, within] -> {:words, read(within)}
      nil -> nil
    end
  end

  # provisions as written, as the numbers and ranges named, in order; none
  # where the text names anything else
  @spec read(String.t() | nil) :: [named()]
  defp read(nil), do: []

  defp read(text) do
    case tokens(text |> String.replace(@also, "") |> String.downcase(), []) do
      {:ok, tokens} -> ranges(tokens)
      :error -> []
    end
  end

  # the feed lands on the provisions its text ends with: `ref`'s last
  # number is written at its own depth or after, or the text has a range
  # (never "Sch. 1 Table 1 semicolon", placed on the Schedule)
  defp lands?(text, ref) do
    named = read(text)
    numbers = numbers(ref)

    numbers != [] and
      (Enum.any?(named, &match?({:range, _, _}, &1)) or
         {:one, List.last(numbers)} in Enum.drop(named, length(numbers) - 1))
  end

  # the provision the words were in is no new one
  defp same?(_ref, nil), do: false
  defp same?(ref, within), do: Enum.map(numbers(ref), &{:one, &1}) == within

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
  defp named?(numbers, old, true), do: named?(numbers, whole(numbers, old), false)
  defp named?(numbers, old, false) when length(numbers) > length(old) or numbers == [], do: true

  defp named?(numbers, old, false) do
    {path, [last]} = Enum.split(numbers, -1)
    {lead, at} = Enum.split(old, length(path))

    not follows?(path, lead) or Enum.any?(at, &within?(last, &1))
  end

  # a tail with the target's own numbers before it: from where the target
  # writes the tail's first number (the last such place the tail reaches
  # the target's end from), else in place of the target's last number
  defp whole(numbers, [first | _] = tail) do
    depth = length(numbers)

    at =
      Enum.find((depth - 1)..0//-1, depth - 1, fn i ->
        depth - i <= length(tail) and {:one, Enum.at(numbers, i)} == first
      end)

    Enum.map(Enum.take(numbers, max(at, 0)), &{:one, &1}) ++ tail
  end

  defp follows?(path, lead), do: Enum.map(path, &{:one, &1}) == lead

  defp within?(number, {:one, one}), do: number == one

  defp within?(number, {:range, from, to}) do
    case Enum.map([from, number, to], &rank(&1, kind(from, to))) do
      [a, n, b] when nil not in [a, n, b] -> a <= n and n <= b
      _ -> true
    end
  end

  # how a range's ends count: numbers ("3", "5A"), roman numerals, a long
  # list's letters ("a" to "aaa": both ends one letter, repeated), letters
  defp kind(from, to) do
    cond do
      Enum.all?([from, to], &(&1 =~ ~r/^\d/)) -> :number
      Enum.all?([from, to], &(&1 =~ ~r/^[ivx]+$/)) -> :roman
      Enum.all?([from, to], &repeated?/1) and String.length(from <> to) > 2 -> :long
      true -> :letter
    end
  end

  defp repeated?(number), do: number =~ ~r/^([a-z])\1*$/

  defp rank(number, :number) do
    case Integer.parse(number) do
      {n, suffix} -> {n, suffix}
      :error -> nil
    end
  end

  defp rank(number, :roman), do: if(number =~ ~r/^[ivx]+$/, do: roman(number))
  # a to z, then aa to zz, then aaa: by length, then letter
  defp rank(number, :long), do: if(repeated?(number), do: {String.length(number), number})
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
