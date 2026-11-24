defmodule SertantaiLegal.Scraper.Commencement.Order.OtherLaw do
  @moduledoc """
  The words of a commencement order that give provisions to a law by
  pointing at it: a statement's head naming the law whose provisions it
  lists ("The following provisions of the 2023 Act come into force …": SI
  2024/452, an order commencing two Acts), and "of that Act" after a law
  its item names ("section 3ZA of the Road Traffic Act 1988 has effect for
  the purposes of sections 3 and 3A of that Act": SI 2007/2472 art.2(h)).
  Whether a named law is the Act commenced is the caller's (`own?`). Pure
  text.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Words

  @law ~S"(?:the\s+\d{4}\s+(?:Act|Order|Measure)|(?:the\s+)?[A-Z][\w()',’.-]*\s+(?:(?:[A-Z(][\w()',’.-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\([^()]*\))?\s+\d{4})"
  @head Regex.compile!("\\bprovisions?\\s+of\\s+(#{@law})", "u")
  @named Regex.compile!(@law, "u")
  @that ~r/\b(?i:(?:sub-?)?sections?|paragraphs?|Schedules?|regulations?|articles?|Parts?)\s+\d+(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*\d*(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*)*\s+(?:of|to)\s+(?:that\s+(?:Act|Order|Measure)|those\s+Regulations)\b/u

  @type own? :: (String.t() -> boolean())

  @doc """
  True when a statement's `head` gives the provisions it lists to a law
  other than the Act commenced: "The following provisions of the 2023 Act
  come into force on 25th April 2024—" read for the Planning Act 2008.
  """
  @spec head?(String.t(), own?()) :: boolean()
  def head?(head, own?) do
    case Regex.run(@head, head) do
      [_, law] -> not own?.(bare(law))
      nil -> false
    end
  end

  @doc """
  `item` without the provisions "of that Act" where that Act is another
  law: the law last named before them in the item. With none named, or the
  Act commenced, they stay.
  """
  @spec drop_that_law(String.t(), own?()) :: String.t()
  def drop_that_law(item, own?) do
    @that
    |> Regex.scan(item, return: :index)
    |> Enum.reverse()
    |> Enum.reduce(item, fn [{at, len}], text ->
      if other_before?(binary_part(item, 0, at), own?),
        do: binary_part(text, 0, at) <> binary_part(text, at + len, byte_size(text) - at - len),
        else: text
    end)
  end

  defp other_before?(before, own?) do
    case Regex.scan(@named, before) do
      [] -> false
      named -> not (named |> List.last() |> hd() |> bare() |> own?.())
    end
  end

  defp bare(law), do: String.replace(law, ~r/^the\s+/, "")

  # an aside naming another law qualifies its item only: "16(1), (2) (in so
  # far as it inserts a new paragraph (v) in section 31(2)(b) of the
  # Control of Pollution Act 1974) and (3), 20, …" — the other law's tail
  # had eaten the list to its end (SI 1991/1042 art.2(1), CV-S09 round 6)
  @law_named ~r/\b(?:Act|Order|Regulations|Measure)\s+\d{4}\b/u

  defp drop_law_asides(line) do
    {out, aside, _} =
      line
      |> String.graphemes()
      |> Enum.reduce({"", "", 0}, fn
        "(", {o, _a, 0} -> {o, "(", 1}
        "(", {o, a, d} -> {o, a <> "(", d + 1}
        ")", {o, a, 1} -> {o <> keep_aside(a <> ")"), "", 0}
        ")", {o, a, d} when d > 1 -> {o, a <> ")", d - 1}
        ch, {o, a, 0} -> {o <> ch, a, 0}
        ch, {o, a, d} -> {o, a <> ch, d}
      end)

    out <> aside
  end

  # (a qualifying aside leaves its item partly in force: "section 30 (except
  # for the purposes of any inquiry … under section 98 … of the 1990 Act)":
  # SI 1991/2728 art.3)
  defp keep_aside(aside) do
    cond do
      not Regex.match?(@law_named, aside) -> aside
      Regex.match?(Words.full(), aside) -> ""
      Regex.match?(Words.partial(), aside) -> " (for certain purposes)"
      true -> ""
    end
  end

  # a line naming another law's provisions keeps only the Act's
  # "… the following repeals:— The Employment Medical Advisory Service Act
  # 1972 – sections 1 and 6 …" (SI 1974/1439 Sch. 2): a law's title then a
  # dash heads that law's provisions, to the end of the line (CV-S04)
  @abbreviated "(?<=\\bthe\\s)(?!(?:UK|GB|EU|EEA|EC)\\b)[A-Z]{2,6}(?![\\w(])"

  @titled ~r/\b(?:the\s+)?((?:[A-Z][\w()',-]*\s+)(?:(?:[A-Z][\w()',-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\s*[–—-]\s+.*$/u

  # "… the repeals to the Game Licences Act 1860 …", "in relation to the
  # Water Resources Act 1991, the repeal of sections 1 to 14 …": what follows
  # is that law's (SI 1996/396, SI 1996/186; CV-S04 round 3)
  # … to the end of its item: never the Act's own "in Part VI of Schedule 16
  # to the Act" after it (SI 1991/685); "in the Town and Country Planning Act
  # 1990, sections 226 and 245" (SI 2004/2593)
  # … "inserting into the WIA paragraph 11 of Schedule 1A" (SI 2005/2714
  # art.4(a)): a capital abbreviation the order never gives the Act is
  # another law's (never a place: the UK, GB, the EU, the EEA); "into" a
  # titled law leaves the item's purpose words ("the provisions inserted
  # into the Town and Country Planning Act 1990 by that section … enable
  # the Secretary of State to make regulations": SI 2013/1124)
  @other_law_tail ~r/\b(?:(?:the\s+)?repeals?\s+(?:to|of|in|relating\s+to)|in\s+relation\s+to|into(?=\s+the\s+[A-Z]{2,6}(?![\w(]))|in)\s+(?:the\s+)?((?:[A-Z][\w()',-]*\s+)(?:(?:[A-Z][\w()',-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?|#{@abbreviated})\b.*?(?=\s+in\s+(?:Part\s+\w+\s+of\s+)?Schedule\s+\d+[A-Z]*\s+to\s+the\s+Act\b|;|$)/u

  # an item opening with another law's title: "The Public Health Act 1936,
  # sections 72(1) to (5), and 73 to 76;" (SI 1988/818, the repeals its
  # s.108(2) row names)
  @opens_other_law ~r/^\s*(?:the\s+)?((?:[A-Z(][\w()',.-]*\s+){1,10}(?:Act|Order|Regulations|Measure)\s+\d{4})\s*,/u

  # "sections 2 and 3 of the Gas Act 1986": another law's provisions
  # (opening its sentence: "Section 105 of the 2023 Act … comes into force":
  # SI 2024/452 reg.4; a Part: "for the purposes of the application of Part 1
  # of the 2006 Act": SI 2021/1322; with its Chapter and Schedule: "section
  # 63(3)(b), Chapter 1 of Part 4 and section 86 of, and Schedule 5 to, the
  # Police Act 1996": SI 2004/913; "sections 1(3) and 32(5) of and Schedule 2
  # to the 1996 Act": SI 1999/3271)
  @other_law_provisions ~r/\b(?i:sections?|paragraphs?|Schedules?|regulations?|articles?|Parts?)\s+\d+(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*(?:Chapter\s+\w+\s+of\s+Part\s+\w+|(?:sections?\s+)?(?:\d+(?:[A-Z]+\d*)*)?(?:\([0-9A-Za-z]+\))*))*(?:\s*\([^()]*\))?,?\s+(?:of|to|into),?\s+(?:and\s+(?:(?:Schedules?|paragraphs?|Parts?|of|and|\d+[A-Z]*(?:\([0-9A-Za-z]+\))*|\([0-9A-Za-z]+\))[\s,]+)+?to,?\s+)?(?:Schedule\s+\d+[A-Z]*\s+to\s+)?(?:the\s+)?((?:\d{4}\s+)?(?:[A-Z(][\w()',.-]*\s+){0,10}(?:(?:of|and|for|the|in|on|at|to|with|etc\.)\s+(?:[A-Z(][\w()',.-]*\s+){0,8})*(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)/u

  # "Articles 3 to 20 and 49A to 52 of and Schedules 1, 2, 3 and 5 to the
  # Fire Services (Northern Ireland) Order 1984" (NISR 2006/257 art.2(e)):
  # another Order's Articles, what a repeals Schedule relates to
  # (never past an "of the" or "to the" naming another law: "so much of
  # Article 280 of the 2006 Order as is necessary to enable regulations under
  # Article 7B(5) of the Water (Northern Ireland) Order 1999 to be made",
  # NISR 2007/282 art.2(1), is Article 280 of the 2006 Order's)
  @other_order_articles ~r/\bArticles?\s+\d(?:(?!\s(?:of|to)\s+the\s)[^;])*?\s+(?:of|to)\s+the\s+((?:[A-Z(][\w()',.-]*\s+)(?:(?:[A-Z(][\w()',.-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}Order\s+\d{4})/u

  @quoted ~r/“[^”]*”|"[^"]*"|‘[^’]*’/u

  @ends_other_law ~r/,\s+to\s+the\s+((?:\d{4}\s+)?[A-Z(][\w()',.-]*(?:\s+(?:[A-Z(][\w()',.-]*|of|and|for|the|in|on|at|to|with|etc\.))*\s+(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\s*[,.]?\s*$/u

  # the headings that go with a range are no provisions of their own, and
  # the range still belongs to the law named after them: "sections 33A to
  # 33C and 33E to 33O including italic headings immediately preceding
  # section 33J and section 33O of the 2000 Act" (SI 2012/57 art.4(1))
  @italic_headings ~r/,?\s+including\s+(?:the\s+)?italic\s+(?:cross-?)?headings?\s+(?:immediately\s+)?(?:preceding|before)\s+(?:that\s+section|(?:sections?\s+)?\d+(?:[A-Z]+\d*)*(?:\s+and\s+(?:sections?\s+)?\d+(?:[A-Z]+\d*)*)*)/iu

  @doc "The line without the items it names in other laws."
  @spec drop_other_laws(String.t(), [String.t()]) :: String.t()
  def drop_other_laws(line, aliases) do
    own? = &own_law?(&1, aliases)

    line =
      line
      |> String.replace(@quoted, " ")
      |> String.replace(@italic_headings, "")
      |> drop_law_asides()
      |> String.split(~r/;\s*/u)
      |> Enum.reject(&other_law_item?(&1, own?))
      |> Enum.map_join("; ", &drop_that_law(&1, own?))

    keep_own = fn whole, law -> if own?.(law), do: whole, else: "" end

    [@other_order_articles, @other_law_tail, @titled, @other_law_provisions]
    |> Enum.reduce(line, fn re, line ->
      Regex.replace(re, line, keep_own)
    end)
  end

  # "the Act", or a name its aliases hold
  @doc "True when the law named is the Act commenced (\"the Act\", an alias, its short title)."
  @spec own_law?(String.t(), [String.t()]) :: boolean()
  def own_law?(law, aliases),
    do:
      Enum.any?(aliases, &String.contains?(Words.norm("the " <> law), &1)) or
        Words.norm(law) in ["act", "the act"] or short_title?(Words.norm(law), aliases)

  # the Act's title without its year, or cut at "Act" before its bracket:
  # "Section 116 of the Environment Act, insofar as …" (SI 1998/781),
  # "Schedule 3 to the Environmental Better Regulation Act (Northern
  # Ireland) 2016" (NISR 2016/332)
  defp short_title?(name, aliases),
    do: name =~ ~r/^[a-z].* / and Enum.any?(aliases, &String.starts_with?(&1, name <> " "))

  # an item ending or opening with another law's name
  defp other_law_item?(item, own?) do
    case Regex.run(@ends_other_law, item) || Regex.run(@opens_other_law, item) do
      [_, law] -> not own?.(law)
      nil -> false
    end
  end
end
