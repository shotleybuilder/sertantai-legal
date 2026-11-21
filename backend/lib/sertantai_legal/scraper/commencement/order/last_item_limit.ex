defmodule SertantaiLegal.Scraper.Commencement.Order.LastItemLimit do
  @moduledoc """
  The split of a commencement list whose limit follows its last item:
  "Sections 86(2), … and 96(2) and (3) of the Act, and section 162(1) of
  the Act in so far as it relates to paragraphs 10(3) and 15(3) to (5) of
  Schedule 15" (SI 1991/96 reg.2) — the limit binds the item after the
  final ", and"; the items before it come in fully (RULES
  `a-qualifier-binds-its-own-item`). So too the item after the Act's name:
  "sections 118 and 119 of, and paragraphs 9 and 11 of Schedule 9 to, the
  2003 Act and section 147 of that Act insofar as it relates to those
  paragraphs of that Schedule" (SI 2004/759 art.8). Pure.

  A limit is the whole list's, and the line is left unsplit, where:
  - a comma sets it off from the last item ("…, and section 162(1) of the
    Act, in so far as they relate to …");
  - it is in the plural after a single provision ("section 162(1) … in so
    far as they relate to …");
  - the items before it carry a limit of their own;
  - the items before it are a Schedule's repeals or entries;
  - a further limit follows it after a comma ("…, except in relation to …");
  - it completes ("so far as not already in force") or names a place.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Territory

  @limit "(?:(?:in\\s*)?so\\s*far\\s+as|insofar\\s+as|to\\s+the\\s+extent|for\\s+the\\s+purposes?\\s+of|in\\s+relation\\s+to|as\\s+respects)"
  @item "(?:(?:sub-?)?sections?|(?:sub-?)?paragraphs?|Schedules?|Parts?|Chapters?|articles?|regulations?)"

  @split Regex.compile!(
           "^(.*\\S)(?:\\s*,\\s+and\\s+|(?<=\\bAct)\\s+and\\s+(?=#{@item}\\s+\\S+\\s+of\\s+that\\s+Act\\b))(#{@item}\\b[^,;—–:]*?)\\s+(#{@limit}\\b.*)$",
           "isu"
         )
  # a limit of the earlier items' own, or items that are entries of a
  # Schedule ("the repeals … in Part 3 of Schedule 14 …, and sections 169
  # and 196 … in so far as it relates to those enactments": SI 2006/3397)
  @any_limit Regex.compile!(
               "\\b#{@limit}\\b|\\b(?:except|save|repeals?|revocations?|entr(?:y|ies))\\b",
               "iu"
             )
  # a second limit after the last item's, set off by a comma, is the whole
  # line's ("…, and section 183 in so far as it relates to those
  # paragraphs, except in relation to a compulsory purchase order …": SI
  # 2017/75 art.3)
  @further Regex.compile!(",\\s+(?:#{@limit}|except|save|but)\\b", "iu")
  @completing ~r/\bnot\s+(?:already|yet|previously|then)\b|\balready\s+in\s+(?:force|operation)\b|\bfor\s+all\s+(?:remaining\s+|other\s+)?purposes\b/i
  @plural_item ~r/^(?:sub-?)?(?:sections|paragraphs|Schedules|Parts|Chapters|articles|regulations)\b|\s+and\s+/i
  @plural_limit ~r/^\S+(?:\s+\S+){0,3}?\s+(?:they|those)\b/i

  @doc """
  `{the items before, the last item with its limit}` where the line's limit
  follows its last item; nil where the line has no such limit, or the limit
  is the whole list's.
  """
  @spec split(String.t()) :: {String.t(), String.t()} | nil
  def split(line) do
    with [_, before, item, limit] <- Regex.run(@split, line),
         true <- own?(before, item, limit),
         true <- Territory.of(before) == Territory.of(line) do
      {before, item <> " " <> limit}
    else
      _ -> nil
    end
  end

  @doc "Whether `text` puts a limit after a final \", and <item>\" (the form, whoever it binds)."
  @spec form?(String.t()) :: boolean()
  def form?(text), do: Regex.match?(@split, text)

  defp own?(before, item, limit) do
    not Regex.match?(@any_limit, before) and not Regex.match?(@completing, limit) and
      not Regex.match?(@further, limit) and agrees?(item, limit)
  end

  # "section 162(1) … in so far as they relate to": the plural is the list's
  defp agrees?(item, limit),
    do: Regex.match?(@plural_item, item) or not Regex.match?(@plural_limit, limit)
end
