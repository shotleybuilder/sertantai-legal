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
  - A relative clause limiting the provisions an item names ("any provision
    of Parts 1 to 7 which— confers a power …") leaves them partly in.
  - A closing qualifier pointing back to provisions the list names limits
    the items after them only (`LawStart.PointingBack`); a Schedule's Part
    named for its repeals or entries only is partly in.
  - A qualifier binds the last provision before it: "Part I of Schedule 8
    and section 67(3) so far as relating to that Part" leaves only section
    67(3) partly in (1986 c.44 s.68(2)); in an exception, the provision is
    excepted only so far ("Part IV, except section 72(4), (6) and (14) and
    section 73(1) so far as relating to Part II of Schedule 17": 1981 c.69
    s.74(2)) — it comes in with the item, partly.

  Pure text: the caller reads each part's refs.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Asides
  alias SertantaiLegal.Scraper.LawStart.PointingBack

  @type item :: %{plain: String.t(), excepted: String.t(), qualified: String.t()}

  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i
  # a relative clause limiting the provisions an item names ("any provision
  # of Parts 1 to 7 which— (i) confers a power to make regulations, or (ii)
  # modifies legislation so as to confer a power …": the Agriculture Act
  # 2020 s.57(1)(b)) leaves them partly in, as a qualifier does: its verb,
  # or the dash its own items follow
  @limited ~r/\bprovisions?\s+of\s+[^;]*?\b(?:which|that)\s*(?:[—–]\s*$|(?:confers?|modif(?:y|ies)|amends?|relates?|appl(?:y|ies)|makes?|inserts?|affects?|enables?)\b)/iu
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
  # (the provision can be one subsection: "Part I of Schedule 11 to this
  # Act and subsection (8) of section 67 so far as it relates to that Part
  # of that Schedule", 1994 c.21 s.68(6)(f))
  @last_qualified ~r/^(.*?)(?:,|\s+and|\s*\(and)\s+((?:(?:sub-?section|paragraph)\s+\(\w+\)\s+of\s+)?(?:regulations?|sections?|articles?|rules?)\s+\d+[A-Z]*(?:\([^)\s]+\))*)\s+(?:to\s+the\s+extent\s+that\s+it|(?:in\s+)?so\s+far\s+as\s+(?:it|relating)|insofar\s+as\s+(?:it|relating))\b.*$/is

  # a qualifier's dash ends its item in a list written in one text
  # ("section 103(1), so far as it relates— section 129; …; subsection (1)
  # of section 170, so far as relating to the following— section 112A(1)
  # of the Land Registration Act 1925; …": 1988 c.33 s.171(5)): what
  # follows is the next item, or the qualifier's matter, another law's
  @qualifier_dash ~r/(?<=\bso\sfar\sas\sit\srelates|\bso\sfar\sas\srelating\sto\sthe\sfollowing)\s*[—–]\s*/u

  @doc """
  The items of a list: the words before the verb, the inline list after it
  and the rows under the statement.
  """
  @spec split(String.t(), String.t(), [String.t()]) :: [String.t()]
  def split(before, inline, children) do
    items =
      [before, inline | children]
      |> Enum.join("; ")
      |> String.replace(@qualifier_dash, "; ")
      |> String.split(~r/;\s*/, trim: true)

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
    case PointingBack.split(item) do
      {plain, limited} -> plain |> read_own() |> also_qualified(limited)
      nil -> read_own(item)
    end
  end

  defp also_qualified(read, more), do: %{read | qualified: join(read.qualified, more)}

  defp read_own(item) do
    {item, entries} = entries_only(item)
    read_own(item, entries)
  end

  # a Schedule's Part named for some of its repeals or entries only ("in
  # Part 1 of Schedule 5, the repeals to the Greater London Council
  # (General Powers) Act 1982": CNEA 2005 s.108(4)(a); "in Part 3 of
  # Schedule 23, the repeals relating to …": 2009 c.25 s.182(3)(d)) is
  # partly in: `{the item without the Part, the Part}`
  @entries_only ~r/\bin\s+(Part\s+(?:\d+|[IVXL]+)[A-Z]?\s+of\s+Schedule\s+\d+[A-Z]*),\s+(?=the\s+(?:repeals?|revocations?|entry|entries)\s+(?:to|of|in|relating\s+to)\b)/

  defp entries_only(item) do
    parts = for [_, part] <- Regex.scan(@entries_only, item), do: part
    {Regex.replace(@entries_only, item, ""), Enum.join(parts, " and ")}
  end

  defp read_own(item, entries) do
    {item, aside} = item |> bracket_qualifier_after() |> aside_qualified()
    {item, bracketed} = bracket_except(item)
    {inside, outside} = item |> split_except() |> exception_end()

    read =
      cond do
        not qualified?(item) -> part(inside, outside, "")
        outside == "" -> qualified_item(item)
        true -> qualified_exception(item, inside, outside)
      end

    %{
      read
      | excepted: String.trim(read.excepted <> " " <> bracketed),
        qualified: read.qualified |> join(aside) |> join(entries)
    }
  end

  # an exception ends where the item goes on to a Schedule's entries
  # ("Part 7 above except sections 83(2) and 85, and in Part 7 of Schedule
  # 5, the repeals to …": CNEA 2005 s.108(2)(n)): they are the item's
  @exception_end ~r/,\s+and\s+(?=in\s+(?:Part\s+\w+\s+of\s+)?Schedule\s+\d)/i

  defp exception_end({inside, outside}) do
    case Regex.split(@exception_end, outside, parts: 2) do
      [excepted, more] -> {inside <> " and " <> more, excepted}
      [_all] -> {inside, outside}
    end
  end

  defp join(text, ""), do: text
  defp join("", aside), do: aside
  defp join(text, aside), do: text <> " and " <> aside

  # a provision brought in beside the item, in brackets, only so far as it
  # relates to it: `{the item without the aside, that provision}` — the
  # items after the aside stay the list's ("sections 117(7) (and section
  # 117(6) so far as relates to it), 158, 167, …": SOCPA 2005 s.178(1)(a));
  # the provision can be several ("(and section 115(1) and (2) so far as
  # relating to those Parts of those Schedules)": 2012 c.9 s.120(5)(b))
  @aside_qualified ~r/\s*\(and\s+((?:sections?|regulations?|articles?|rules?)\s+\d[\w()]*(?:\s*(?:,|and|to)\s*[\d(][\w()]*)*)\s+(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent)\b[^()]*\)/i

  defp aside_qualified(item) do
    case Regex.run(@aside_qualified, item) do
      [aside, provision] -> {String.replace(item, aside, "", global: false), provision}
      nil -> {item, ""}
    end
  end

  # a qualifier in brackets before its provision, put after it: "Part 1 of
  # Schedule 17 and (so far as it relates to that Part of that Schedule)
  # section 174(2)" (SOCPA 2005 s.178(1)(b))
  @bracket_qualifier_first ~r/\band\s+\(((?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\s+(?:it|they)\s+relates?\s+to\s+[^()]+)\)\s+((?:sections?|regulations?|articles?|rules?)\s+\d[\w()]*)/i

  defp bracket_qualifier_after(item),
    do: Regex.replace(@bracket_qualifier_first, item, "and \\2 \\1")

  # (a heading in brackets qualifies nothing: "section 221 (exercise of
  # compulsory purchase powers in relation to Crown land)")
  # … but a provision qualified in brackets does: "paragraph 1(2) of
  # Schedule 3 (and Article 65 so far as relating thereto)" (NISI 2003/419
  # art.1(3)(e))
  defp qualified?(item) do
    own = Asides.drop_headings(item)

    Regex.match?(@qualified, own) or Regex.match?(@limited, own) or
      Regex.match?(~r/\(and\s+.*?\b(?:so\s+far\s+as|to\s+the\s+extent)\b/i, item)
  end

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
  @extent_only ~r/^\s*(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent)\b/i
  @own_provision ~r/^\s*(sections?|regulations?|articles?|rules?)\s+(\d+[A-Z]*)(?:\(|\s|$)/i
  @own_subsections ~r/^\s*(?:sub-?sections?|paragraphs?)\s+((?:\(\w+\)(?:\s*(?:,|and)\s*)?)+)\s*(?:in\s+)?so\s+far\s+as\b/i

  # … an item excepted only so far as it relates to something is itself
  # in, partly ("section 9, except so far as relating to sections 21 and 22
  # of the Land Drainage Act 1930": 1973 c.37 s.39(1)); so are its own
  # subsections so excepted ("section 11, except subsection (6) so far as
  # relating to section 12 of the Water Act 1945")
  defp qualified_exception(item, inside, outside) do
    cond do
      Regex.match?(@qualified, inside) -> part("", "", item)
      Regex.match?(@extent_only, outside) -> part("", "", inside)
      own = own_subsections(inside, outside) -> part(inside, own, own)
      true -> last_qualified_exception(item, inside, outside)
    end
  end

  defp last_qualified_exception(item, inside, outside) do
    case qualified_last(outside) do
      {excepted, qualified} -> part(inside, excepted <> " and " <> qualified, qualified)
      nil -> part("", "", item)
    end
  end

  # the item's own subsections, written out in full: "section 11(6)"
  defp own_subsections(inside, outside) do
    with [_, noun, number] <- Regex.run(@own_provision, inside),
         [_, subs] <- Regex.run(@own_subsections, outside) do
      ~r/\(\w+\)/
      |> Regex.scan(subs)
      |> Enum.map_join(" and ", fn [sub] ->
        "#{String.trim_trailing(noun, "s")} #{number}#{sub}"
      end)
    else
      _ -> nil
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
    {text, after_it} = item_after(text)

    case Regex.run(@last_qualified, text) do
      [_, plain, qualified] when after_it != "" ->
        if Regex.match?(@qualified, plain),
          do: nil,
          else: {plain <> " and " <> after_it, qualified}

      [_, plain, qualified] ->
        if Regex.match?(@qualified, plain), do: nil, else: {plain, qualified}

      nil ->
        nil
    end
  end

  # a plain item after the qualified one, whose qualifier closes on "that
  # paragraph": "regulation 10 insofar as it relates to that sub-paragraph
  # and regulation 21" (NISR 2008/231 reg.1(6)) names regulation 21 in full
  @item_after ~r/^(.*\b(?:so\s+far\s+as|insofar\s+as)\s+it\s+relates\s+to\s+that\s+(?:sub-?)?(?:paragraph|section|Part))\s*,?\s+and\s+((?:regulations?|sections?|articles?|rules?)\s+\d[^,;]*?)[\s,]*$/is

  defp item_after(text) do
    case Regex.run(@item_after, text) do
      [_, before, item] -> {before, item}
      nil -> {text, ""}
    end
  end

  # a qualifier written before its item: "Paragraph (2) of regulation 3 and,
  # so far as it relates to that paragraph, paragraph (3) of that
  # regulation, and regulation 4" (SI 2017/1312 reg.1(3)) qualifies
  # paragraph (3), never regulation 4
  @qualifier_first ~r/\band,\s*((?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\s+it\s+(?:relates|applies)\s+to\s+that\s+[\w-]+),\s*([^,;]+?)(?=\s*[,;]|\s+(?:shall\s+)?comes?\s+into\b)/i

  # a list of one Schedule's provisions ("The following provisions of
  # Schedule 2, and section 55 to the extent it relates to those
  # provisions, … come into force …— paragraph 2; Part 2": asc 2023/4
  # s.56(3)): its bare paragraphs and Parts are that Schedule's
  @schedule_list ~r/\bthe\s+following\s+provisions\s+of\s+Schedule\s+(\d+[A-Z]*)\b(?!\s+(?:to|of)\s+th)/i
  @bare_schedule_item ~r/^(\W*(?:paragraphs?|Parts?)\s+(?:\d[\w()]*|[IVXL]+\b)(?:\s*(?:,|and|to)\s*(?:\d[\w()]*|[IVXL]+\b))*)(?!\s+of\s+(?:the\s+)?Schedule)/
  @head_aside ~r/,?\s+and\s+((?:sections?|regulations?|articles?|rules?)\s+\d[\w()]*(?:\s*(?:,|and|to)\s*\d[\w()]*)*)\s*,?\s+(?:to\s+the\s+extent(?:\s+that)?|(?:in\s+)?so\s+far\s+as|insofar\s+as)\s+(?:it|they)\s+relates?\s+to\s+those\s+provisions\s*,?/i

  @doc """
  The list's head without a provision it brings in only so far as it
  relates to the listed ones: `{the head, that provision}` ("" for none).
  """
  @spec head_aside(String.t()) :: {String.t(), String.t()}
  def head_aside(head) do
    case Regex.run(@head_aside, head) do
      [aside, provision] -> {String.replace(head, aside, "", global: false), provision}
      nil -> {head, ""}
    end
  end

  @doc """
  The items of a list of one Schedule's provisions, each bare paragraph or
  Part named as that Schedule's; any other list's items as they are. A
  qualified item names only the provision before its qualifier.
  """
  @spec in_schedule([item()], String.t()) :: [item()]
  def in_schedule(items, head) do
    case Regex.run(@schedule_list, head) do
      [_, n] -> Enum.map(items, &schedule_item(&1, n))
      nil -> items
    end
  end

  defp schedule_item(item, n) do
    %{
      item
      | plain: of_schedule(item.plain, n),
        qualified: item.qualified |> before_qualifier() |> of_schedule(n)
    }
  end

  defp of_schedule(text, n), do: Regex.replace(@bare_schedule_item, text, "\\1 of Schedule #{n}")

  @part_list ~r/\bthe\s+following\s+provisions\s+(?:in|of)\s+Part\s+(\d+[A-Z]*|[IVXL]+)\b(?!\s+(?:to|of)\s+th)/
  @bare_chapter_item ~r/^(\W*Chapters?\s+(?:\d+[A-Z]*|[IVXL]+\b)(?:\s*(?:,|and|to)\s*(?:\d+[A-Z]*|[IVXL]+\b))*)(?!\s+of\s+Part)/

  @doc """
  The items of a list of one Part's provisions ("the following provisions
  in Part 7 …— (a) Chapter 2": asc 2021/1 s.175(2)), each bare Chapter
  named as that Part's; any other list's items as they are.
  """
  @spec in_part([item()], String.t()) :: [item()]
  def in_part(items, head) do
    case Regex.run(@part_list, head) do
      [_, n] -> Enum.map(items, &%{&1 | plain: of_part(&1.plain, n)})
      nil -> items
    end
  end

  defp of_part(text, n), do: Regex.replace(@bare_chapter_item, text, "\\1 of Part #{n}")

  defp before_qualifier(text) do
    case Regex.split(@qualified, text, parts: 2) do
      [provision, _qualifier] -> provision
      [text] -> text
    end
  end

  @doc "`subject` with a qualifier written before its item put after it, the form the items are read in."
  @spec qualifier_after(String.t()) :: String.t()
  def qualifier_after(subject),
    do: Regex.replace(@qualifier_first, subject, "and \\2 \\1")

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
