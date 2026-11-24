defmodule SertantaiLegal.Scraper.Commencement.Order.Statements do
  @moduledoc """
  A commencement order article's statements: its heads, their qualifiers, and
  the items each head brings in.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Dates,
    Items,
    OtherLaw,
    Purposes,
    RepealLists,
    Words
  }

  alias SertantaiLegal.Scraper.Commencement.Rule

  # ── statements in articles ──────────────────────────────────────────

  # an article (or paragraph) whose own words state a commencement: its
  # first such line is the statement, the lines below are its items
  @doc "The rules of the order's articles whose own words state a commencement."
  @spec statements(Doc.t(), [String.t()]) :: [Rule.t()]
  def statements(order, aliases) do
    made = Dates.made(order)

    # (a lettered paragraph is a statement of its own where the article's
    # words state none: "Except as provided by Article 2 of this Order— (a)
    # the following provisions … shall come into operation on 1st December
    # 1964 …; (b) …": SI 1964/1045)
    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*|-[a-z])?$/),
        words = order |> Text.words_of(id) |> Words.wording(),
        Regex.match?(Words.cif(), words) or Regex.match?(Words.appointed(), words) or
          Regex.match?(Words.appointed_is(), words),
        lines =
          order
          |> Doc.element(id)
          |> RepealLists.prune()
          |> Doc.lines()
          |> Items.join_open()
          |> Enum.map(&Words.clean_line/1)
          |> closing_date(),
        {pre, head, rest} = split_head(lines),
        head != nil,
        head <- Dates.two_days(head),
        not already_in_force?(head),
        {date, inline} <- List.wrap(Dates.statement(head, made)),
        # "The following provisions of the 2023 Act come into force …": the
        # 2023 Act's, never the order's other Act's (SI 2024/452)
        not OtherLaw.head?(head, &OtherLaw.own_law?(&1, aliases)),
        # "in so far as it relates to the following repeals in Part I of
        # Schedule 16 …: the repeal of section 1(1)(d) … of the Health and
        # Safety at Work etc. Act 1974; …" (SI 1996/3056): the entries below
        # are other provisions' repeals, never commenced by it
        rest = if(head =~ Words.entries_head(), do: [], else: rest),
        items = Enum.reject(pre ++ [Words.clean_line(inline) | rest], &(&1 == "")),
        q <- [list_qualifier(head)],
        rule <-
          Enum.map(
            Items.item_rules(items, aliases, date, order.law_name, id, head),
            &qualified(&1, q)
          ) ++
            elsewhere_rules(order, id, head, aliases, date),
        do: rule
  end

  # "The day appointed for the coming into force of— (a) section 67 …; (b)
  # …; is 1 April 2004." (WSI 2004/910 art.2(1)): the day after the list is
  # the head's — a bare date only, never "is 19th September 2004 or the end
  # of a period of six months …" (SI 2004/2173)
  @open_appointed ~r/\b(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b(?!.*\bis\b)/isu

  @closing_day ~r/^\W*(?:is|shall\s+be)\s+((?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\s+[A-Z][a-z]+\s+\d{4})\s*\.?$/u

  @doc "A \"the following\" head dated by the date closing its list."
  @spec closing_date([String.t()]) :: [String.t()]
  def closing_date(lines) do
    with [_ | _] <- lines,
         [_, day] <- Regex.run(@closing_day, List.last(lines)),
         {before, [open | items]} <-
           Enum.split_while(Enum.drop(lines, -1), &(not (&1 =~ @open_appointed))) do
      before ++ ["#{open} the following is #{day}" | items]
    else
      _ -> lines
    end
  end

  # "… after the amendments made by paragraphs 1(2)(a) and 8(3) of Schedule
  # 5 to the 1994 Act have come into force, those sections shall have effect
  # as if …" (SI 1994/3262 art.3(2)): provisions that "have come into force"
  # are spoken of as in force, never brought in — a head whose every "come
  # into force" is so worded states no commencement
  @in_force_already ~r/\b(?:has|have|had|having)\s+come\s+into\s+(?:force|operation)\b/i

  @doc "True when a head only speaks of provisions as already in force."
  @spec already_in_force?(String.t()) :: boolean()
  def already_in_force?(head) do
    said = length(Regex.scan(@in_force_already, head))
    said > 0 and said == length(Regex.scan(Words.cif(), head))
  end

  # completing or a place, never a purpose: "so far as not already
  # commenced" (SI 2024/35), "To the extent to which they have not already
  # been commenced" (SI 2004/2593), "(in so far as not coming into force
  # under article 2(9))" (SI 2010/2317), "Except to the extent that they
  # extend to Scotland" (SI 2005/1521)
  @head_completing ~r/\bnot\s+(?:already\s+|yet\s+|previously\s+)?(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force|coming\s+into\s+force)\b|\bextends?\s+to\b/i

  @head_place ~r/\b(?:in relation to|in|as respects)\s+(?:England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\b/i

  # a "the following" head's own qualifier, before its list, reaches each
  # item with none of its own ("… on 18th February 1993 but only insofar as
  # they enable the Secretary of State to give directions—": SI 1993/274
  # art.2(2); "…, for the purpose of making regulations …, on the day after
  # …—": SI 2015/425 art.2); its place is the territory, never a qualifier
  defp list_qualifier(head) do
    words = head |> String.split(~r/[—–]/u, parts: 2) |> hd()

    if words =~ ~r/\bthe\s+following\b/i and not (words =~ @head_completing),
      do: words |> String.replace(@head_place, "") |> head_qualifier()
  end

  defp qualified(rule, nil), do: rule
  defp qualified(%Rule{purposes: nil} = rule, q), do: %{rule | purposes: q}
  defp qualified(rule, _q), do: rule

  # a paragraph's statement whose items are in other paragraphs: "listed in
  # paragraph (2) below" (SI 1994/2025 art.3(1)), "specified in article 3
  # below" (SI 1994/3188), "specified in the following paragraphs of this
  # regulation" (SI 2025/272 reg.2(1)) — those paragraphs' lines, less a
  # head pointing back ("The provisions referred to in paragraph (1) above
  # are—")
  @elsewhere_para ~r/\b(?:listed|specified|referred\s+to|set\s+out|mentioned)\s+in\s+paragraph\s+\((\d+[A-Z]?)\)/i

  @elsewhere_article ~r/\b(?:listed|specified|referred\s+to|set\s+out|mentioned)\s+in\s+(article|regulation)\s+(\d+[A-Z]*)\s+below\b/i

  @following_paras ~r/\b(?:in|by)\s+the\s+following\s+paragraphs\b/i

  @points_back ~r/^\W*(?:The\s+)?(?:provisions?|enactments?)?\s*referred\s+to\s+in\s+(?:paragraph|article|regulation)\b[^.;]*?\b(?:are|is)\b\s*[—–:-]*/i

  # the items another paragraph lists, each with the statement's own
  # qualifier ("… set out in paragraph (3) below shall come into force on
  # 1st May 1994, save for the purposes of their application to the
  # following activities": SI 1994/1096 art.2(2))
  defp elsewhere_rules(order, id, head, aliases, date) do
    case elsewhere(order, id, head) do
      [] ->
        []

      lines ->
        qualifier = head_qualifier(head)

        lines
        |> Items.item_rules(aliases, date, order.law_name, id, head)
        |> Enum.map(&%{&1 | purposes: &1.purposes || qualifier})
    end
  end

  defp head_qualifier(head) do
    if Regex.match?(Words.partial(), head) and not Regex.match?(Words.full(), head),
      do: Purposes.purposes(head)
  end

  defp elsewhere(order, id, head) do
    for other <- pointed_to(order, id, head),
        el = Doc.element(order, other),
        el != nil,
        line <- el |> Doc.lines() |> Items.join_open() |> Enum.map(&Words.clean_line/1),
        line = line |> String.replace(@points_back, "") |> String.trim(),
        line != "",
        # (the paragraph's own number, a line of its own, is no item: "53"
        # under a live Schedule read as its paragraph 53 — SI 2026/323)
        line != other |> String.split("-") |> List.last(),
        do: line
  end

  # (never what an exception points to: "… except the provisions listed in
  # paragraph (2)" — those are left out, `listed/3`: SI 2008/401)
  defp pointed_to(order, id, head) do
    subject = head |> String.split(Words.cif(), parts: 2) |> hd()

    if subject =~
         ~r/\bpurposes?\s+(?:\w+\s+){0,3}(?:listed|specified|referred\s+to|set\s+out|mentioned)\s+in\b/i or
         head =~
           ~r/\b(?:except|other\s+than|apart\s+from)\b[^.;]*?\b(?:listed|specified|referred\s+to|set\s+out|mentioned)\s+in\s+(?:paragraph|article|regulation)\b/i,
       do: [],
       else: pointed_to_items(order, id, subject)
  end

  defp pointed_to_items(order, id, head) do
    case Regex.run(~r/^((?:article|regulation)-\d+[A-Z]*)-\d+[A-Z]*$/, id) do
      [_, parent] -> paragraphs_pointed(order, id, parent, head)
      nil -> articles_pointed(head)
    end
  end

  defp paragraphs_pointed(order, id, parent, head) do
    case Regex.run(@elsewhere_para, head) do
      [_, n] ->
        [parent <> "-" <> n]

      nil ->
        if Regex.match?(@following_paras, head),
          do: later_paragraphs(order, id, parent),
          else: articles_pointed(head)
    end
  end

  defp articles_pointed(head) do
    case Regex.run(@elsewhere_article, head) do
      [_, kind, n] -> [String.downcase(kind) <> "-" <> n]
      nil -> []
    end
  end

  defp later_paragraphs(order, id, parent) do
    n = id |> String.split("-") |> List.last() |> Integer.parse() |> elem(0)

    Enum.filter(order.ids, fn other ->
      case Regex.run(~r/^#{Regex.escape(parent)}-(\d+)[A-Z]*$/, other) do
        [_, m] -> String.to_integer(m) > n
        _ -> false
      end
    end)
  end

  # {items before the statement, the statement line, the lines after}: an
  # older order lists its items first and states the date last ("The
  # following provisions of the … Act 1981, namely— (a) Part I …; (b) …
  # shall come into force on 28th September 1982": CR-07, SI 1982/1217)
  defp split_head(lines) do
    case Enum.split_while(
           lines,
           &(not (Regex.match?(Words.cif(), &1) or Regex.match?(Words.appointed(), &1) or
                    Regex.match?(Words.appointed_is(), &1)))
         ) do
      {before, [head | rest]} ->
        case Enum.split_while(before, &(not (&1 =~ ~r/\b(?:namely|the following)\b/i))) do
          {_, [header | items]} ->
            {first_items(header, items), head, Enum.reject(rest, &(&1 == ""))}

          _ ->
            {[], head, Enum.reject(rest, &(&1 == ""))}
        end

      _ ->
        {[], nil, []}
    end
  end

  # "The following provisions of the Act, namely in Schedule 8, the entries
  # relating to:— (a) section 97 of the National Parks … Act 1949, …" (SI
  # 1978/1583 art.3): the header's own words are the item — that Schedule's
  # entries — and the lines below only describe them
  @namely_entries ~r/\bnamely\s*,?\s*(in\s+(?:the\s+Schedule|Schedule\s+\d+[A-Z]*)\b[^;]*?\bthe\s+(?:repeals?|entr(?:y|ies))\b.*)$/isu

  # "The following subsections of section 13 of the Control of Pollution Act
  # 1974, namely— (a) subsections (5) and (6) (…), …" (SI 1978/954 art.3):
  # the items are that section's
  @of_section ~r/\bthe\s+following\s+sub-?sections\s+of\s+section\s+(\d+[A-Z]*)\b/iu

  defp first_items(header, items) do
    case {Regex.run(@namely_entries, header), Regex.run(@of_section, header)} do
      {[_, entries], _} -> [entries]
      {nil, [_, n]} -> ["in section #{n}—" | items]
      {nil, nil} -> items
    end
  end
end
