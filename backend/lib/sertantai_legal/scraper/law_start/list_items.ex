defmodule SertantaiLegal.Scraper.LawStart.ListItems do
  @moduledoc """
  The items of a commencement list ("The following provisions … come into
  force on …— section 1; Part IV, except section 72(4); …") and what each
  says of itself: the provisions it names, those it excepts, and those its
  own qualifier leaves partly in.

  - Items part at ";" and at the rows under the statement; a list with no
    ";" parts at a comma before a provision noun ("section 8, section
    317(6), … Part II of Schedule 37 and section 582(1) so far as relating
    thereto, and …": 1996 c.56 s.583(3)).
  - An item's exception is its own, after "except" / "apart from" or in
    brackets ("Part III (apart from section 81(2) and (3))", "Schedule 7
    (apart from paragraphs 6 and 7 of that Schedule)": CROW 2000 s.103(2)).
  - A qualifier binds the last provision before it: "Part I of Schedule 8
    and section 67(3) so far as relating to that Part" leaves only section
    67(3) partly in (1986 c.44 s.68(2)); in an exception, the provision is
    excepted only so far ("Part IV, except section 72(4), (6) and (14) and
    section 73(1) so far as relating to Part II of Schedule 17": 1981 c.69
    s.74(2)) — it comes in with the item, partly.

  Pure text: the caller reads each part's refs.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Asides

  @type item :: %{plain: String.t(), excepted: String.t(), qualified: String.t()}

  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i
  # ("This Part, apart from section 45, comes into force …": asc 2026/4
  # s.46(1); never one in brackets before more items, "This section (apart
  # from subsection (2)) and sections 1, …", whose bracket ends it: 2004
  # c.22 s.11(2))
  @except ~r/,?\s*(?:\b(?:except|other than|with the exception of)\b|(?<!\()\bapart from\b)/i
  @bracket_except ~r/\s*\((?:apart\s+from|except(?:\s+for)?|other\s+than)\s+((?:[^()]|\([^()]*\))+)\)/is
  # a qualifier over several items ("…, and sections 222 and 227, and
  # Schedule 19, in so far as they relate to those paragraphs": 1996 c.52
  # s.232(2)) binds more than its own item
  @plural ~r/\b(?:so\s+far\s+as|to\s+the\s+extent\s+that)\s+they\b/i
  @noun ~S"(?:sections?|regulations?|articles?|rules?|Parts?|Chapters?|Schedules?|paragraphs?|this\s+(?:section|regulation|article|rule|Part))\b"
  @comma Regex.compile!(",\\s*(?:and\\s+)?(?=#{@noun})(?![^()]*\\))", "i")
  @last_qualified ~r/^(.*?)(?:,|\s+and|\s*\(and)\s+((?:regulations?|sections?|articles?|rules?)\s+\d+[A-Z]*(?:\([^)\s]+\))*)\s+(?:to\s+the\s+extent\s+that\s+it|(?:in\s+)?so\s+far\s+as\s+(?:it|relating)|insofar\s+as\s+(?:it|relating))\b.*$/is

  @doc """
  The items of a list: the words before the verb, the inline list after it
  and the rows under the statement.
  """
  @spec split(String.t(), String.t(), [String.t()]) :: [String.t()]
  def split(before, inline, children) do
    items =
      [before, inline | children] |> Enum.join("; ") |> String.split(~r/;\s*/, trim: true)

    case {items, children} do
      {[one], []} -> at_commas(one)
      _ -> items
    end
  end

  defp at_commas(list) do
    if Regex.match?(@plural, list),
      do: [list],
      else: list |> String.split(@comma, trim: true) |> Enum.reject(&(String.trim(&1) == ""))
  end

  @doc "What an item names in full (`plain`), excepts (`excepted`) and leaves partly in (`qualified`)."
  @spec read(String.t()) :: item()
  def read(item) do
    {item, bracketed} = bracket_except(item)
    {inside, outside} = split_except(item)

    read =
      cond do
        not qualified?(item) -> part(inside, outside, "")
        outside == "" -> qualified_item(item)
        true -> qualified_exception(item, inside, outside)
      end

    %{read | excepted: String.trim(read.excepted <> " " <> bracketed)}
  end

  # (a heading in brackets qualifies nothing: "section 221 (exercise of
  # compulsory purchase powers in relation to Crown land)")
  # … but a provision qualified in brackets does: "paragraph 1(2) of
  # Schedule 3 (and Article 65 so far as relating thereto)" (NISI 2003/419
  # art.1(3)(e))
  defp qualified?(item),
    do:
      Regex.match?(@qualified, Asides.drop_headings(item)) or
        Regex.match?(~r/\(and\s+.*?\b(?:so\s+far\s+as|to\s+the\s+extent)\b/i, item)

  # "Part I of Schedule 8 and section 67(3) so far as relating to that
  # Part"; an item wholly qualified is wholly partly in
  defp qualified_item(item) do
    case qualified_last(item) do
      {plain, qualified} -> part(plain, "", qualified)
      nil -> part("", "", item)
    end
  end

  # the qualifier inside the exception: its provision excepted so far,
  # in partly; a qualifier on the item itself leaves the whole item partly in
  defp qualified_exception(item, inside, outside) do
    with false <- Regex.match?(@qualified, inside),
         {excepted, qualified} <- qualified_last(outside) do
      part(inside, excepted <> " and " <> qualified, qualified)
    else
      _ -> part("", "", item)
    end
  end

  defp part(plain, excepted, qualified),
    do: %{plain: plain, excepted: excepted, qualified: qualified}

  @doc """
  The last provision of `text` with a qualifier of its own: `{the words
  before it, the provision}` — "regulation 4 and regulation 6 to the extent
  that it applies to regulation 4" (SI 1994/232 reg.1(b)); nil for none, or
  where the words before it are qualified too.
  """
  @spec qualified_last(String.t()) :: {String.t(), String.t()} | nil
  def qualified_last(text) do
    case Regex.run(@last_qualified, text) do
      [_, plain, qualified] ->
        if Regex.match?(@qualified, plain), do: nil, else: {plain, qualified}

      nil ->
        nil
    end
  end

  @doc "`subject` at its exception: `{what it names, what it excepts}` (\"\" for none)."
  @spec split_except(String.t()) :: {String.t(), String.t()}
  def split_except(subject) do
    case Regex.split(@except, subject, parts: 2) do
      [inside, outside] -> {inside, outside}
      [inside] -> {inside, ""}
    end
  end

  # an item's exception in brackets ("Part III (apart from section 81(2)
  # and (3))"): `{the item without it, what it excepts}`; "that Schedule"
  # is the Schedule the item names
  defp bracket_except(item) do
    case Regex.run(@bracket_except, item) do
      [bracket, outside] ->
        inside = String.replace(item, bracket, "", global: false)
        {inside, that_schedule(outside, inside)}

      nil ->
        {item, ""}
    end
  end

  defp that_schedule(outside, inside) do
    case Regex.scan(~r/\bSchedule\s+(\d+[A-Z]*)/, inside) do
      [] ->
        outside

      found ->
        String.replace(
          outside,
          ~r/\bthat\s+Schedule\b/,
          "Schedule " <> (found |> List.last() |> List.last())
        )
    end
  end
end
