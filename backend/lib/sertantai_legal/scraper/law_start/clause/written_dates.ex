defmodule SertantaiLegal.Scraper.LawStart.Clause.WrittenDates do
  @moduledoc """
  A date written out at the start of a clause's tail, in figures ("17th April 1995") or in words ("the first day of April in the year one thousand nine hundred and ninety-five"). Pure.
  """

  @months ~w(january february march april may june july august september october november december)

  @numbers %{
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "four" => 4,
    "five" => 5,
    "six" => 6,
    "seven" => 7,
    "eight" => 8,
    "nine" => 9,
    "ten" => 10,
    "eleven" => 11,
    "twelve" => 12,
    "thirteen" => 13,
    "fourteen" => 14,
    "fifteen" => 15,
    "sixteen" => 16,
    "seventeen" => 17,
    "eighteen" => 18,
    "nineteen" => 19,
    "twenty" => 20,
    "thirty" => 30,
    "first" => 1,
    "second" => 2,
    "third" => 3,
    "fourth" => 4,
    "fifth" => 5,
    "sixth" => 6,
    "seventh" => 7,
    "eighth" => 8,
    "ninth" => 9,
    "tenth" => 10,
    "eleventh" => 11,
    "twelfth" => 12,
    "thirteenth" => 13,
    "fourteenth" => 14,
    "fifteenth" => 15,
    "sixteenth" => 16,
    "seventeenth" => 17,
    "eighteenth" => 18,
    "nineteenth" => 19,
    "twentieth" => 20,
    "thirtieth" => 30,
    "forty" => 40,
    "fortieth" => 40,
    "fifty" => 50,
    "fiftieth" => 50,
    "sixty" => 60,
    "sixtieth" => 60,
    "seventy" => 70,
    "eighty" => 80,
    "ninety" => 90
  }

  @doc "Numbers written in words, by word."
  @spec numbers() :: %{String.t() => non_neg_integer()}
  def numbers, do: @numbers

  @doc """
  A date at the start of text: "17th April 1995", "30 th August 2013",
  "1 October 2020"; in words, as older Acts write it: "the first day of
  April, nineteen hundred and sixty-two" (Factories Act 1961 s.185(2)).
  """
  @spec date_at_start(String.t()) :: Date.t() | nil
  def date_at_start(text) do
    # (the year run on to the month, "6th July2017": SI 2017/720 art.1(2);
    # a date the revised text brackets, "on [1st December 1999]": SI
    # 1999/2463 reg.1)
    re =
      ~r/^(?:the\s+)?\[?\s*(\d{1,2})\s*(?:st|nd|rd|th)?\s*(?:day\s+of\s+)?([A-Za-z]+),?\s*(\d{4})\b/

    with [_, d, m, y] <- Regex.run(re, String.trim(text)),
         month when is_integer(month) <- Enum.find_index(@months, &(&1 == String.downcase(m))),
         {:ok, date} <- Date.new(String.to_integer(y), month + 1, String.to_integer(d)) do
      date
    else
      _ -> date_in_words(String.trim(text))
    end
  end

  @in_words ~r/^(?:the\s+)?([a-z]+(?:[- ][a-z]+)?)\s+day\s+of\s+([A-Za-z]+),?\s+(?:in\s+the\s+year\s+)?([a-z][a-z -]*)/i

  defp date_in_words(text) do
    with [_, d, m, y] <- Regex.run(@in_words, text),
         month when is_integer(month) <- Enum.find_index(@months, &(&1 == String.downcase(m))),
         day when is_integer(day) <- words_number(d),
         year when is_integer(year) and year > 1000 <- year_in_words(y),
         {:ok, date} <- Date.new(year, month + 1, day) do
      date
    else
      _ -> nil
    end
  end

  # "first", "twenty-first", "thirty first"
  defp words_number(words) do
    parts = words |> String.downcase() |> String.split(~r/[- ]/, trim: true)
    values = Enum.map(parts, &Map.get(@numbers, &1))
    if parts != [] and Enum.all?(values, & &1), do: Enum.sum(values)
  end

  # "nineteen hundred and sixty-two", "two thousand and one": the leading
  # number words, then the rest of the sentence ignored
  defp year_in_words(words) do
    words
    |> String.downcase()
    |> String.split(~r/[- ]+/, trim: true)
    |> Enum.take_while(&(Map.has_key?(@numbers, &1) or &1 in ~w(hundred thousand and)))
    |> Enum.reject(&(&1 == "and"))
    |> Enum.reduce({0, 0}, fn
      "thousand", {total, n} -> {total + n * 1000, 0}
      "hundred", {total, n} -> {total + n * 100, 0}
      w, {total, n} -> {total, n + Map.fetch!(@numbers, w)}
    end)
    |> then(fn {total, n} -> total + n end)
  end
end
