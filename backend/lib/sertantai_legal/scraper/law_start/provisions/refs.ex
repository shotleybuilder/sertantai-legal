defmodule SertantaiLegal.Scraper.LawStart.Provisions.Refs do
  @moduledoc """
  The law's own provisions a sentence names, as row refs: inward and outward words, Parts and Schedules of this law, a provision's children, a dash's items. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{ItemSubject, ListItems, NumberWords}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Mentioned, RefLists, Words}

  # (", and" one separator: "regulations 2(a), (c) to (f) and (h), and
  # 4(b)" — SI 2004/3386 reg.1, CV-S08 round 1)
  # (two bracketed items with only a space between are two: "20(2)
  # 28(8)(a)(ii)", SI 2013/3113 reg.1(4)'s list missing a comma)
  # ("or" names each too: "appointments under regulation 5 or 11", SI
  # 2020/1095 reg.1(2)(a))
  @noun ~r/\b(sections?|regulations?|articles?|rules?)\s+((?:(?:\s*(?:,\s*and|,\s*or|,|and|or|to|–|-)\s*|(?<=\))\s+(?=\d+[A-Z]*\())?(?:\d+[A-Z]*(?:\([^)]+\))*|\([^)]+\)(?:\([^)]+\))*))+)/i

  # (never a Schedule's Part: "Part III of Schedule 16 and, in Part IX of
  # that Schedule" — EPA 1990 s.164(2), CV-S04 round 4)
  # (", and" joins a list too: "Parts II, III, and V to VIII", 1963 c.33
  # s.94(2))
  @part ~r/(?<![Ii]n\s)\bParts?\s+((?>(?:(?:\s*(?:,\s*and|,|and|to)\s*)?[0-9]+[A-Z]?|(?:\s*(?:,\s*and|,|and|to)\s*)?[IVXL]+[A-Z]?)+))\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)/

  @this ~r/\bthis\s+(?:section|article|regulation|rule)\b/i

  @this_part ~r/\bthis\s+Part\b/i

  # ("Chapters II and III of Part I": each, CROW 2000 s.103(2))
  @chapter_of_part ~r/\bChapters?\s+((?>(?:(?:\s*(?:,|and|to)\s*)?(?:[0-9]+|[IVXL]+)[A-Z]?)+))\s+of\s+Part\s+(\w+)\b/

  # (another Act's Part is that Act's too: "Part 3 of the Regulatory Enforcement
  # and Sanctions Act 2008", 2010 c.29 s.49(3)(f); a title with an apostrophe:
  # "the Magistrates’ Courts Act 1980", 1988 c.33 s.171(5))
  # (with its Schedule: "sections 171 and 368 of and Schedule 1 to the Criminal
  # Procedure (Scotland) Act 1975", 1988 c.33 s.171(5))
  @other_provisions ~r/\b(?:(?:sub-?)?sections?|regulations?|paragraphs?|articles?|Parts?|Chapters?)\s+[\w()]+(?:\s*(?:,|and|or|to|–|-)\s*[\w()]+)*\s+of\s+(?:and\s+Schedules?\s+\w+(?:\s*(?:,|and|to)\s*\w+)*\s+to\s+)?the\s+(?:\(?[A-Z][\w()'’,.-]*\s+|(?:and|of|the|for|in|on|etc\.?)\s+){1,16}(?:Act|Order|Regulations|Measure)\s+\d{4}(?:\s*\([^)]*\))?/u

  # a repeal entry naming another Act ("the repeals to the Greater London
  # Council (General Powers) Act 1982 (c i)": 2005 c.16 s.108(4)(a))
  @repeal_of_law ~r/\b(?:the\s+)?repeals?\s+(?:to|of|in)\s+the\s+(?:\(?[A-Z][\w()'’,.-]*\s+|(?:and|of|the|for|in|on|etc\.?)\s+){1,16}(?:Act|Order|Regulations|Measure)\s+\d{4}(?:\s*\([^)]*\))?/u

  @that_act ~r/\b(?:to|of)\s+that\s+(?:Act|Order|Regulations|Measure)\b/

  # another Act's Schedule, named with its title and year ("Schedule 3 to
  # the Criminal Justice Act 1967": 1988 c.33 s.171(6)); "Schedule 3 to this
  # Act" is the law's own. The Part or paragraph of it named goes with it
  # ("Part 1 of Schedule 5 to the Agriculture Act 2020": asc 2023/4
  # s.56(3)(b))
  # (so too an Act named by its year: "Paragraph 24 of Schedule 22 to the 2020
  # Act", SI 2022/500 reg.4)
  @other_schedules ~r/\b(?:(?:Parts?|paragraphs?)\s+[\w()]+(?:\s*(?:,|and|or|to)\s*[\w()]+)*\s+of\s+)?Schedules?\s+\d+[A-Z]*(?:\s*(?:,|and|or|to)\s*\d+[A-Z]*)*\s+to\s+the\s+(?:\d{4}\s+(?:Act|Order|Regulations|Measure)\b|(?:\(?[A-Z][\w()'’,.-]*\s+|(?:and|of|the|for|in|on|etc\.?)\s+){1,16}(?:Act|Order|Regulations|Measure)\s+\d{4}(?:\s*\([^)]*\))?)/u

  @other_law ~r/\bof\s+(?:the|that)\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,12}(?:Act|Order|Regulations|Measure)\b/

  @doc "A subject and its \"except …\" (`ListItems.split_except/1`)."
  @spec split_except(String.t()) :: {String.t(), String.t()}
  def split_except(subject), do: ListItems.split_except(subject)

  @doc """
  The law's own provisions `text` names, bare ("reg.7", "pt.II"), as this
  reader names them over `rows` from the provision `base` — for checks that
  must name refs the same way (`Commencement.Leftovers`).
  """
  @spec refs_in(String.t(), [map()], String.t()) :: [String.t()]
  def refs_in(text, rows, base),
    do: text |> refs(rows, base) |> Enum.map(&(&1 |> String.split(":", parts: 2) |> List.last()))

  # the references a subject names, as section_id prefixes or containers
  @doc "The law's own refs a subject names, bare of weights."
  @spec refs(String.t(), [map()], String.t()) :: [String.t()]
  def refs(subject, rows, base),
    do: subject |> weighted_refs(rows, base) |> Enum.map(&elem(&1, 0))

  # each reference with its specificity: a named provision's is its length;
  # a Part's or Chapter's rows weigh 0, so a provision another sentence
  # names wins over its Part ("Part 7 …" vs "Regulation 73 … 2030")
  @doc "The law's own refs a subject names, each with its weight."
  @spec weighted_refs(String.t(), [map()], String.t(), boolean()) :: [{String.t(), integer()}]
  def weighted_refs(subject, rows, base, follow? \\ true) do
    # another law's provisions ("section 3 of the 2022 Act") are never this
    # law's rows; an item naming them beside its own keeps its own ("section
    # 40 and, in Part 4 of Schedule 5, the repeal to section 33 of the
    # Environmental Protection Act 1990": 2005 c.16 s.108(4)(f))
    # (an item still naming another Act after that, "paragraph 12 of Schedule
    # 1A to that Act", stays another law's: 1986 c.50 s.88(5))
    # (numbers in words as digits: "Section forty-one of this Act", 1962
    # c.58 s.70(3))
    # (a bracket apart from its number is still its number's: "11(1) (a) and
    # (5)", NISR 2008/231 reg.1(4))
    subject =
      subject
      |> NumberWords.digits()
      |> String.replace(~r/(?<=\d\(\w\)|\d\(\w\w\))\s+(?=\(\w{1,3}\))/, "")
      |> String.replace(@other_provisions, "")
      |> String.replace(@other_schedules, "")
      |> String.replace(@repeal_of_law, "")
      |> Mentioned.schedule_part_first()
      |> inward(rows, base)

    if other_law?(subject),
      do: subject |> ItemSubject.words() |> item_own_refs(rows, base, follow?),
      else: own_refs(subject, rows, base, follow?)
  end

  defp other_law?(subject), do: subject =~ @other_law or subject =~ @that_act

  # another law named only in an item's description or qualifier leaves
  # the item's own provisions the law's (`LawStart.ItemSubject`:
  # "regulation 4(c) (amendment of regulation 17A of the 2008
  # Regulations: …)", SI 2025/662 reg.1(2)); one named among the
  # provisions themselves keeps them that law's
  defp item_own_refs("", _rows, _base, _follow?), do: []

  defp item_own_refs(own, rows, base, follow?),
    do: if(other_law?(own), do: [], else: own_refs(own, rows, base, follow?))

  # a provision named outwards, from its sub-paragraph to its regulation, is
  # that sub-paragraph, never the whole regulation: "Sub-paragraph (a) of
  # paragraph (1) of regulation 9" is regulation 9(1)(a) (NISR 2008/231
  # reg.1(6)); "subsection (2) of section 5", section 5(2)
  @outward ~r/\b(?:sub-?paragraphs?\s+(\(\w{1,4}\))\s+of\s+)?(?:paragraph|subsection)\s+(\(\w{1,4}\))\s+of\s+(regulation|section|article|rule)\s+(\d+[A-Z]*)\b(?!\()/i

  # several at once: "paragraphs (4) and (5) of regulation 29" is
  # regulation 29(4) and (5) (NISR 2002/331 reg.1(4))
  @outward_list ~r/\b(?:paragraphs|subsections)\s+(\(\w{1,4}\)(?:\s*(?:,\s*and|,|and|or|to)\s*\(\w{1,4}\))+)\s+of\s+(regulation|section|article|rule)\s+(\d+[A-Z]*)\b(?!\()/i

  # (where the law holds it; else the regulation stays named)
  defp inward(subject, rows, base) do
    prefix = base |> Words.provision() |> String.split(".", parts: 2) |> hd()

    subject =
      Regex.replace(@outward_list, subject, fn whole, list, noun, n ->
        [first | _] = Regex.run(~r/\(\w{1,4}\)/, list)

        if Enum.any?(rows, &covers?("#{prefix}.#{n}#{first}", &1.section_id)),
          do: "#{noun}s #{n}#{String.replace(list, ~r/\s+/, " ")}",
          else: whole
      end)

    Regex.replace(@outward, subject, fn whole, sub, para, noun, n ->
      id = "#{prefix}.#{n}#{para}#{sub}"

      if Enum.any?(rows, &covers?(id, &1.section_id)),
        do: "#{noun} #{n}#{para}#{sub}",
        else: whole
    end)
  end

  # Parts and Chapters as the law's own ids ("UK_x:pt.II", "UK_x:pt.6.ch.1")
  # `follow?`: whether "the provisions mentioned in subsection (3)" is read
  # into that subsection — once, never from within it (a subsection naming
  # itself would loop: Petroleum Act 1998 s.52)
  defp own_refs(subject, rows, base, follow?) do
    law = base |> String.split(":", parts: 2) |> hd()
    # a provision's description in brackets names no Part or Chapter of its
    # own ("section 114(1) (power to make transitional provision in relation
    # to Part 3)": Energy Act 2013 s.156(3), CV-S08 round 2); an aside
    # breaks no list ("sections 117(7) (and section 117(6) …), 158, 167":
    # SOCPA 2005 s.178(1)(a))
    plain =
      Regex.replace(~r/\s\((?=(?:[^()]|\([^()]*\))*\s)(?:[^()]|\([^()]*\))*\)/u, subject, "")

    prefix = base |> Words.provision() |> String.split(".", parts: 2) |> hd()
    held = MapSet.new(rows, & &1.section_id)

    this = if Regex.match?(@this, subject), do: [Words.provision(base)], else: []

    this_part = this_part_refs(subject, rows, base, law)

    nouns =
      for s <- Enum.uniq([subject, plain]),
          [_, _noun, list] <- Regex.scan(@noun, s),
          ref <- RefLists.list_refs(list, prefix, rows),
          uniq: true,
          do: ref

    # "Chapter 1 of Part 6": that Chapter only; else a Part
    chapters =
      for [_, list, p] <- Regex.scan(@chapter_of_part, plain),
          c <- RefLists.part_list(list),
          r <- rows,
          RefLists.same_part?(Map.get(r, :part), p),
          RefLists.same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    own_part = own_part(rows, base)

    lone_chapters =
      for [_, c] <- Regex.scan(~r/\bChapters?\s+(\w+)\b(?!\s+of\s+Part)/, plain),
          own_part != nil,
          r <- rows,
          RefLists.same_part?(Map.get(r, :part), own_part),
          RefLists.same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    chapters = Enum.uniq(chapters ++ lone_chapters)

    # (never in an item "in Schedule 15, Part III and Part V(1) and (5)":
    # that Schedule's Parts — Access to Justice Act 1999 s.108(3)(f))
    parts =
      for [_, list] <- Regex.scan(@part, Regex.replace(@chapter_of_part, plain, "")),
          not Regex.match?(~r/^\W*in\s+Schedule\s+\d+[A-Z]*\s*,/i, subject),
          p <- RefLists.part_list(list),
          r <- rows,
          RefLists.same_part?(Map.get(r, :part), p),
          do: "#{law}:pt.#{r.part}"

    # "paragraph (4)" / "subsection (6)" alone: within the clause's provision
    # ("the condition in subsection (5)", "a provision … to which subsection
    # (2) applies", "referred to in paragraph (3)": a condition or a
    # description, not what comes into force — CR-06, 2020/7 s.87(4))
    relative =
      for [_, b] <-
            Regex.scan(
              ~r/(?<!condition in |to which |referred to in |mentioned in |specified in |under |by virtue of )\b(?:paragraph|subsection)s?\s+(\([^)]+\)(?:\([^)]+\))*)(?!\s+(?:applies|apply|is met|are met))/i,
              subject
            ),
          not Regex.match?(@noun, subject),
          do: base <> b

    mentioned = Mentioned.mentioned_refs(subject, rows, base, follow?)

    # a container's ids exist by construction (its rows, or theirs)
    provisions =
      (this ++ nouns ++ relative)
      |> Enum.filter(fn ref -> Enum.any?(held, &covers?(ref, &1)) end)
      |> Enum.map(&{&1, String.length(&1)})

    schedules = every_schedule(subject, law)

    # a Schedule's provisions, as named (no LAT row holds one: CV-S04)
    schedule_refs =
      for r <-
            subject
            |> Mentioned.schedule_words()
            |> SertantaiLegal.Scraper.Commencement.TextRefs.own_schedule_refs(),
          do: {"#{law}:#{r}", String.length(r)}

    Enum.uniq_by(
      provisions ++
        mentioned ++
        schedule_refs ++ Enum.map(this_part ++ chapters ++ parts ++ schedules, &{&1, 0}),
      &elem(&1, 0)
    )
  end

  # "This Part": the clause's own Part
  defp this_part_refs(subject, rows, base, law) do
    with true <- Regex.match?(@this_part, subject),
         part when is_binary(part) <- own_part(rows, base) do
      ["#{law}:pt.#{part}"]
    else
      _ -> []
    end
  end

  # "Chapter 1 comes into force …" in a Part: that Part's Chapter (NERC
  # Act 2006 s.107(6), CV-S04)
  defp own_part(rows, base) do
    case Enum.find(rows, &(Words.provision(&1.section_id) == Words.provision(base))) do
      %{part: part} when is_binary(part) -> part
      _ -> nil
    end
  end

  # "… and the Schedules": every Schedule (no LAT row holds one: kept as
  # the container `sch`, CV-S04); never "paragraphs of the Schedule", a
  # subset, nor "the Schedule entitled Schedule 1C", one (PMCA 1994
  # s.94(3), CV-S04 round 2)
  @every_schedule ~r/(?<!of\s)\bthe\s+Schedules?\b(?!\s+entitled)(?!,?\s+(?:to|of)\s+(?:the|that)\b)/i

  defp every_schedule(subject, law),
    do: if(subject =~ @every_schedule, do: ["#{law}:sch"], else: [])

  # a reference covers itself and the rows under it
  defp covers?(ref, sid), do: sid == ref or String.starts_with?(sid, ref <> "(")

  @doc "The rows under a row."
  @spec children(map(), [map()]) :: [map()]
  def children(row, rows),
    do:
      Enum.filter(
        rows,
        &(&1.section_id != row.section_id and covers?(row.section_id, &1.section_id))
      )

  # the items a dash opens: the row's lettered (or roman) items, never a
  # numbered paragraph beside them where the row holds no (1) ("These
  # Regulations come into force— (a) …; (b) …" then "(2) Any provision of
  # these Regulations amending … has the same extent …": SI 2019/74 reg.2)
  @doc "The items a row's dash opens."
  @spec dash_items(map(), [map()]) :: [map()]
  def dash_items(row, rows) do
    items = children(row, rows)
    top = for %{section_id: id} <- items, direct?(row.section_id, id), do: id
    {numbered, lettered} = Enum.split_with(top, &numbered?/1)

    if numbered != [] and lettered != [],
      do: Enum.reject(items, fn i -> Enum.any?(numbered, &covers?(&1, i.section_id)) end),
      else: items
  end

  defp direct?(parent, id), do: Regex.match?(~r/^\(\w+\)$/, String.replace_prefix(id, parent, ""))

  defp numbered?(id), do: Regex.match?(~r/\(\d+[A-Z]*\)$/, id)
end
