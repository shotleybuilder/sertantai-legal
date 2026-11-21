defmodule SertantaiLegal.Scraper.LawStart.ThatProvision do
  @moduledoc """
  A provision named by "of that section" in a commencement statement, as
  the section it means: in "subsection (1) of section 170, so far as …;
  subsection (2) of that section" (1988 c.33 s.171(6)) it is section
  170(2), and in "Paragraph (2) of regulation 3 and, …, paragraph (3) of
  that regulation" (SI 2017/1312 reg.1(3)) regulation 3(3). Pure.
  """

  @nouns "regulation|section|article|rule"
  @that Regex.compile!(
          "\\b(?:sub-?paragraphs?\\s+(\\(\\w{1,4}\\))\\s+of\\s+)?(?:paragraph|subsection)\\s+(\\(\\w{1,4}\\))\\s+of\\s+that\\s+(#{@nouns})\\b",
          "i"
        )
  # the section a provision was named in, outwards ("subsection (1) of
  # section 170"): the nearest such before; else the section last named
  # that is no other law's ("section 6(5) of the Magistrates' Courts Act")
  @outward Regex.compile!(
             "\\b(?:paragraph|subsection)\\s+\\(\\w{1,4}\\)\\s+of\\s+(?:#{@nouns})\\s+(\\d+[A-Z]*)\\b",
             "i"
           )
  @plain Regex.compile!(
           "\\b(?:#{@nouns})s?\\s+(\\d+[A-Z]*)\\b(?!(?:\\(\\w+\\))*\\s+(?:of|to)\\s+(?:the|that)\\b)",
           "i"
         )

  @doc """
  `statement` with each "subsection (X) of that section" written as
  "section N(X)", N the section last named before it; left as written where
  none is.
  """
  @spec name(String.t()) :: String.t()
  def name(statement) do
    case Regex.run(@that, statement, return: :index) do
      [{at, len} | _] -> statement |> named(at, len) |> continue(statement)
      nil -> statement
    end
  end

  # (an unresolved one is left, and ends the pass)
  defp continue(statement, statement), do: statement
  defp continue(named, _statement), do: name(named)

  defp named(statement, at, len) do
    before = binary_part(statement, 0, at)
    words = binary_part(statement, at, len)
    [_, sub, para, noun] = Regex.run(@that, words)

    case last(@outward, before) || last(@plain, before) do
      nil ->
        statement

      n ->
        before <>
          "#{noun} #{n}#{para}#{sub}" <>
          binary_part(statement, at + len, byte_size(statement) - at - len)
    end
  end

  defp last(regex, text) do
    case Regex.scan(regex, text, capture: :all_but_first) do
      [] -> nil
      found -> found |> List.last() |> hd()
    end
  end
end
