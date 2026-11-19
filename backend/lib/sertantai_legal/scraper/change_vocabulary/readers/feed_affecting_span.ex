defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffectingSpan do
  @moduledoc """
  The refs a number or a range of numbers names under a prefix, in a
  changes-feed effect's affecting provisions: "reg." with "11" to "14" →
  reg.11, reg.12, reg.13, reg.14 (`FeedAffecting`). Pure.
  """

  # the most a range is counted out to; a longer one gives its two ends
  @longest 100

  @doc ~S"""
  Every ref from `from` to `to` under `prefix`, by number or letter: "11" to
  "14" → 11, 12, 13, 14; "11(1)" to "(3)" → 11(1), 11(2), 11(3). With no end
  (""), the one ref. Ends that cannot be counted between (lettered numbers
  "2A" to "2D", roman numerals, ends at different depths, over 100 apart)
  give the two ends.
  """
  @spec refs(String.t(), String.t(), String.t()) :: [String.t()]
  def refs(prefix, from, ""), do: [prefix <> from]

  def refs(prefix, from, to) do
    {stem, first} = last_part(from)

    case between(first, to) do
      nil -> [prefix <> from | far_end(prefix, stem, first, to)]
      parts -> Enum.map(parts, &(prefix <> stem <> &1))
    end
  end

  # "11(1)" → {"11", "(1)"}; "11" → {"", "11"}
  defp last_part(from) do
    case Regex.run(~r/^(.*)(\([^)]+\))$/u, from) do
      [_, stem, last] -> {stem, last}
      nil -> {"", from}
    end
  end

  # the end's own ref, when it stands at the start's depth
  defp far_end(prefix, stem, first, to) do
    if String.starts_with?(first, "(") == String.starts_with?(to, "("),
      do: [prefix <> stem <> to],
      else: []
  end

  defp between("(" <> _ = from, "(" <> _ = to) do
    with [_, a] <- Regex.run(~r/^\(([^()]+)\)$/u, from),
         [_, b] <- Regex.run(~r/^\(([^()]+)\)$/u, to),
         [_ | _] = parts <- counted(a, b) do
      Enum.map(parts, &"(#{&1})")
    else
      _ -> nil
    end
  end

  defp between(from, to), do: numbers(from, to)

  defp counted(a, b), do: numbers(a, b) || letters(a, b)

  defp numbers(a, b) do
    with {x, ""} <- Integer.parse(a),
         {y, ""} <- Integer.parse(b),
         true <- x < y and y - x <= @longest do
      Enum.map(x..y, &Integer.to_string/1)
    else
      _ -> nil
    end
  end

  # "(c)" to "(e)"; never letters that may be roman numerals ("(i)" to "(v)")
  defp letters(<<a>>, <<b>>) when a in ?a..?z and b in ?a..?z and a < b do
    if roman?(a) and roman?(b), do: nil, else: Enum.map(a..b, &<<&1>>)
  end

  defp letters(_, _), do: nil

  defp roman?(char), do: char in ~c"ivxlc"
end
