defmodule SertantaiLegal.Scraper.LawStart.Provisions do
  @moduledoc """
  The sentences of a law's commencement provision that commence less than
  the whole law (lat-refactor LR-34), read as groups for the commencement
  ruleset (commencement-rules CR-03: `Commencement.OwnClause` writes each
  as a rule; CR-06: the evaluator, not this module, decides which rows each
  reaches). Treatments: `LawStart.provision_catalogue/0`.

  | Sentence | Treatment |
  |---|---|
  | "Regulation 12 shall come into operation on 31st May 2015" | `:provision_dated` |
  | "Sections 1 and 2 come into force on such day as … may by order appoint"; "The remaining provisions of this Act come into force on such day as …" | `:provision_by_order` |
  | "… so far as it relates to …", "in relation to Wales", "for the purposes of …" | `:provision_qualified` (a partial rule) |
  | provisions or a date the reader can't resolve | `:provision_unread` |

  "Remaining" / "other" provisions are those no sentence names, never the
  commencement provision itself (it commences with the law). References
  read: "this section", "regulations 17 to 21", "Articles 45(4)(d) and
  (5)(a) and 48", "Part II", "paragraph (4)", with "except …" / "other than
  …" subtracted; a provision noun maps to the law's own prefix (domestic SIs
  number articles as `reg.`). Schedules aren't in LAT. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{Clause, ScheduleTable}

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i
  @remaining ~r/\b(?:remaining provisions|remainder|the rest of this|other provisions|all (?:other )?(?:provisions|regulations|articles|sections|rules)|provisions of this \w+(?: \([^)]*\))?,? except|preceding (?:provisions|Parts|sections|regulations|articles)|^\s*(?:\(\w+\)\s*)?otherwise\b|^\s*(?:\(\w+\)\s*)?(?:Subject to [^,]+,\s*)?the provisions of this)/i
  # a general clause left open for its list ("… come into force as follows—",
  # "… on the following dates—", "… come into force—")
  @open_clause ~r/into\s+(?:force|operation)\s*(?:as follows|on the following dates?)?\s*[—–:-]?\s*$/iu
  @except ~r/,?\s*\b(?:except|other than|with the exception of)\b/i
  # (", and" one separator: "regulations 2(a), (c) to (f) and (h), and
  # 4(b)" — SI 2004/3386 reg.1, CV-S08 round 1)
  @noun ~r/\b(sections?|regulations?|articles?|rules?)\s+((?:(?:\s*(?:,\s*and|,|and|to|–|-)\s*)?(?:\d+[A-Z]*(?:\([^)]+\))*|\([^)]+\)(?:\([^)]+\))*))+)/i
  # (never a Schedule's Part: "Part III of Schedule 16 and, in Part IX of
  # that Schedule" — EPA 1990 s.164(2), CV-S04 round 4)
  @part ~r/(?<![Ii]n\s)\bParts?\s+((?>(?:(?:\s*(?:,|and|to)\s*)?[0-9]+[A-Z]?|(?:\s*(?:,|and|to)\s*)?[IVXL]+[A-Z]?)+))\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)/
  @this ~r/\bthis\s+(?:section|article|regulation|rule)\b/i
  @this_part ~r/\bthis\s+Part\b/i
  @chapter_of_part ~r/\bChapters?\s+(\w+)\s+of\s+Part\s+(\w+)\b/
  # a statement elsewhere names provisions first, never something under them
  # ("… a partial restriction notice served under section 183 above by a
  # notice … which shall come into force": Building Societies Act 1986
  # s.186(1))
  @provisions_subject ~r/^(?:\(\w+\)\s*)?(?:(?:Subject\s+to|Except|Apart\s+from|Other\s+than|Save|In\s+(?:Part|Schedule)\s+\w+)[^,]{0,200},\s*)?(?:the\s+)?(?:sections?|regulations?|articles?|rules?|paragraphs?|sub-?sections?|sub-?paragraphs?|Parts?|Chapters?|Schedules?|this|these|following|remaining|preceding|other|rest|provisions?|repeals?|amendments?)\b/i

  @this_only ~r/^(?:\(\w+\)\s*)?This\s+(?:section|regulation|article|rule)\s+(?:shall\s+)?(?:comes?|came)\s+into/i
  @other_law ~r/\bof\s+(?:the|that)\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,12}(?:Act|Order|Regulations|Measure)\b/

  @doc """
  The provision-level sentences of a law's commencement clause as groups,
  their references unexpanded (commencement-rules CR-03: a rule's scope):
  `kind` (`:named` | `:remaining` | `:unread`), `refs` (provisions as
  section_id prefixes; Parts and Chapters as the law's own ids, "UK_x:pt.II",
  "UK_x:pt.6.ch.1"), `excluded`, `treatment`, `date`, `qualified_date` (a
  qualified sentence's date: a partial rule's, CR-03),
  `evidence`, `text`.
  """
  @spec groups([map()], Date.t() | nil, LawStart.t()) :: [map()]
  def groups(rows, made, %LawStart{} = law) do
    clause = if clause?(law), do: provision(law.evidence)

    # a law left to orders reads its clause's other sentences too ("Subject
    # to subsections (2) and (3), this Act is to come into force on such day
    # as …": LGRA 1997 s.34, CV-S04)
    clause_groups =
      if clause,
        do: clause_groups(rows, made, law.evidence, whole_clause(law), law.date),
        else: []

    for g <- clause_groups ++ elsewhere(rows, made, clause, law.date),
        do: %{g | refs: Enum.map(g.refs, &elem(&1, 0))}
  end

  defp clause?(%LawStart{evidence: e}), do: is_binary(e) and String.contains?(e, ":")

  @doc """
  The provisions a general clause leaves out — inline ("This Act, apart
  from sections 7 and 8 and this section, shall come into force …": Police
  (Health and Safety) Act 1997 s.9(2)) or in a list below it ("This Act,
  except— (a) this section; (b) sections 8(2), 11(1) to (5), 12 and 13; …":
  Gas Act 1995 s.18(2)) — as refs (CV-S04 round 3). [] for none.
  """
  @spec except_refs(LawStart.t(), [map()]) :: [String.t()]
  def except_refs(%LawStart{evidence: evidence, text: text}, rows)
      when is_binary(evidence) and is_binary(text) do
    base = provision(evidence)
    row = Enum.find(rows, &(&1.section_id == evidence))

    source =
      cond do
        text =~ ~r/(?:except|apart\s+from|other\s+than)\s*[—–]/u and row != nil ->
          row |> children(rows) |> Enum.map_join("; ", &(&1.text || ""))

        m =
            Regex.run(
              ~r/(?:,\s*|\(\s*)(?:except|apart\s+from|other\s+than)\s+([^—–()]+?)\s*(?:,|\))\s*(?:shall|comes?|is\s+to|are\s+to|does|do)\b/iu,
              text
            ) ->
          Enum.at(m, 1)

        # "Except for section 26 and this section the provisions of this Act
        # shall not come into force until …" (Road Traffic (Driver
        # Licensing) Act 1988-like, ukpga 1988/45)
        m =
            Regex.run(
              ~r/^\W*(?:\(\w+\)\s*)?(?:except\s+for|apart\s+from|other\s+than)\s+(.+?),?\s+(?:the\s+provisions\s+of\s+)?this\s+(?:Act|Measure)\b/iu,
              text
            ) ->
          Enum.at(m, 1)

        true ->
          ""
      end

    source
    |> String.split(~r/;\s*/, trim: true)
    |> Enum.reject(&Regex.match?(@qualified, &1))
    |> Enum.flat_map(&weighted_refs(&1, rows, base))
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
  end

  def except_refs(_law, _rows), do: []

  # statements in other provisions ("Section 6 and Schedules 2 and 3 shall
  # not come into force until such day as …": Access to Justice Act 1999
  # s.7(3); "Part 1 … comes into force in accordance with provision made by
  # order": NERC Act 2006 s.107(1)), each read in its own provision: never a
  # mention, another law's provisions, a general clause (the law's start is
  # LawStart's) or "this section" alone (OwnClause reads a provision's own
  # words) — CV-S04
  defp elsewhere(rows, made, clause, start) do
    for row <- rows,
        provision(row.section_id) != clause,
        s <- sentences(row),
        Regex.match?(@cif, s),
        not Clause.mention?(s),
        not Clause.general?(s),
        Regex.match?(@provisions_subject, s),
        not Regex.match?(@this_only, s),
        g <- clause_sentence_groups(s, row, rows, made, provision(row.section_id), start),
        g.kind != :unread,
        do: g
  end

  @doc """
  The groups of a clause commencing by its Schedule's table (V1-02,
  `LawStart.ScheduleTable`): one per table row, its provisions dated in
  full when its purpose is all ("All purposes", "In respect of all
  buildings") and the provision carries no qualifier of its own ("Regulation
  17 (for the purpose of new regulation 25A)"); else partial.
  """
  @spec table_groups([map()], LawStart.t(), map() | nil) :: [map()]
  def table_groups(rows, %LawStart{evidence: evidence, text: text}, tables)
      when is_binary(evidence) and is_map(tables) do
    base = provision(evidence)

    for %{date: date, provisions: p, purpose: purpose} <- ScheduleTable.rows(text, tables),
        {qualified, refs} = cell_refs(p, rows, base),
        g <- [
          table_group(refs -- qualified, all_purposes?(purpose), date, evidence, p, purpose),
          table_group(qualified, false, date, evidence, p, purpose)
        ],
        g != nil,
        do: g
  end

  def table_groups(_rows, _law, _tables), do: []

  defp all_purposes?(purpose), do: purpose == nil or purpose =~ ~r/\ball\b/i

  defp table_group([], _full?, _date, _evidence, _p, _purpose), do: nil

  defp table_group(refs, full?, date, evidence, p, purpose),
    do: %{
      kind: :named,
      refs: refs,
      excluded: [],
      treatment: if(full?, do: :provision_dated, else: :provision_qualified),
      date: if(full?, do: date, else: nil),
      qualified_date: if(full?, do: nil, else: date),
      evidence: evidence,
      text: Enum.join(Enum.reject([p, purpose], &is_nil/1), " | ")
    }

  # a cell's refs, and those an item qualifies in brackets of its own:
  # "Regulations 1-10, 11(a) (in so far as it inserts …) and (b), 12" — only
  # 11(a) is partial; items split at commas and "and" outside brackets, a
  # bare number taking the cell's provision noun
  defp cell_refs(p, rows, base) do
    noun =
      case Regex.run(~r/^\s*(regulations?|sections?|articles?|rules?)\b/i, p) do
        [_, n] -> n
        nil -> ""
      end

    qualified =
      p
      |> split_items()
      |> Enum.filter(&qualified_provision?/1)
      |> Enum.flat_map(fn item ->
        item = strip_qualifier(item)
        item = if item =~ ~r/^\s*\d/, do: noun <> " " <> item, else: item
        refs(item, rows, base)
      end)

    {qualified, refs(strip_qualifier(p), rows, base)}
  end

  defp split_items(p) do
    {items, cur, _depth} =
      p
      |> String.graphemes()
      |> Enum.reduce({[], "", 0}, fn
        "(", {items, cur, d} -> {items, cur <> "(", d + 1}
        ")", {items, cur, d} -> {items, cur <> ")", max(d - 1, 0)}
        ",", {items, cur, 0} -> {[cur | items], "", 0}
        c, {items, cur, d} -> {items, cur <> c, d}
      end)

    [cur | items]
    |> Enum.reverse()
    |> Enum.flat_map(&String.split(&1, ~r/\s+and\s+(?![^()]*\))/))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # a provision's own qualifier in brackets ("(for the purpose of new
  # regulation 25A)", "(in so far as it inserts …)"); "(so far as not
  # otherwise commenced)" completes it
  defp qualified_provision?(p),
    do:
      p =~ ~r/\((?:for the purposes? of|in so far as|so far as|insofar as)\b/i and
        not (p =~ ~r/\(\s*(?:in )?so far as not (?:otherwise|already)\b/i)

  # bracketed asides with words in them are qualifiers, not numbers ("and
  # (b)" stays)
  # ("13(a) (in so far as it inserts paragraphs (3B) … into regulation 20) and (b)")
  defp strip_qualifier(p),
    do: Regex.replace(~r/\s\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/, p, "")

  defp clause_groups(rows, made, evidence, clause, start) do
    base = provision(evidence)
    held = rows |> Enum.filter(&(provision(&1.section_id) == base))
    clause = squash(clause)

    # never the sentence the law's start was read from ("they come into
    # force …", a list item "come into force …": V1-02) — but its own
    # exception, dated ("…, except regulation 20(4) which shall come into
    # operation on 6th April 2007": CV-S04)
    for row <- held,
        s <- sentences(row),
        Regex.match?(@cif, s),
        not Clause.mention?(s),
        g <-
          if(squash(s) == clause,
            do: except_which(s, row, rows, made, base),
            else: clause_sentence_groups(s, row, rows, made, base, start)
          ),
        do: g
  end

  @except_which [
    ~r/\bexcept\s+(.+?)\s+which\s+shall\s+(?:come|be\s+brought)\s+into\s+(?:force|operation)\s+(.+?)\.?$/i,
    # "… except for this section, section 74 above and paragraphs 76(8)(a)
    # and 135 of Schedule 22 to this Act (which come into force on the
    # passing of this Act) …" (EA 1995 s.125(3))
    ~r/\bexcept\s+for\s+(.+?)\s*\(which\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+([^)]+)\)/i,
    # "This Act (except the provisions listed in subsection (3), which come
    # into force on the passing of this Act) shall come into force on such
    # day as …" (Communications Act 2003 s.411(2))
    ~r/\(except\s+((?:[^()]|\([^()]*\))+?),\s*which\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+((?:[^()]|\([^()]*\))+)\)/i,
    # "Subsection (1) above does not apply to section 195 which shall come
    # into force when this Act is passed" (Building Societies Act 1986
    # s.211(2)); "… save that regulations 9 and 12(1)(b) shall come into
    # force on 1st April 1994" (SI 1988/1729): CV-S04
    ~r/\bdoes\s+not\s+apply\s+to\s+(.+?),?\s+which\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)\.?$/i,
    ~r/\bsave\s+that\s+(.+?)\s+shall\s+come\s+into\s+(?:force|operation)\s+(.+?)[;.]?$/i
  ]

  defp except_which(s, row, rows, made, base) do
    with [_, subject, tail] <- Enum.find_value(@except_which, &Regex.run(&1, s)),
         [_ | _] = refs <- weighted_refs(subject, rows, base),
         {:provision_dated, %Date{} = d} <- tail_treatment(tail, made) do
      [
        %{
          kind: :named,
          refs: refs,
          excluded: [],
          treatment: :provision_dated,
          date: d,
          qualified_date: nil,
          evidence: row.section_id,
          text: s
        }
      ]
    else
      _ -> []
    end
  end

  # "… shall not come into operation [for some purposes] until <date>"
  # (NISR 2006/1 reg.1(a), (b)): the provisions it names — or, said of the
  # law ("they", "these Regulations"), the rest of it — in partly from the
  # law's start, fully from that date (CV-S04)
  @not_until ~r/^(.*?)\bshall\s+not\s+(?:come|be\s+brought)\s+into\s+(?:force|operation)\b(.*?)\buntil\s+(.+?)\s*[;.,]?\s*(?:and|or)?\s*$/is
  @the_law ~r/\b(?:they|it|these\s+(?:Regulations|Rules)|this\s+(?:Act|Order|Measure))\b/i

  defp not_until(s, row, rows, made, base, start) do
    with %Date{} <- start,
         [_, subject, _qualifier, until] <- Regex.run(@not_until, s),
         {_, %Date{} = d} <- Clause.tail_date("on " <> String.trim(until), made) do
      subject = String.replace(subject, ~r/^\s*(?:\(\w+\)\s*)?subject\s+to\s+[^,]+,\s*/i, "")
      refs = weighted_refs(subject, rows, base)

      kind =
        cond do
          refs != [] -> :named
          Regex.match?(@the_law, subject) -> :remaining
          true -> nil
        end

      g = %{
        kind: kind,
        refs: refs,
        excluded: [],
        evidence: row.section_id,
        text: s
      }

      if kind,
        do: [
          Map.merge(g, %{treatment: :provision_qualified, date: nil, qualified_date: start}),
          Map.merge(g, %{treatment: :provision_dated, date: d, qualified_date: nil})
        ],
        else: []
    else
      _ -> nil
    end
  end

  # the general clause commences the whole law; its list items, each with
  # its date ("These Regulations come into force as follows— (a) Parts 1, 2
  # … on 16th April 2005; (b) the remainder, on 16th July 2005"), are read as
  # sentences of their own (V1-02)
  defp clause_sentence_groups(s, row, rows, made, base, start) do
    with nil <- not_until(s, row, rows, made, base, start),
         [] <- except_which(s, row, rows, made, base) do
      clause_sentence_groups(s, row, rows, made, base)
    end
  end

  defp clause_sentence_groups(s, row, rows, made, base) do
    cond do
      Clause.general?(s) and Regex.match?(@open_clause, s) ->
        for item <- children(row, rows),
            not Regex.match?(@cif, item.text || ""),
            {subject, tail, _date} <- [Clause.item_split(item.text, made)],
            subject != "",
            g <- groups("#{subject} come into force #{tail}", item, rows, made, base),
            do: g

      # another general sentence in the clause than the law's start: the
      # rest of the law, dated ("Other than those regulations specified in
      # paragraph (3) these Regulations come into force on 31 October 2026"
      # beside "… come into force in accordance with paragraphs (2) and (3)":
      # SSI 2025/417 reg.1(2), CV-S04)
      Clause.general?(s) ->
        general_rest(s, row, made)

      true ->
        groups(s, row, rows, made, base)
    end
  end

  # … partly where it is qualified ("for the purpose of …", "in relation to
  # any container …"); a sentence dating each country apart ("in England on
  # 1st July 2007 and in Wales on 2nd April 2007": SI 2007/764) one partial
  # group per country, the country carried (`territory`)
  @by_country ~r/\bin\s+(England|Wales|Scotland|Northern Ireland)\s+on\s+(\d{1,2}\s*(?:st|nd|rd|th)?\s+[A-Za-z]+,?\s+\d{4})/i

  defp general_rest(s, row, made) do
    rest = fn t, d, text ->
      %{
        kind: :remaining,
        refs: [],
        excluded: [],
        treatment: t,
        date: if(t == :provision_qualified, do: nil, else: d),
        qualified_date: if(t == :provision_qualified, do: d),
        evidence: row.section_id,
        text: text
      }
    end

    case Regex.scan(@by_country, s) do
      [_, _ | _] = countries ->
        for [_, place, date] <- countries,
            %Date{} = d <- [Clause.date_at_start(date)],
            do: Map.put(rest.(:provision_qualified, d, s), :territory, place)

      _ ->
        with [_subject, tail] <- Regex.split(@cif, s, parts: 2),
             {t, d} when t in [:provision_dated, :provision_by_order] <-
               tail_treatment(String.trim(tail), made) do
          t = if Regex.match?(@qualified, s), do: :provision_qualified, else: t
          [rest.(t, d, s)]
        else
          _ -> []
        end
    end
  end

  # one sentence → its groups: kind (:named | :remaining | :unread), refs,
  # excluded refs, treatment and date. A list ("The following provisions
  # come into force on …— (a) section 1; (b) section 105 in so far as …")
  # is read item by item: qualified items are their own (D2) group.
  defp groups(sentence, row, rows, made, base) do
    [subject, tail] = Regex.split(@cif, sentence, parts: 2)

    # an inline list follows "namely—" or a dash; else the rows under this one
    [tail, inline] =
      case Regex.split(~r/(?:,?\s*namely\s*)?(?:[—–]|:(?=\s))\s*/u, String.trim(tail), parts: 2) do
        [t, list] -> [t, list]
        [t] -> [t, ""]
      end

    {treatment, date} = tail_treatment(tail, made)

    list_head? =
      tail == "" and inline == "" and not (subject =~ ~r/\bthe\s+following\b/i) and
        children(row, rows) != []

    if list_head?,
      do: list_head(subject, row, rows, made, base),
      else:
        sentence_groups(sentence, subject, tail, inline, treatment, date, row, rows, made, base)
  end

  # "Section 1 comes into force— (a) on 1 January 2022 for the purpose of
  # making regulations; (b) on 1 April 2022 for all other purposes": each
  # item dates the head's provisions (UK_ukpga_2021_24 s.4(2), CV-S04)
  defp list_head(subject, row, rows, made, base) do
    for item <- children(row, rows),
        text = String.replace(item.text || "", ~r/^\(?[a-z0-9]+\)\s*/i, ""),
        text != "",
        not Regex.match?(@cif, text),
        g <- groups("#{subject} come into force #{text}", item, rows, made, base),
        do: g
  end

  defp sentence_groups(sentence, subject, tail, inline, treatment, date, row, rows, _made, base) do
    g = %{
      kind: :named,
      refs: [],
      excluded: [],
      treatment: treatment,
      date: date,
      qualified_date: nil,
      evidence: row.section_id,
      text: sentence
    }

    if subject =~ ~r/\bthe following\b/i do
      items =
        [inline | Enum.map(children(row, rows), &(&1.text || ""))]
        |> Enum.join("; ")
        |> String.split(~r/;\s*/, trim: true)

      {qualified, plain} = Enum.split_with(items, &Regex.match?(@qualified, &1))

      # each item's own "except …" ("Part 7 …, except regulation 73")
      {refs, excluded} =
        Enum.reduce(plain, {[], []}, fn item, {rs, ex} ->
          {inside, outside} = split_except(item)
          named = weighted_refs(inside, rows, base)

          {rs ++ named,
           ex ++
             refs(outside, rows, relative_base(named, base))}
        end)

      named = %{g | refs: refs, excluded: excluded}

      listed = %{
        g
        | refs: Enum.flat_map(qualified, &weighted_refs(&1, rows, base)),
          treatment: :provision_qualified,
          date: nil,
          qualified_date: date
      }

      # a list whose items are all qualified is only the qualified group
      [classify(named, subject <> " " <> tail), listed]
      |> Enum.reject(&(&1.treatment == :provision_qualified and &1.refs == []))
      |> Enum.reject(&(&1.kind == :unread and plain == [] and qualified != []))
    else
      case bracket_qualified(subject) || trailing_qualified(subject) do
        {plain, qualified} ->
          # "regulations 2, 5, 10 and 11, and, so far as they relate to …,
          # regulations 3, 6 and 7": the qualifier is only the later items'
          named = %{g | refs: weighted_refs(plain, rows, base)}

          listed = %{
            g
            | refs: weighted_refs(qualified, rows, base),
              treatment: :provision_qualified,
              date: nil,
              qualified_date: date
          }

          [classify(named, plain <> " " <> tail, plain), listed]
          |> Enum.reject(&(&1.refs == []))

        nil ->
          whole_subject(g, sentence, subject, rows, base)
      end
    end
  end

  # an item with its own qualifier in brackets: only that item is partial —
  # {the other items, the qualified item} ("This regulation, regulation 2
  # (insofar as it relates to regulation 22) and regulation 22 come into
  # force on 31st May 2015": SI 2015/21 reg.1(2), CV-S04)
  @bracket_qualifier ~r/((?:regulations?|sections?|articles?|rules?|paragraphs?)\s+\d+[A-Z]*(?:\([^)\s]+\))*)\s*\((?:in\s+so\s+far|insofar|so\s+far|for\s+the\s+purposes?\s+of|to\s+the\s+extent)\b[^)]*\)/i

  defp bracket_qualified(subject) do
    case Regex.run(@bracket_qualifier, subject, return: :index) do
      [{start, len}, {i_start, i_len}] ->
        item = binary_part(subject, i_start, i_len)

        plain =
          binary_part(subject, 0, start) <>
            binary_part(subject, start + len, byte_size(subject) - start - len)

        if Regex.match?(@qualified, plain), do: nil, else: {plain, item}

      _ ->
        nil
    end
  end

  # a subject whose qualifier covers only the items after it: {the plain
  # items, the qualified items} (CR-06: uksi 1988/819 reg.1(2); asp 2005/13
  # s.33 "Sections 33, 34, 41 and (in so far as …) 42")
  defp trailing_qualified(subject) do
    case Regex.run(
           ~r/^(.*\d.*?),?\s+and,?\s+(?:in\s+)?so\s+far\s+as\b[^,]*,\s*(.*\d.*)$/is,
           subject
         ) ||
           Regex.run(
             ~r/^(.*\d.*?),?\s+and\s+\((?:in\s+)?so\s+far\s+as\b[^)]*\)\s*(.*\d.*)$/is,
             subject
           ) do
      [_, plain, qualified] ->
        if Regex.match?(@qualified, plain), do: nil, else: {plain, qualified}

      nil ->
        nil
    end
  end

  defp whole_subject(g, sentence, subject, rows, base) do
    {subject_in, subject_out} = split_except(subject)
    refs = weighted_refs(subject_in, rows, base)

    # "Regulation 26, with the exception of paragraph (4)": relative to
    # what the subject names
    excluded =
      refs(subject_out, rows, relative_base(refs, base))

    [classify(%{g | refs: refs, excluded: excluded}, sentence, subject)]
  end

  defp classify(g, qualifiable, subject \\ "") do
    cond do
      Regex.match?(@qualified, qualifiable) ->
        %{g | treatment: :provision_qualified, date: nil, qualified_date: g.date}

      Regex.match?(@remaining, subject) and g.treatment != :provision_unread ->
        %{g | kind: :remaining}

      g.refs == [] or g.treatment == :provision_unread ->
        %{g | kind: :unread, treatment: :provision_unread, date: nil}

      true ->
        g
    end
  end

  defp tail_treatment(tail, made) do
    # "in relation to Wales on 1st October 2020": the date after the place
    # (such a sentence is qualified: a partial rule, CR-03)
    tail =
      String.replace(
        tail,
        ~r/^(?:in relation to|in|as respects)\s+(?:England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\s+(?=on\b|from\b)/i,
        ""
      )

    # "… shall come into force for all purposes on 6th April 1992" (ICTA
    # 1988 s.843(3), SSCBA 1992 s.289(2): CV-S04)
    tail = String.replace(tail, ~r/^for\s+all\s+(?:other\s+)?purposes\s+(?=on\b)/i, "")

    case Clause.tail_date(tail, made) do
      {_, %Date{} = d} ->
        {:provision_dated, d}

      _ ->
        if Clause.by_order?(tail), do: {:provision_by_order, nil}, else: {:provision_unread, nil}
    end
  end

  # what an "except …" is relative to: the first provision named, else the
  # clause's own (a Part's or Chapter's id isn't a provision: "Part 7 …,
  # except regulation 73")
  defp relative_base(named, base) do
    case named |> Enum.map(&elem(&1, 0)) |> Enum.reject(&String.contains?(&1, ":pt.")) do
      [first | _] -> first
      [] -> base
    end
  end

  defp split_except(subject) do
    case Regex.split(@except, subject, parts: 2) do
      [inside, outside] -> {inside, outside}
      [inside] -> {inside, ""}
    end
  end

  # the references a subject names, as section_id prefixes or containers
  defp refs(subject, rows, base),
    do: subject |> weighted_refs(rows, base) |> Enum.map(&elem(&1, 0))

  # each reference with its specificity: a named provision's is its length;
  # a Part's or Chapter's rows weigh 0, so a provision another sentence
  # names wins over its Part ("Part 7 …" vs "Regulation 73 … 2030")
  defp weighted_refs(subject, rows, base) do
    # another law's provisions ("section 3 of the 2022 Act") are never this
    # law's rows
    if subject =~ @other_law, do: [], else: own_refs(subject, rows, base)
  end

  # Parts and Chapters as the law's own ids ("UK_x:pt.II", "UK_x:pt.6.ch.1")
  # `follow?`: whether "the provisions mentioned in subsection (3)" is read
  # into that subsection — once, never from within it (a subsection naming
  # itself would loop: Petroleum Act 1998 s.52)
  defp own_refs(subject, rows, base, follow? \\ true) do
    law = base |> String.split(":", parts: 2) |> hd()
    # a provision's description in brackets names no Part or Chapter of its
    # own ("section 114(1) (power to make transitional provision in relation
    # to Part 3)": Energy Act 2013 s.156(3), CV-S08 round 2); an aside
    # breaks no list ("sections 117(7) (and section 117(6) …), 158, 167":
    # SOCPA 2005 s.178(1)(a))
    plain =
      Regex.replace(~r/\s\((?=(?:[^()]|\([^()]*\))*\s)(?:[^()]|\([^()]*\))*\)/u, subject, "")

    prefix = base |> provision() |> String.split(".", parts: 2) |> hd()
    held = MapSet.new(rows, & &1.section_id)

    this = if Regex.match?(@this, subject), do: [provision(base)], else: []

    # "This Part": the clause's own Part
    this_part =
      with true <- Regex.match?(@this_part, subject),
           %{part: part} when is_binary(part) <-
             Enum.find(rows, &(provision(&1.section_id) == provision(base))) do
        ["#{law}:pt.#{part}"]
      else
        _ -> []
      end

    nouns =
      for s <- Enum.uniq([subject, plain]),
          [_, _noun, list] <- Regex.scan(@noun, s),
          ref <- list_refs(list, prefix, rows),
          uniq: true,
          do: ref

    # "Chapter 1 of Part 6": that Chapter only; else a Part
    chapters =
      for [_, c, p] <- Regex.scan(@chapter_of_part, plain),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    # "Chapter 1 comes into force …" in a Part: that Part's Chapter (NERC
    # Act 2006 s.107(6), CV-S04)
    own_part =
      case Enum.find(rows, &(provision(&1.section_id) == provision(base))) do
        %{part: part} when is_binary(part) -> part
        _ -> nil
      end

    lone_chapters =
      for [_, c] <- Regex.scan(~r/\bChapters?\s+(\w+)\b(?!\s+of\s+Part)/, plain),
          own_part != nil,
          r <- rows,
          same_part?(Map.get(r, :part), own_part),
          same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    chapters = Enum.uniq(chapters ++ lone_chapters)

    # (never in an item "in Schedule 15, Part III and Part V(1) and (5)":
    # that Schedule's Parts — Access to Justice Act 1999 s.108(3)(f))
    parts =
      for [_, list] <- Regex.scan(@part, Regex.replace(@chapter_of_part, plain, "")),
          not Regex.match?(~r/^\W*in\s+Schedule\s+\d+[A-Z]*\s*,/i, subject),
          p <- part_list(list),
          r <- rows,
          same_part?(Map.get(r, :part), p),
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

    # "The provisions mentioned in subsection (3) …": those the subsection
    # lists (Competition Act 1998 s.52(2), CV-S04)
    mentioned =
      for [_, n] <-
            Regex.scan(
              ~r/\bprovisions\s+(?:mentioned|specified|listed|referred\s+to)\s+in\s+(?:sub-?section|paragraph)\s+\((\w+)\)/i,
              subject
            ),
          prefix = "#{base}(#{n})",
          r <- rows,
          follow?,
          r.section_id == prefix or String.starts_with?(r.section_id, prefix <> "("),
          ref <- own_refs(Map.get(r, :text) || "", rows, base, false),
          do: ref

    # a container's ids exist by construction (its rows, or theirs)
    provisions =
      (this ++ nouns ++ relative)
      |> Enum.filter(fn ref -> Enum.any?(held, &covers?(ref, &1)) end)
      |> Enum.map(&{&1, String.length(&1)})

    # "… and the Schedules": every Schedule (no LAT row holds one: kept as
    # the container `sch`, CV-S04)
    schedules =
      if subject =~
           ~r/(?<!of\s)\bthe\s+Schedules?\b(?!\s+entitled)(?!,?\s+(?:to|of)\s+(?:the|that)\b)/i,
         # (never "paragraphs of the Schedule", a subset; nor "the Schedule
         # entitled Schedule 1C", one: PMCA 1994 s.94(3), CV-S04 round 2)
         do: ["#{law}:sch"],
         else: []

    # a Schedule's provisions, as named (no LAT row holds one: CV-S04)
    schedule_refs =
      for r <- SertantaiLegal.Scraper.Commencement.Order.own_schedule_refs(subject),
          do: {"#{law}:#{r}", String.length(r)}

    Enum.uniq_by(
      provisions ++
        mentioned ++
        schedule_refs ++ Enum.map(this_part ++ chapters ++ parts ++ schedules, &{&1, 0}),
      &elem(&1, 0)
    )
  end

  # "45(4)(d) and (5)(a) and 48", "17 to 21", "3, 4, 17, 21 and 23"
  defp list_refs(list, prefix, rows) do
    tokens =
      Regex.scan(~r/(to|–|-(?=\s*\d))|(\d+[A-Z]*)((?:\([^)]+\))*)|((?:\([^)]+\))+)/, list)

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, brackets], {acc, _last, range?} ->
          ref = "#{prefix}.#{n}#{brackets}"

          acc =
            if range? and acc != [],
              do: acc ++ range_refs(List.last(acc), ref, rows),
              else: acc ++ [ref]

          {acc, n, false}

        # "5(1) to (4)": a bracket range within the number (Petroleum Act
        # 1998 s.52(1), CV-S04)
        [_, "", "", "", brackets], {acc, last, true} when is_binary(last) and acc != [] ->
          {acc ++ bracket_range(List.last(acc), "#{prefix}.#{last}#{brackets}"), last, false}

        [_, "", "", "", brackets], {acc, last, range?} when is_binary(last) ->
          {acc ++ ["#{prefix}.#{last}#{brackets}"], last, range?}

        _, state ->
          state
      end)

    refs
  end

  # "s.5(1)" to "s.5(4)": the members after the first, one bracket deep,
  # numbers or letters (the held rows decide which exist)
  defp bracket_range(first, last) do
    with [_, base, a] <- Regex.run(~r/^(.*)\(([0-9]+|[a-z])\)$/, first),
         [_, ^base, b] <- Regex.run(~r/^(.*)\(([0-9]+|[a-z])\)$/, last),
         {from, to} when from < to <- {ordinal(a), ordinal(b)} do
      for i <- (from + 1)..to, do: "#{base}(#{member(i, a)})"
    else
      _ -> [last]
    end
  end

  defp ordinal(<<c>>) when c in ?a..?z, do: c
  defp ordinal(n), do: String.to_integer(n)

  defp member(i, <<c>>) when c in ?a..?z, do: <<i>>
  defp member(i, _), do: Integer.to_string(i)

  # the provisions from `first` to `last` in document order
  defp range_refs(first, last, rows) do
    bases = rows |> Enum.map(&provision(&1.section_id)) |> Enum.uniq()
    from = Enum.find_index(bases, &(&1 == provision(first)))
    to = Enum.find_index(bases, &(&1 == provision(last)))

    if from && to && to >= from, do: Enum.slice(bases, (from + 1)..to//1), else: [last]
  end

  @roman ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX)

  # "1, 3 and 5", "1 to 3", "II to IV": each Part (CV-S04: DRA 2014 s.50(1))
  defp part_list(list) do
    list
    |> String.split(~r/\s*(?:,|and)\s*/, trim: true)
    |> Enum.flat_map(fn item ->
      with [a, b] <- String.split(item, ~r/\s+to\s+/),
           {i, j} when is_integer(i) and is_integer(j) and i <= j <- {number(a), number(b)} do
        Enum.map(i..j, &Integer.to_string/1)
      else
        _ -> [item]
      end
    end)
  end

  defp number(p) do
    case Integer.parse(p) do
      {i, ""} -> i
      _ -> Enum.find_index(@roman, &(&1 == String.upcase(p))) |> then(&(&1 && &1 + 1))
    end
  end

  defp same_part?(nil, _p), do: false

  defp same_part?(part, p) do
    up = String.upcase(p)
    part = String.upcase(part)
    part == up or part == roman(up) or roman(part) == up
  end

  defp roman(s) do
    case Integer.parse(s) do
      {i, ""} when i in 1..20 -> Enum.at(@roman, i - 1)
      _ -> s
    end
  end

  # a reference covers itself and the rows under it
  defp covers?(ref, sid), do: sid == ref or String.starts_with?(sid, ref <> "(")

  defp children(row, rows),
    do:
      Enum.filter(
        rows,
        &(&1.section_id != row.section_id and covers?(row.section_id, &1.section_id))
      )

  defp sentences(row), do: Clause.sentences(Map.get(row, :text) || "")

  # the law's start read from one sentence for the whole law (a dated
  # clause, a pronoun or a list item: V1-02) — a staged or own-part clause
  # is also a provision sentence
  defp whole_clause(%LawStart{treatment: t, text: text})
       when t not in [:clause_staged, :clause_unread],
       do: text

  defp whole_clause(_law), do: nil

  defp squash(nil), do: nil
  defp squash(s), do: s |> String.replace(~r/\s+/, " ") |> String.trim()

  # "UK_x:reg.1(2)" → "UK_x:reg.1"
  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
