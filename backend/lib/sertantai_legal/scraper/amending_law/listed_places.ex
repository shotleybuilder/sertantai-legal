defmodule SertantaiLegal.Scraper.AmendingLaw.ListedPlaces do
  @moduledoc """
  The places an amending provision's words point to a list of, elsewhere in
  the amending law, read into its words (Amending-law reader: yield,
  2026-11-27): a sub-paragraph ("In each of the provisions listed in
  sub-paragraph (3)—", SI 2026/386 Sch.2 para.23(2); "In the provisions
  mentioned in sub paragraph (3), for … substitute …", SSI 2005/383 Sch.1
  para.3(2)) or a Schedule, its list or its "Regulation | Provision" table
  ("In the regulations set out in schedule 2 to these Regulations,
  substitute …", SI 2014/1771 reg.3(3)). The pointer is rewritten as
  "provisions listed below" and names no place ("(3)" is never a bracket);
  the list's items follow as places. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}

  @in_sub ~r/\b(?:provisions|regulations|sections|articles)\s+(?:listed|mentioned|specified|set\s+out)\s+in\s+(?:sub[-\s]?paragraph|paragraph|subsection)\s+\(([0-9A-Za-z]+)\)/i
  @in_schedule ~r/\b(?:provisions|regulations|sections|articles)\b(?:,\s*schedules?\s+and\s+parts?\s+of\s+a\s+schedule)?\s+(?:listed|mentioned|specified|set\s+out)\s+in\s+schedule\s+(\d+[A-Z]*)\s+to\s+(?:these\s+Regulations|this\s+(?:Act|Order))/i
  @below "provisions listed below"

  # (never inside a caption: "(which provide for the provisions mentioned in
  # paragraph (a) to be piloted …)", 2011 c.20 s.47(b))
  @caption ~r/\((?:[^()]|\([^()]*\))*\s(?:[^()]|\([^()]*\))*\)/u

  @doc "`words` of the provision `id` in `doc` with the list they point to read in; else as they are."
  @spec expand(Doc.t(), String.t(), String.t()) :: String.t()
  def expand(doc, id, words) do
    bare = String.replace(words, @caption, "")

    cond do
      match = Regex.run(@in_sub, bare) -> sub_list(doc, id, words, match)
      match = Regex.run(@in_schedule, bare) -> schedule_list(doc, words, match)
      true -> under_lead(doc, id, words)
    end
  end

  # a paragraph under a lead that is only the pointer ("In the provisions
  # listed in subsection (9)— (a) for “gateway” substitute …, and (b) for
  # …": 2025 c.18 s.70(8)): its own verb once per item of the lead's list
  # (the lead once crossed every item's places with every law)
  defp under_lead(doc, id, words) do
    parent = String.replace(id, ~r/-[^-]+$/, "")

    with true <- parent != id,
         lead when is_binary(lead) <- Text.words_of(doc, parent),
         {"", [_, n]} <- {lead_verb(lead), Regex.run(@in_sub, lead)},
         list = String.replace(parent, ~r/-[^-]+$/, "-" <> String.downcase(n)),
         true <- list != parent and Doc.element(doc, list) != nil,
         [_ | _] = items <- law_items(doc, list) do
      words |> String.replace(~r/[\s.—–:;,]+(?:and|or)?[\s.—–:;,]*$/u, "") |> per_item(items)
    else
      _ -> words
    end
  end

  @doc "Whether `words` (as `expand/3` gives them) point to a list read in."
  @spec listed?(String.t()) :: boolean()
  def listed?(words), do: String.contains?(words, @below)

  defp sub_list(doc, id, words, [_, n]) do
    list = String.replace(id, ~r/-[^-]+$/, "-" <> String.downcase(n))

    if list == id or Doc.element(doc, list) == nil,
      do: words,
      else: listed_in(doc, list, words, law_items(doc, list))
  end

  # (a list not read leaves no pointer bracket: "subsection (3)" had read
  # as s.4(3), 2004 c.20 s.179(2))
  defp listed_in(_doc, _list, words, :mixed),
    do: Regex.replace(@in_sub, words, "provisions listed")

  defp listed_in(doc, list, words, []), do: with_items(words, @in_sub, item_words(doc, list))
  defp listed_in(_doc, _list, words, items), do: per_law(words, items)

  # a list whose every item names its own law ("regulation 2(1) of the
  # Merchant Shipping (Cargo Ship Construction) Regulations 1997,": SI
  # 2018/1221 reg.3(2)): the instruction once per item, its place after its
  # verb, so each law's part of the text holds the verb ("omit …, in
  # regulation 2(1) of the … Regulations 1997; omit …, in regulation 1(2)
  # of …"; its citation and caption after the year aside: "… Regulations
  # 2004 ( S.I. 2004/3391 ) (restriction on …);", 2025 c.18 s.88(12))
  # (or by a defined term or "that Act": "section 3A(1), (5)(a) and (7) of
  # the 1989 Act (…);", "section 48(1) of that Act (…);", 2004 c.20 s.179(3))
  @law_item ~r/^\s*((?:sections?|regulations?|articles?|rules?)\s+\d.*?(?:\b(?:Act|Regulations|Order|Rules)(?:\s+\(Northern\s+Ireland\))?\s+\d{4}|\bthe\s+\d{4}\s+(?:Act|Regulations|Order|Rules)|\bthat\s+(?:Act|Regulations|Order|Rules)))(?:\s*\((?:[^()]|\([^()]*\))*\))*\s*[,;.]?\s*(?:and|or)?\s*$/iu
  @lead_words ~r/^\s*In\s+(?:each\s+of\s+)?the\s+(?:provisions|regulations|sections|articles)\s+(?:listed|mentioned|specified|set\s+out)\s+in\s+(?:sub[-\s]?paragraph|paragraph|subsection)\s+\([0-9A-Za-z]+\)\s*,?\s*/iu

  # (some items naming laws, others not: :mixed, never crossed with one
  # another — 2013 c.22 Sch.9 para.52's had given s.17 to ten Acts)
  defp law_items(doc, list) do
    items =
      case descendants(doc, list) do
        [] -> lines_after_lead(doc, list)
        ids -> for id <- ids, do: Text.words_of(doc, id)
      end

    items = Enum.reject(items, &(String.trim(&1) =~ ~r/^[.\s…]*$/u))

    places = Enum.map(items, &law_item/1)

    cond do
      items != [] and Enum.all?(places) ->
        places |> List.flatten() |> that_law() |> Enum.flat_map(&siblings/1)

      Enum.any?(places) ->
        :mixed

      true ->
        []
    end
  end

  # "of that Act" is the law of the item before ("section 48(1) of that
  # Act" after "… of the 1989 Act")
  @of_law ~r/\s+of\s+((?:the|that)\s+.*)$/iu
  defp that_law(places) do
    {out, _} = Enum.map_reduce(places, nil, &of_that_law/2)
    out
  end

  defp of_that_law(place, prev) do
    case Regex.run(@of_law, place, capture: :all_but_first) do
      [law] -> that_or_named(place, law, prev)
      nil -> {place, prev}
    end
  end

  defp that_or_named(place, law, prev) when is_binary(prev) do
    if law =~ ~r/^that\s/iu,
      do: {String.replace(place, @of_law, " of " <> prev), prev},
      else: {place, law}
  end

  defp that_or_named(place, law, nil), do: {place, law}

  # a list whose items carry no ids, its lines after "The provisions are—"
  # (2013 c.22 Sch.9 para.52(2)); none when no line leads it
  defp lines_after_lead(doc, list) do
    case doc
         |> Doc.element(list)
         |> Doc.lines()
         |> Enum.split_while(&(not (&1 =~ ~r/[—–:]\s*$/u))) do
      {_, [_lead | items]} -> items
      _ -> []
    end
  end

  # an item naming its law after its place, or its law's title then its
  # places ("Access to Justice Act 1999: sections 17, 17A, 21 and 54 to 57,",
  # a caption after them aside: 2013 c.22 Sch.9 para.52(2) — its places had
  # been crossed with every law's; yield, 2026-11-27)
  @titled_item ~r/^\s*((?:The\s+)?[A-Z][^:;]*?\b(?:Act|Regulations|Order|Rules|Measure)(?:\s+\(Northern\s+Ireland\))?\s+\d{4})(?:\s*\([^()]*\))?\s*:\s*((?:sections?|regulations?|articles?|rules?|paragraphs?)\s+\d.*?)\s*[,;.]?\s*(?:and|or)?\s*$/u

  # an aside naming another law ("section 40(4) until its repeal by the
  # Courts and Legal Services Act 1990 is fully in force": that Act had
  # taken the item's places)
  @until_repeal ~r/\s+until\s+its\s+repeal\b.*?\bin\s+force\b/u

  # a Schedule's place of a named law: an item of the list, no place of it
  # ("paragraph 11(4) of Schedule 11 to the Value Added Tax Act 1994 (c.
  # 23);", 2001 c.16 Sch.2 para.13(2): the list had been left unread)
  @schedule_item ~r/^\s*(?:sub-?)?paragraphs?\s+.*?\bof\s+Schedule\s+\w+\s+to\s+(?:the|that)\s+.*?\b(?:Act|Regulations|Order|Rules)\b/iu

  defp law_item(item) do
    case Regex.run(@law_item, item, capture: :all_but_first) do
      nil when is_binary(item) and item != "" ->
        if item =~ @schedule_item, do: [], else: titled_item(item)

      nil ->
        nil

      place ->
        place
    end
  end

  defp titled_item(item) do
    case Regex.run(@titled_item, item, capture: :all_but_first) do
      [title, places] ->
        places
        |> String.replace(@caption, "")
        |> String.replace(@until_repeal, "")
        |> String.trim()
        |> each_place()
        # (a Schedule's places dropped: no rule by design, and alone a
        # neighbour's section had lent them a number — "paragraphs 16(a)
        # and 16D(a) of Schedule 17" read as s.143(a), 2013 c.22 Sch.9)
        |> Enum.reject(&(&1 =~ ~r/\b(?:Schedule|paragraphs?)\b/u))
        |> Enum.map(&"#{&1} of the #{title}")

      nil ->
        nil
    end
  end

  # a title's places one each ("sections 6A(2) and 40(1) and (3), and
  # section 40(4)": section 6A(2), section 40(1), section 40(3), section
  # 40(4)), the noun and number carried to a bare one ("17A", "(3)"); a
  # range ("54 to 57") or any other piece ("paragraph 6(5) of Schedule 18")
  # stays whole
  @noun ~r/^(sections?|regulations?|articles?|rules?)\s+(.*)$/iu
  @numbered ~r/^(\d+[A-Z]*)((?:\([0-9A-Za-z]+\))*)$/u
  @bracketed ~r/^(?:\([0-9A-Za-z]+\))+$/u

  # (by noun first: a Schedule's "paragraphs 4(3) and 9(3) of Schedule 1"
  # is one piece, never "paragraphs 4(3)" of the law)
  @next_noun ~r/\s*,\s*(?:and\s+)?(?=(?:sections?|regulations?|articles?|rules?|(?:sub-?)?paragraphs?|the)\s)|\s+and\s+(?=(?:sections?|regulations?|articles?|rules?|(?:sub-?)?paragraphs?|the)\s)/u

  @doc """
  A list of places one each ("sections 6A(2) and 40(1) and (3), and
  section 40(4)" → "section 6A(2)", "section 40(1)", "section 40(3)",
  "section 40(4)"); a group under another noun ("paragraphs 4(3) and 9(3)
  of Schedule 1") stays whole.
  """
  @spec each_place(String.t()) :: [String.t()]
  def each_place(places) do
    places
    |> String.split(@next_noun, trim: true)
    |> Enum.flat_map(fn group ->
      if group =~ @noun, do: section_places(group), else: [group]
    end)
  end

  defp section_places(group) do
    {pieces, _} =
      group
      |> String.split(~r/\s*,\s*(?:and\s+)?|\s+and\s+/u, trim: true)
      |> Enum.flat_map_reduce({nil, nil}, &place_piece/2)

    pieces
  end

  defp place_piece(piece, {_noun, number} = carried) do
    case Regex.run(@noun, piece, capture: :all_but_first) do
      [n, rest] ->
        place_piece(rest, {n |> String.downcase() |> String.trim_trailing("s"), number})

      nil ->
        numbered_piece(piece, carried)
    end
  end

  defp numbered_piece(piece, {nil, _}), do: {[piece], {nil, nil}}

  # (carried: the noun and the last place's number and brackets)
  defp numbered_piece(piece, {noun, _last} = carried) do
    case Regex.run(@numbered, piece, capture: :all_but_first) do
      [n, bs] -> {["#{noun} #{piece}"], {noun, {n, brackets(bs)}}}
      nil -> other_piece(piece, carried)
    end
  end

  # a bare bracket is a sibling at its own level: "29(9)(f), (g)" is 29(9)(g),
  # "109(3)(b), (4)(b)" 109(4)(b), "2(1)(a), (2)" 2(2) (once read as 29(g),
  # and 109(3) whole: 2007 c.11 Sch.27, SSI 2025/165 Sch.21; yield, 2026-11-27)
  defp other_piece(piece, {noun, last} = carried) do
    cond do
      last != nil and piece =~ @bracketed ->
        sibling(piece, noun, last)

      noun != nil and piece =~ ~r/^\d+[A-Z]*\s+to\s+\d+[A-Z]*$/u ->
        {["#{noun}s #{piece}"], carried}

      true ->
        {[piece], {nil, nil}}
    end
  end

  defp sibling(piece, noun, {n, above}) do
    own = brackets(piece)
    kept = Enum.take_while(above, &(level(&1, above) < level(hd(own), above)))
    {["#{noun} #{n}#{Enum.map_join(kept ++ own, &"(#{&1})")}"], {noun, {n, kept ++ own}}}
  end

  defp brackets(bs),
    do: for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/u, bs, capture: :all_but_first), do: b)

  # a bracket's level: a number (1, 4A), a letter (a, ea), a roman numeral
  # (i, iv — "i" a letter only where no letter is above it), a capital
  defp level(b, above) do
    cond do
      b =~ ~r/^\d/ ->
        1

      b =~ ~r/^[ivxl]+$/ and Enum.any?(above, &(&1 =~ ~r/^[a-z]+$/ and not (&1 =~ ~r/^[ivxl]+$/))) ->
        3

      b =~ ~r/^[a-z]+$/ ->
        2

      true ->
        4
    end
  end

  # an item's sibling places one each ("section 40(4A)(b) and (5B)(d) of the
  # … Act 2000": s.40(4A)(b) and s.40(5B)(d) of it), so no clause cut at its
  # "and" leaves a place without its law
  # (numbered siblings too: "Articles 21(4) and 22(1) of the … Order 1989",
  # 2001 c.16 Sch.2 para.13(2)(b); a bare bracket at its own level)
  @place_of_law ~r/^((?:sections?|regulations?|articles?|rules?)\s+\d.*?)(\s+of\s+(?:the|that)\s+.*)$/iu
  defp siblings(place) do
    case Regex.run(@place_of_law, place, capture: :all_but_first) do
      [places, law] ->
        if places =~ ~r/,|\band\b/u, do: Enum.map(each_place(places), &(&1 <> law)), else: [place]

      nil ->
        [place]
    end
  end

  # each clause of the verb with the item's place ("omit …, in regulation
  # 2(1) of … 1997 and for … substitute, in regulation 2(1) of … 1997"): the
  # reader takes a law's part clause by clause
  defp placed(clauses, item), do: Enum.map_join(clauses, " and ", &"#{&1}, in #{item}")

  # the lead's verb: the words after its pointer (a block quote leaves its
  # stop behind: "substitute— ."); nil where the words open with no pointer
  defp lead_verb(words) do
    case Regex.run(@lead_words, words, return: :index) do
      [{0, len}] ->
        # (its caption aside: "(but subject to any specific amendments made
        # by or under this Act)—", 2013 c.22 Sch.9 para.52(1))
        words
        |> binary_part(len, byte_size(words) - len)
        |> String.replace(@caption, "")
        |> String.replace(~r/^[\s,]+|[\s.—–:]+$/u, "")

      _ ->
        nil
    end
  end

  # (a lead with no verb of its own, its paragraphs holding them, stays as
  # it is: each paragraph is read per item, `under_lead/3`)
  # (its pointer's bracket dropped: "sub-paragraph (2)" is no place, 2013
  # c.22 Sch.9 para.52(1) had read s.1183 as s.1183(2))
  defp per_law(words, items) do
    case lead_verb(words) do
      nil -> words
      "" -> Regex.replace(@in_sub, words, "provisions listed")
      verb -> per_item(verb, items)
    end
  end

  # (no "listed below": each item's place is its own, never crossed with
  # the others' brackets)
  defp per_item(verb, items) do
    clauses = String.split(verb, ~r/\s+and\s+(?=(?:for|omit|after|before|insert|at|in)\b)/u)
    Enum.map_join(items, "; ", &placed(clauses, &1))
  end

  defp schedule_list(doc, words, [_, n]) do
    list = "schedule-" <> String.downcase(n)

    case Doc.element(doc, list) do
      nil ->
        words

      el ->
        case table_items(el) do
          [] -> with_items(words, @in_schedule, item_words(doc, list))
          rows -> with_items(words, @in_schedule, rows)
        end
    end
  end

  defp with_items(words, pointer, items),
    do: Regex.replace(pointer, words, @below) <> " " <> (items |> Enum.join("; ") |> places())

  defp item_words(doc, list),
    do: for(id <- [list | descendants(doc, list)], w = Text.words_of(doc, id), w != "", do: w)

  # every id under the list's, in document order ("schedule-1-paragraph-1",
  # "schedule-1-part-1-paragraph-2": the id map's children skip the
  # "paragraph" segment)
  defp descendants(doc, id), do: Enum.filter(doc.ids, &String.starts_with?(&1, id <> "-"))

  # a "Regulation | Provision" table's rows as places: "regulation 11(7)",
  # the number carried down from the row above when left empty
  defp table_items(el) do
    rows =
      for tr <- xpath(el, ~x".//*[local-name()='tr']"l),
          do: Enum.map(xpath(tr, ~x"./*[local-name()='td' or local-name()='th']"l), &cell/1)

    case Enum.drop_while(rows, &(not header?(&1))) do
      [[word | _] | body] -> carry(body, word |> String.downcase() |> String.trim_trailing("s"))
      _ -> []
    end
  end

  defp cell(td), do: td |> Doc.text() |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp header?([a, b | _]),
    do: a =~ ~r/^(?:Regulations?|Sections?|Articles?|Rules?)$/i and b =~ ~r/^Provisions?$/i

  defp header?(_row), do: false

  defp carry(body, word) do
    {items, _} =
      Enum.flat_map_reduce(body, nil, fn
        [n, p | _], above ->
          n = if n == "", do: above, else: n
          brackets = p |> String.split(~r/\s+/, trim: true) |> Enum.join(" and ")
          if n, do: {["#{word} #{n}#{brackets}"], n}, else: {[], above}

        _row, above ->
          {[], above}
      end)

    items
  end

  # a list's items as places: captions dropped, "in section 1, subsections
  # (1) and (3A)" as "section 1(1) and (3A)"
  defp places(words) do
    words
    |> String.replace(~r/\s*\((?=[^()]*\s)[^()]*\)/u, "")
    |> String.replace(~r/\bin\s+(?=(?:sections?|regulations?|articles?|rules?)\s+\d)/iu, "")
    |> String.replace(
      ~r/\b(sections?|regulations?|articles?|rules?)\s+(\d+[A-Z]*),?\s+(?:sub-?sections?|paragraphs?)\s+\(/iu,
      "\\1 \\2("
    )
  end
end
