defmodule SertantaiLegal.Scraper.LawStart.Completing do
  @moduledoc """
  The completing words of a commencement statement: "(so far as not in
  force by virtue of subsection (2))" (2026 c.18 s.175(3)), "Part 3 (to
  the extent that it does not come into force in accordance with
  subsection (1))" (2007 c.28 s.245(2)), "In so far as they are not
  already in force, these Regulations come into force on …" (SI 2026/15
  reg.1(3)). They limit nothing — the provisions come into force in full
  on the statement's day — and the subsection they point to is no
  provision of the statement, so the reader reads the statement without
  them. Pure text.
  """

  @so_far ~S"(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent(?:\s+that)?)"
  @not_in_force ~S"(?:(?:it|they|those\s+provisions|that\s+provision)\s+)?(?:(?:is|are|has|have|does|do)\s+)?not\s+(?:(?:already|yet|otherwise|previously)\s+)?(?:been\s+)?(?:brought\s+into|in|come\s+into|coming\s+into)\s+(?:force|operation)\b"
  @by ~S"(?:\s+(?:by(?:\s+virtue\s+of)?|in\s+accordance\s+with|under)\s+(?:sub-?sections?|(?:sub-?)?paragraphs?|sections?|regulations?|articles?)\s+\(?\w+\)?(?:\(\w+\))*(?:\s+(?:or|and)\s+\(\w+\))*(?:\s+of\s+this\s+(?:section|regulation|article))?)?"

  @bracket Regex.compile!("\\s*\\(#{@so_far}\\s+#{@not_in_force}(?:[^()]|\\([^()]*\\))*\\)", "iu")
  @leading Regex.compile!(
             "^(\\W*(?:\\(\\w+\\)\\s*)?)#{@so_far}\\s+#{@not_in_force}#{@by}\\s*,\\s*",
             "iu"
           )
  @set_off Regex.compile!(",?\\s*#{@so_far}\\s+#{@not_in_force}#{@by}(\\s*,)?", "iu")

  @doc "`text` without its completing words; nil for nil."
  @spec drop(String.t() | nil) :: String.t() | nil
  def drop(nil), do: nil

  def drop(text) do
    text
    |> String.replace(@bracket, "")
    |> String.replace(@leading, "\\1")
    |> String.replace(@set_off, "")
  end

  @doc "`row` with its text read without its completing words."
  @spec row(map()) :: map()
  def row(%{text: text} = row) when is_binary(text), do: %{row | text: drop(text)}
  def row(row), do: row
end
