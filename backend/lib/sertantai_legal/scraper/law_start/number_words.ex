defmodule SertantaiLegal.Scraper.LawStart.NumberWords do
  @moduledoc """
  Provision numbers an older Act writes in words, as digits: "Section
  forty-one of this Act" → "Section 41 of this Act" (Pipe-lines Act 1962
  s.70(3)); "sections one hundred and seventy-two and one hundred and
  ninety" → "sections 172 and 190" (Mines and Quarries Act 1954 s.194).
  Only after a provision noun; an "and" after "hundred" is the number's,
  any other parts two numbers. Pure.
  """

  @units ~w(one two three four five six seven eight nine ten eleven twelve thirteen
            fourteen fifteen sixteen seventeen eighteen nineteen)
  @tens ~w(twenty thirty forty fifty sixty seventy eighty ninety)
  @values @units
          |> Enum.with_index(1)
          |> Map.new()
          |> Map.merge(@tens |> Enum.with_index(2) |> Map.new(fn {w, i} -> {w, i * 10} end))
  @word "(?:#{Enum.join(@units ++ @tens ++ ["hundred"], "|")})"
  @run Regex.compile!(
         "\\b(sections?|regulations?|articles?|rules?)\\s+(#{@word}(?:(?:\\s*,\\s*|\\s+|-)(?:#{@word}|and|to)\\b)*)",
         "i"
       )

  @doc "`text` with the provision numbers it writes in words as digits."
  @spec digits(String.t()) :: String.t()
  def digits(text) do
    if text =~ @run,
      do: Regex.replace(@run, text, fn _, noun, run -> noun <> " " <> list(run) end),
      else: text
  end

  # the run's numbers, its separators kept ("and", "to", ",")
  defp list(run) do
    ~r/[a-z]+|,/i
    |> Regex.scan(run)
    |> List.flatten()
    |> Enum.map(&String.downcase/1)
    |> Enum.reduce({[], []}, &token/2)
    |> close()
    |> Enum.reverse()
    |> Enum.join(" ")
    |> String.replace(" ,", ",")
  end

  # {the text so far (reversed), the words of the number being read}
  defp token("and", {out, ["hundred" | _] = number}), do: {out, number}

  defp token(sep, {out, number}) when sep in ["and", "to", ","],
    do: {[sep | flush(out, number)], []}

  defp token(word, {out, number}), do: {out, [word | number]}

  defp close({out, number}), do: flush(out, number)

  defp flush(out, []), do: out
  defp flush(out, number), do: [number |> Enum.reverse() |> value() |> to_string() | out]

  defp value(words) do
    {total, n} =
      Enum.reduce(words, {0, 0}, fn
        "hundred", {total, n} -> {total + max(n, 1) * 100, 0}
        w, {total, n} -> {total, n + Map.fetch!(@values, w)}
      end)

    total + n
  end
end
