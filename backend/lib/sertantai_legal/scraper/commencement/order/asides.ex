defmodule SertantaiLegal.Scraper.Commencement.Order.Asides do
  @moduledoc """
  The bracketed asides in a commencement order's list of provisions: words
  in brackets after an item ("2 (except sub-paragraphs (2) and (9)(b))",
  "35 (insofar as it adds …)", "section 19 (charging)", "(so far as not
  already in force)"), as against an item's own brackets ("32(1) to (13)").
  Pure text.
  """

  # a bracket holding words (a space), its own brackets one deep
  @aside ~S"\((?=(?:[^()]|\([^()]*\))*\s)(?:[^()]|\([^()]*\))*\)"

  # an aside that says how far or what: a qualifier, an exception, a
  # provision — any other is the provision's heading
  @aside_says ~r/^\(\s*(?:and\s+|but\s+|only\s+)?(?:(?:in\s*)?so\s*far|insofar|in\s+as\s+far|to\s+the\s+extent|for\s+(?:the\s+)?(?:purposes?|all|certain|specified|limited|particular)\b|except|save|other\s+than|apart\s+from|with\s+the\s+exception|subject\s+to|excluding|including|not\b|only\b|in\s+relation\s+to|as\s+respects|as\s+(?:it|they)\s+appl|in\s+(?:England|Wales|Scotland|Northern\s+Ireland|Great\s+Britain)|which\b|that\b|where\b|being\b|(?:sub-?)?(?:sections?|paragraphs?)\b|Parts?\b|Schedules?\b|\d)/iu

  @aside_re ~r/#{@aside}/u

  @doc """
  `text` without its asides — they are no refs: "paragraphs 1, 2 (except
  sub-paragraphs (2) and (9)(b)), 3 to 7" reads on to 3 to 7 (SI 1995/2950).
  """
  @spec strip(String.t()) :: String.t()
  def strip(text), do: String.replace(text, @aside_re, "")

  @doc """
  `text` without its items' bracketed headings: "section 86 (water and
  sewerage undertakers in England: modifying appointments)" (SI 2022/48) —
  a heading's "in England" or "for the purpose of" is never the item's
  own. An aside that qualifies ("(so far as relating to England)",
  "(except subsection (1))") stays.
  """
  @spec drop_headings(String.t()) :: String.t()
  def drop_headings(text),
    do: Regex.replace(@aside_re, text, &if(&1 =~ @aside_says, do: &1, else: ""))

  @item_aside ~r/(\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s*(#{@aside})/u

  @doc """
  Each numbered item with the aside after it: "1, 2 (except sub-paragraphs
  (2) and (9)(b)), 3" → [{"2", "except sub-paragraphs (2) and (9)(b)"}].
  """
  @spec items(String.t()) :: [{String.t(), String.t()}]
  def items(text) do
    for [_, item, aside] <-
          Regex.scan(@item_aside, text),
        do: {item, aside |> String.slice(1..-2//1) |> String.trim()}
  end
end
