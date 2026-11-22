defmodule SertantaiLegal.Scraper.Commencement.Order.RelatedList do
  @moduledoc """
  An order item's open "so far as it relates to—" list of sections: "(i)
  paragraph 3(8)(b) so far as it relates to— (aa) sections 39ZA, … of the
  1991 Act; and (bb) sections 42 to 47, 49 and 51 to 53 of the 2014 Act"
  (SI 2015/1469 art.2(f)). The sections are what the item relates to, never
  brought in, so their lines are dropped and the item reads as partial. A
  Schedule's paragraphs under such a list are left as they are: a section
  so far as it relates to its Schedule's paragraphs brings them in (SI
  1975/1938: "Section 125(1), as far as it relates to:— (a) in Part III of
  Schedule 16, paragraphs 1, 2 …"). Pure text.
  """

  @open ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it\s+relates|they\s+relate)\s+to\s*[—–:]*\s*$/iu
  @sections ~r/^\W*sections?\s+\d/iu

  @doc "The lines, without the sections lines an open relating list names."
  @spec drop_sections([String.t()]) :: [String.t()]
  def drop_sections(lines) do
    lines
    |> Enum.reduce({[], false}, fn line, {acc, open?} ->
      cond do
        open? and line =~ @sections -> {acc, true}
        true -> {[line | acc], line =~ @open}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end
