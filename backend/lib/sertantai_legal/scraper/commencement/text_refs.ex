defmodule SertantaiLegal.Scraper.Commencement.TextRefs do
  @moduledoc """
  The provisions a commencement text names, as refs ("sections 85 to 87"
  → "s.85..s.87", "paragraphs 4 to 10 of Schedule 3" → sch.3.para.4…): the
  ref reader the order reader (`Order`), the own-clause reader's Schedule
  lists (`LawStart.Provisions`) and the checks (`Leftovers`, `Misreads`)
  share. Its own module, so the commencement catalogue's reading reaches
  no order reading and an order fix keeps its cache (`CommencementCatalogue.Version`).
  Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Text.{Asides, ScheduleParts, Sibling}

  @doc """
  The Schedule provisions `text` names, in the law it is written in: a
  law's own commencement clause ("Part II and paragraphs 4 to 10 and 21 of
  Schedule 3", "Schedule 8, and Part II of Schedule 9", "Schedule 2 to this
  Act") — refs `sch.3.para.4`, `sch.8`, `sch.9.pt.II` (CV-S04: shared with
  `LawStart.Provisions`, which reads no Schedule rows).
  """
  @spec own_schedule_refs(String.t()) :: [String.t()]
  def own_schedule_refs(text) do
    text
    |> String.replace(~r/,?\s+to\s+th(?:is|ese)\s+(?:Act|Regulations|Order|Rules|Measure)\b/i, "")
    # "in Schedule 4, paragraphs 8, 10 and 11" → "paragraphs 8, 10 and 11 of
    # Schedule 4" (Petroleum Act 1998 s.52(3))
    |> String.replace(
      ~r/\bin\s+Schedule\s+(\d+[A-Z]*)\s*,\s*(paragraphs?\s+[\d\s,()A-Za-z]+?)(?=;|$|\s+and\s+in\b)/,
      "\\2 of Schedule \\1"
    )
    |> refs(nil)
    |> Enum.filter(&String.starts_with?(&1, "sch."))
  end

  # not the order's own Schedule ("Schedule 1 to this Order")
  @own ~S"(?!\s+to\s+th(?:is|ese)\s)"

  # ("8(1), and (3), 13": a comma before "and" — SI 1995/2950 art.3(1))
  @part ~S"(?:[IVXL]+[A-Z]?|\d+[A-Z]?)"
  @list ~S"((?:(?:\s*(?:,\s*and\b|,|and|to|–|-)\s*)?(?:\d+(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*|\([0-9A-Za-z]+\)(?:\([0-9A-Za-z]+\))*))+)"

  @doc "The Act's provisions an order's `text` names, as this reader names them (\"s.85..s.87\"): for checks (`Commencement.Leftovers`)."
  @spec refs_in(String.t()) :: [String.t()]
  def refs_in(text) do
    # (another law: "of the Health and Safety at Work etc. Act 1974"; "the
    # Act", the one commenced, has no year)
    if text =~
         ~r/\b(?:of|to|into)\s+the\s+[^,;]{0,120}?\b(?:Act|Order|Regulations|Measure)\s+\d{4}\b/,
       do: [],
       else: text |> Asides.strip() |> refs(nil)
  end

  @doc """
  The provisions `text` names, as the order reader names them ("s.85..s.87",
  "sch.3.para.4"); `sch` the Schedule the text's paragraphs are of (nil:
  none).
  """
  @spec refs(String.t(), String.t() | nil) :: [String.t()]
  def refs(text, sch) do
    {of_section, text} = text |> ScheduleParts.as_place() |> subsections_of()
    {chapters, text} = chapters_of_part(text)
    {subsections, text} = in_section(text)
    bare = bare_paragraph_refs(text)
    schedule_parts = schedule_part_refs(text)

    Enum.uniq(
      of_section ++
        section_refs(text) ++
        article_refs(text) ++
        subsections ++
        schedule_refs(text, bare, schedule_parts) ++
        Enum.map(schedule_parts, &elem(&1, 1)) ++
        chapters ++ part_refs(text, sch) ++ bare ++ paragraph_refs(text, sch)
    )
    |> Enum.reject(&(&1 =~ ~r/^s\.\(/))
  end

  @section_list ~r/\bsections?\s+#{@list}/i

  defp section_refs(text) do
    for [_, list] <- Regex.scan(@section_list, text),
        r <- list_refs(list, "s."),
        do: r
  end

  # an Order in Council's Articles, named as LAT names them: "Article 4(3)
  # of the Offshore, and Pipelines, Safety (Northern Ireland) Order 1992"
  # (NISR 1996/251) → reg.4(3); never the commencement order's own ("Subject
  # to Article 3", "Article 2 of this Order")
  @articles ~r/(?<!\bto\s)(?<!\bby\s)(?<!\bin\s)(?<!\bunder\s)\bArticles?\s+#{@list}(?!\s+(?:of|to)\s+th(?:is|ese)\s)/

  defp article_refs(text) do
    for [_, list] <- Regex.scan(@articles, text),
        r <- list_refs(list, "reg."),
        do: r
  end

  # a wrapped list's tail "… 28, 29 and 30 of Schedule 15" (its "paragraphs"
  # on the line before: SI 1991/1042): those paragraphs
  defp bare_paragraph_refs(text) do
    for [_, list, n] <-
          Regex.scan(
            ~r/(?<![Ss]ections\s)(?<![Ss]ection\s)(?<![Pp]arts\s)((?:\d+[A-Z]*(?:\([0-9A-Za-z]+\))*\s*(?:,|and)\s*)+\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s+of\s+Schedule\s+(\d+[A-Z]*)/,
            text
          ),
        not (text =~ ~r/\b(?:paragraphs?|sections?)\b/i),
        r <- list_refs(list, "sch.#{n}.para."),
        do: r
  end

  # "Part III of Schedule 4": that Part (AR-12); "Parts 1 and 3 of
  # Schedule 12": each (SI 2022/48)
  @parts_of_schedule ~r/\bParts?\s+(#{@part}(?:\s*(?:,|and)\s*#{@part})*)\s+of\s+Schedule\s+(\d+[A-Z]*)\b#{@own}/

  defp schedule_part_refs(text) do
    for [_, list, n] <-
          Regex.scan(
            @parts_of_schedule,
            text
          ),
        p <- String.split(list, ~r/\s*(?:,|and)\s*/, trim: true),
        do: {n, "sch.#{n}.pt.#{p}"}
  end

  # "in Schedule 13 to the Act, paragraphs …" is where, not what; "Schedule
  # 1 to this Order" is the order's own (AR-12: SI 1999/2830)
  @schedule_list ~r/(?<![Ii]n )\bSchedules?\s+#{@list}\b(?!\s*,?\s*paragraph)#{@own}/

  defp schedule_refs(text, bare, schedule_parts) do
    for [_, list] <-
          Regex.scan(
            @schedule_list,
            text
          ),
        not (text =~ ~r/\bparagraphs?\b[^;]*\bof\s+Schedule/i),
        bare == [],
        # "the following provisions of Schedule 22—", "the provisions in
        # Schedules 13 and 14 … specified in …", "the provisions of … Schedules
        # 15, 16 and 18 to, the 1994 Act which are specified in Schedule 3 to
        # this Order": a subset, not the Schedule
        not (text =~
               ~r/\b(?:provisions|paragraphs|entries|repeals|amendments)\s+(?:of|in|made\s+by)\s+(?:Part\s+\w+\s+of\s+)?Schedules?\b|\bSchedules?\s+[\d\s,and]+(?:to\s+the\s+Act\s+)?specified\b|\bSchedules?\s+\d+[A-Z]*\s*[—–:]|\b(?:which\s+are|as\s+are)\s+specified\s+in\b/iu),
        r <- list_refs(list, "sch."),
        r not in for({n, _} <- schedule_parts, do: "sch.#{n}"),
        do: r
  end

  # "Chapter 6 (special cases) of Part 5": that Chapter, never the whole
  # Part (WSI 2018/35 art.2(w)); the phrase is taken out of the text so its
  # "Part 5" isn't read as the Part
  @chapters_of_part ~r/(\b[Ii]n\s+)?\bChapters?\s+(#{@part}(?:\s*(?:,|and)\s*#{@part})*)\s*(?:\([^()]*\)\s*)?of\s+Part\s+(#{@part})\b(?!\s+(?:of|to)\s+(?:the\s+)?Schedule)/

  defp chapters_of_part(text) do
    for [phrase, heading, list, part] <- Regex.scan(@chapters_of_part, text),
        reduce: {[], text} do
      {refs, text} ->
        {refs ++ chapter_refs(heading, list, part), String.replace(text, phrase, " ")}
    end
  end

  # (a heading "in Chapter 1 of Part 1 (green deal)—" names where the
  # provisions listed under it are, never a provision: SI 2012/873 art.2(a))
  defp chapter_refs("", list, part),
    do: for(c <- String.split(list, ~r/\s*(?:,|and)\s*/, trim: true), do: "pt.#{part}.ch.#{c}")

  defp chapter_refs(_in, _list, _part), do: []

  # "Part I", "Parts III and IV" of the Act (not "Part II of Schedule 17";
  # "in Part II, the repeals of …" is where in a repeals Schedule; "the
  # said Part I" is the order's own, AR-15: SI 1997/3114)
  defp part_refs(text, sch) do
    for [_, list] <-
          Regex.scan(
            ~r/(?<![Ii]n )(?<!said )\bParts?\s+((?>(?:[IVXL]+[A-Z]?|\d+[A-Z]?)(?:\s*(?:,|and|to)\s*(?:[IVXL]+[A-Z]?|\d+[A-Z]?))*))\b(?!\s+(?:of|to)\s+(?:the\s+)?Schedule|\s+thereof)/,
            text
          ),
        not (text =~ ~r/\bof\s+Schedule\b/i and sch != nil),
        p <- String.split(list, ~r/\s*(?:,|and|to)\s*/, trim: true),
        do: "pt.#{p}"
  end

  @paragraphs_of_schedule ~r/\bparagraphs?\s+#{@list}\s+of\s+Schedule\s+(\d+[A-Z]*)/i

  defp paragraph_refs(text, nil) do
    for [_, list, s] <-
          Regex.scan(@paragraphs_of_schedule, text),
        r <- list_refs(list, "sch.#{s}.para."),
        do: r
  end

  @paragraph_list ~r/\bparagraphs?\s+#{@list}/i

  defp paragraph_refs(text, s) do
    for [_, list] <- Regex.scan(@paragraph_list, text),
        r <- list_refs(list, "sch.#{s}.para."),
        do: r
  end

  # "Subsections (1) to (5) of section 18", "sub-sections (2), (3) and (4)
  # of section 34": those subsections, never the section (AR-14: SI
  # 1999/2830, SI 2004/1572); the phrase is taken out of the text so its
  # "section 18" isn't read as the whole section
  @subsections_of ~r/\bsub-?sections?\s+((?:\([0-9A-Za-z]+\)\s*(?:,|and|to|–)?\s*)+)of\s+section\s+(\d+[A-Z]*)\b/i

  defp subsections_of(text) do
    for [phrase, list, n] <- Regex.scan(@subsections_of, text), reduce: {[], text} do
      {refs, t} -> {refs ++ list_refs(n <> list, "s."), String.replace(t, phrase, " ")}
    end
  end

  # "in section 61, subsection (6) and subsection (1)", "In section 196 …,
  # and subsections (5) to (7)": those subsections — the section is where
  # they are, taken out of the text so it isn't read as an item (SI
  # 2004/2528, SI 1992/1630)
  @in_section ~r/\bin\s+section\s+(\d+[A-Z]*)\s*,\s*(.*)$/is
  @subsection_list ~r/\bsub-?sections?\s+((?:\([0-9A-Za-z]+\))+(?:\s*(?:,|and|to|–)\s*(?:\([0-9A-Za-z]+\))+)*)/i

  defp in_section(text) do
    with [_, n, rest] <- Regex.run(@in_section, text),
         [_ | _] = lists <- Regex.scan(@subsection_list, rest) do
      refs = for [_, list] <- lists, r <- list_refs(n <> list, "s."), do: r
      {refs, String.replace(text, ~r/\bin\s+section\s+#{n}\s*,/i, " ", global: false)}
    else
      _ -> {[], text}
    end
  end

  # "17 to 22", "1, 3 to 6, and 10 to 14", "2(1) to (3)", "105(1)"
  @doc "A list's refs under `prefix`: \"17 to 22\", \"1, 3 to 6, and 10 to 14\", \"2(1) to (3)\", \"105(1)\"."
  @spec list_refs(String.t(), String.t()) :: [String.t()]
  def list_refs(list, prefix) do
    tokens =
      Regex.scan(
        ~r/(to|–|-(?=\s*[\d(]))|(\d+(?:[A-Z]+\d*)*)((?:\([0-9A-Za-z]+\))*)|((?:\([0-9A-Za-z]+\))+)/,
        list
      )

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, b], {acc, _last, true} when acc != [] ->
          [from | rest] = acc
          {["#{from}..#{prefix}#{n}#{b}" | rest], n <> b, false}

        [_, "", n, b], {acc, _last, _} ->
          {["#{prefix}#{n}#{b}" | acc], n <> b, false}

        # "2(1) to (3)": a bracket range within the last number; "33(1)(a)
        # and (b)": a sibling at the bracket's own depth (s.33(1)(b), CV-S04)
        # ("136(1) to (6)(a) to (e)": one range, ending at 136(6)(e) — SI
        # 2010/2317)
        [_, "", "", "", b], {[from | rest], last, true} when is_binary(last) ->
          to = Sibling.of(last, b)
          {["#{from |> String.split("..") |> hd()}..#{prefix}#{to}" | rest], to, false}

        [_, "", "", "", b], {acc, last, _} when is_binary(last) ->
          {["#{prefix}#{Sibling.of(last, b)}" | acc], Sibling.of(last, b), false}

        _, state ->
          state
      end)

    refs |> Enum.reverse() |> Enum.flat_map(&lettered/1)
  end

  # a range of lettered (or roman-numbered) paragraphs under one parent,
  # each named: "79(2)(a) to (d)" is (a), (b), (c) and (d) — LatRef orders
  # ranges by number, so a lettered range would cover none (SSI 2009/393)
  @lettered ~r/^(.*\()([a-z]+)\)\.\.(.*\()([a-z]+)\)$/

  defp lettered(ref) do
    with [_, parent, a, parent, b] <- Regex.run(@lettered, ref),
         [_ | _] = labels <- labels(a, b) do
      Enum.map(labels, &"#{parent}#{&1})")
    else
      _ -> [ref]
    end
  end

  @romans ~w(i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx)

  defp labels(a, b) do
    cond do
      a in @romans and b in @romans -> between(@romans, a, b)
      String.length(a) == 1 and String.length(b) == 1 -> between(Enum.map(?a..?z, &<<&1>>), a, b)
      true -> []
    end
  end

  defp between(labels, a, b) do
    {i, j} = {Enum.find_index(labels, &(&1 == a)), Enum.find_index(labels, &(&1 == b))}
    if i < j, do: Enum.slice(labels, i..j), else: []
  end
end
