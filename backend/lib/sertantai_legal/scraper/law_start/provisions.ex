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

  The words are read by: `LawStart.Statements` (several statements in one
  sentence), `LawStart.ListItems` (a list's items, each with its own
  exception and qualifier), `LawStart.Territorial` (a commencement country
  by country) and `LawStart.NumberWords` (numbers written in words).
  """

  alias SertantaiLegal.Scraper.LawStart

  alias SertantaiLegal.Scraper.LawStart.{
    Clause,
    Completing,
    ItemSubject,
    ListItems,
    MadeCondition,
    NestedItems,
    NumberWords,
    PurposeStages,
    ScheduleTable,
    Statements,
    Territorial,
    ThatDay,
    ThatProvision
  }

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? (?:only )?of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i
  @remaining ~r/\b(?:remaining (?:provisions|regulations|articles|sections|rules)|remainder|the rest of th(?:is|ese)|other provisions|all (?:other )?(?:provisions|regulations|articles|sections|rules)|provisions of this \w+(?: \([^)]*\))?,? except|preceding (?:provisions|Parts|sections|regulations|articles)|^\s*(?:\(\w+\)\s*)?otherwise\b|^\s*(?:\(\w+\)\s*)?(?:Subject to [^,]+,\s*)?the provisions of this)/i
  # a general clause left open for its list ("… come into force as follows—",
  # "… on the following dates—", "… come into force—")
  @open_clause ~r/into\s+(?:force|operation)\s*(?:as follows|on the following dates?)?\s*[—–:-]?\s*$/iu
  # a pointer to provisions named elsewhere, never what a general clause's
  # inline exception excepts ("except as provided in paragraph (2) below":
  # SI 2000/3251); a statement's "except the provisions mentioned in
  # subsection (1)" is followed there (2022 c.30 s.170(2))
  @pointer ~r/\b(?:in\s+accordance\s+with|(?:provided|specified|listed|mentioned|set\s+out|referred\s+to)\s+(?:for\s+)?(?:in|by|under))\b/i
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
  # a statement elsewhere names provisions first, never something under them
  # ("… a partial restriction notice served under section 183 above by a
  # notice … which shall come into force": Building Societies Act 1986
  # s.186(1))
  @provisions_subject ~r/^(?:\(\w+\)\s*)?(?:(?:Subject\s+to|Except|Apart\s+from|Other\s+than|Save|In\s+(?:Part|Schedule)\s+\w+)[^,]{0,200},\s*)?(?:the\s+)?(?:sections?|regulations?|articles?|rules?|paragraphs?|sub-?sections?|sub-?paragraphs?|Parts?|Chapters?|Schedules?|this|these|following|remaining|preceding|other|rest|provisions?|repeals?|amendments?)\b/i

  @purpose_item ~r/^(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that|for\s+(?:the\s+)?purposes?\s+of|for\s+all\s+(?:other\s+|remaining\s+)?purposes)\b/i
  # a list's head: "The following provisions …—", or "These provisions …—"
  # (2005 c.16 s.108(4))
  @list_subject ~r/\bthe following\b|^\W*(?:\(\w+\)\s*)?These\s+provisions\b/i
  @this_only ~r/^(?:\(\w+\)\s*)?This\s+(?:section|regulation|article|rule)\s+(?:shall\s+)?(?:comes?|came)\s+into/i
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
  # a provision that only names a statement's purpose, before its subject
  # ("In relation to an offence under regulation 3(2), regulations 6 to 8
  # come into force …": SI 2017/1312 reg.1(4)), is not in its scope
  @leading_purpose ~r/^\W*(?:\(\w+\)\s*)?(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|in\s+the\s+case\s+of|as\s+respects)\s+[^,;]+,\s*(?=(?:the\s+)?(?:sections?|regulations?|articles?|rules?|paragraphs?|Parts?|Chapters?|Schedules?)\b)/i
  @other_law ~r/\bof\s+(?:the|that)\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,12}(?:Act|Order|Regulations|Measure)\b/
  # a list another law heads: a commencement order's "The following
  # provisions of the 2014 Act come into force on 6th March 2017—" (SI
  # 2017/58 art.2) lists that Act's sections, never the order's articles.
  # The Act is named or dated: a bare "the Act" may be the Act speaking of
  # itself ("The following provisions of the Act shall come into force …,
  # namely—": EPA 1990 s.164(2))
  @other_law_list ~r/\b[Tt]he\s+following\s+(?:provisions\s+)?of\s+(?:the|that)\s+(?:\d{4}\s+|(?:[A-Z][\w()',-]*\s+){1,12})(?:Act|Order|Regulations|Measure)\b/

  @doc """
  The provision-level sentences of a law's commencement clause as groups,
  their references unexpanded (commencement-rules CR-03: a rule's scope):
  `kind` (`:named` | `:remaining` | `:unread`), `refs` (provisions as
  section_id prefixes; Parts and Chapters as the law's own ids, "UK_x:pt.II",
  "UK_x:pt.6.ch.1"), `excluded`, `treatment`, `date`, `qualified_date` (a
  qualified sentence's date: a partial rule's, CR-03),
  `evidence`, `text`.
  """
  @spec groups([map()], SertantaiLegal.Scraper.LawStart.OwnDays.days(), LawStart.t()) :: [map()]
  def groups(written, made, %LawStart{} = law) do
    clause = if clause?(law), do: provision(law.evidence)
    # read without their completing words ("(so far as not in force by
    # virtue of subsection (2))": `LawStart.Completing`), which limit nothing
    rows = Enum.map(written, &Completing.row/1)
    start = law |> whole_clause() |> Completing.drop()

    # a law left to orders reads its clause's other sentences too ("Subject
    # to subsections (2) and (3), this Act is to come into force on such day
    # as …": LGRA 1997 s.34, CV-S04)
    clause_groups =
      if clause, do: clause_groups(rows, made, law.evidence, start, law.date), else: []

    words = as_written(written)

    for g <- clause_groups ++ elsewhere(rows, made, clause, law.date) do
      %{g | refs: Enum.map(g.refs, &elem(&1, 0)), text: Map.get(words, g.text, g.text)}
    end
  end

  # each sentence read without its completing words, to the words written
  defp as_written(rows) do
    for row <- rows,
        s <- sentences(row),
        read = Completing.drop(s),
        read != s,
        into: %{},
        do: {read, s}
  end

  defp clause?(%LawStart{evidence: e}), do: is_binary(e) and String.contains?(e, ":")

  @doc """
  Whether `sentence` heads a list of another law's provisions ("The
  following provisions of the 2014 Act come into force on …—": a
  commencement order's, SI 2017/58 art.2), which states nothing of the
  law's own commencement.
  """
  @spec other_law_list?(String.t()) :: boolean()
  def other_law_list?(sentence), do: Regex.match?(@other_law_list, sentence)

  @doc """
  The provisions a general clause leaves out — inline ("This Act, apart
  from sections 7 and 8 and this section, shall come into force …": Police
  (Health and Safety) Act 1997 s.9(2); with brackets inside, "except Parts
  1, 2 and 3 and section 26(2)": nia 2016/13 s.27(1); "(apart from this
  section and paragraph 6(2) and (5) of Schedule 5)": 1999 c.28 s.43(2)) or in a list below it ("This Act,
  except— (a) this section; (b) sections 8(2), 11(1) to (5), 12 and 13; …":
  Gas Act 1995 s.18(2)) — as refs (CV-S04 round 3). [] for none.
  """
  @spec except_refs(LawStart.t(), [map()]) :: [String.t()]
  def except_refs(%LawStart{evidence: evidence, text: text}, rows)
      when is_binary(evidence) and is_binary(text) do
    base = provision(evidence)
    row = Enum.find(rows, &(&1.section_id == evidence))

    source =
      if text =~ ~r/(?:except|apart\s+from|other\s+than)\s*[—–]/u and row != nil,
        do: row |> children(rows) |> Enum.map_join("; ", &(&1.text || "")),
        else: inline_except(text)

    source
    |> String.split(~r/;\s*/, trim: true)
    |> Enum.reject(&Regex.match?(@qualified, &1))
    |> Enum.flat_map(&weighted_refs(&1, rows, base))
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
  end

  def except_refs(_law, _rows), do: []

  @doc """
  The provisions a general clause leaves out only so far: those the list
  it points to names with a limit of their own ("… the provisions
  specified in subsection (6) below (which come into force on the passing
  of this Act) …", the list ending "and subsection (8) of section 67 so
  far as it relates to that Part of that Schedule": 1994 c.21 s.68(4),
  (6)(f)) — as refs. [] for none.
  """
  @spec except_partly(LawStart.t(), [map()]) :: [String.t()]
  def except_partly(%LawStart{evidence: evidence, text: text}, rows)
      when is_binary(evidence) and is_binary(text) do
    {_named, _excepted, partly} = mentioned_items(text, rows, provision(evidence))

    partly |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
  end

  def except_partly(_law, _rows), do: []

  # an exception between commas or in brackets before the verb — never a
  # pointer there ("apart from the provisions coming into force in
  # accordance with subsection (4)": 2004 c.22 s.11(3)); a later form's
  # pointer is followed into the provision it names (1994 c.21 s.68(5))
  @inline_except ~r/(?:,\s*|\(\s*)(?:except(?:\s+for)?|apart\s+from|other\s+than)\s+((?:[^—–();]|\([^()]*\))+?)\s*(?:,|\))\s*(?:shall|comes?|is\s+to|are\s+to|does|do)\b/iu

  @inline_excepts [
    # "… come into force on 5th October 2012 except for regulation
    # 3(3)(b) which comes into force on the date of commencement of Part
    # 9A …" (SI 2012/2267 reg.1(2))
    ~r/\bexcept\s+(?:for\s+)?((?:sections?|regulations?|articles?|rules?)\s+[^,]+?)\s*,?\s+which\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\b/iu,
    # "Except for section 26 and this section the provisions of this Act
    # shall not come into force until …" (Road Traffic (Driver
    # Licensing) Act 1988-like, ukpga 1988/45)
    ~r/^\W*(?:\(\w+\)\s*)?(?:except\s+for|apart\s+from|other\s+than)\s+(.+?),?\s+(?:the\s+provisions\s+of\s+)?this\s+(?:Act|Measure)\b/iu,
    # "Except for regulation 2(3) and (4), these Regulations come into
    # force on 22nd May 2025" (SI 2025/407 reg.1(2)); never a pointer
    # ("Except as provided in paragraphs (2) and (3), these Regulations
    # come into force on …": WSI 2026/103 reg.1)
    ~r/^\W*(?:\(\w+\)\s*)?(?:except(?:\s+for)?|apart\s+from|other\s+than)\s+(?!as\s+|in\s+|where\s+|for\s+the\s+purposes?\b)((?:sections?|regulations?|articles?|rules?|Parts?)\s+\d[^,]*?),\s*(?:these\s+(?:Regulations|Rules)|this\s+Order)\s+(?:shall\s+)?come\s+into\s+(?:force|operation)\b/iu
  ]

  # the words of the first inline exception form that matches
  defp inline_except(text) do
    case Regex.run(@inline_except, text) do
      [_, w] ->
        if w =~ @pointer, do: "", else: w

      nil ->
        Enum.find_value(@inline_excepts, "", &first_group(&1, text))
    end
  end

  defp first_group(re, text) do
    case Regex.run(re, text) do
      [_, w | _] -> w
      nil -> nil
    end
  end

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
        s <- Enum.flat_map(sentences(row), &statements/1),
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
    # (a head whose condition on the making day fails states nothing: "If
    # this Order is made on or after 31st December 2024—", SI 2024/1366
    # art.2(3), made on the 18th)
    held =
      rows |> Enum.filter(&(provision(&1.section_id) == base)) |> MadeCondition.holding(made)

    clause = squash(clause)

    # never the sentence the law's start was read from ("they come into
    # force …", a list item "come into force …": V1-02) — but its own
    # exception, dated ("…, except regulation 20(4) which shall come into
    # operation on 6th April 2007": CV-S04)
    for row <- held,
        {s, written} <- row |> ThatDay.resolve(held) |> sentences() |> Enum.zip(sentences(row)),
        Regex.match?(@cif, s),
        not Clause.mention?(s),
        g <- sentence_statements(s, clause, row, rows, made, base, start),
        # (an item counting from "that day" is read with the day written
        # out, and keeps its words)
        do: if(g.text == s, do: %{g | text: written}, else: g)
  end

  # a sentence of statements run together is read a statement at a time
  # (`LawStart.Statements`); the law's start is still the first's
  defp sentence_statements(s, clause, row, rows, made, base, start) do
    [first | later] = statements(s)

    own =
      if squash(s) == clause or squash(first) == clause,
        do: s |> except_which(row, rows, made, base) |> with_mentioned_partly(s, rows, base),
        else: clause_sentence_groups(first, row, rows, made, base, start)

    own ++ Enum.flat_map(later, &clause_sentence_groups(&1, row, rows, made, base, start))
  end

  defp statements(s), do: Statements.split(s)

  @except_which [
    ~r/\bexcept\s+(.+?)\s+which\s+(?:shall\s+(?:come|be\s+brought)|comes?)\s+into\s+(?:force|operation)\s+(.+?)\.?$/i,
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
    ~r/\b(?:save|except)\s+that\s+(.+?)\s+shall\s+come\s+into\s+(?:force|operation)\s+(.+?)[;.]?$/i,
    # "… with the exception of articles 18, 23 … which shall come into force
    # on 1st March 2005" (SI 2000/311); "…, apart from section 167 and
    # Schedule 21 which come into force on such day as …" (2026 c.18)
    ~r/\b(?:with\s+the\s+exception\s+of|apart\s+from)\s+(.+?)\s+which\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)\.?$/i
  ]

  # a second dated exception chained on: "… except that regulation 14(2)
  # shall come into force on 1st January 1993 and regulation 16(7) shall come
  # into force on 1st September 1990" (SI 1988/1655)
  @and_dated ~r/^(.+?)\s+and\s+((?:regulations?|sections?|articles?|rules?)\s+\d.+?)\s+shall\s+come\s+into\s+(?:force|operation)\s+(.+?)$/i

  # (an undated exception kept only for numbered provisions of its own:
  # never "the repeal of the entry … in Part II of Schedule 1 to the House
  # of Commons Disqualification Act 1975": Ports Act 1981)
  @own_numbered ~r/^\s*(?:for\s+)?(?:sections?|regulations?|articles?|rules?)\s+\d[\w()]*(?:\s*(?:,|and|to)\s*\d?[\w()]*)*\s*$/i

  # the exception's own date; one the reader can't date ("on the date of
  # commencement of Part 9A … of the Merchant Shipping Act 1995": SI
  # 2012/2267 reg.1(2)) is kept, unread, so it's never the law's date
  defp except_which(s, row, rows, made, base) do
    case Enum.find_value(@except_which, &Regex.run(&1, s)) do
      [_, subject, tail] ->
        for {subject, tail} <- chained(following(subject, row, rows), tail),
            [_ | _] = refs <- [weighted_refs(subject, rows, base)],
            {treatment, d} <- [except_date(tail, subject, made)],
            do: %{
              kind: :named,
              refs: refs,
              excluded: [],
              treatment: treatment,
              date: d,
              qualified_date: nil,
              evidence: row.section_id,
              text: s
            }

      nil ->
        []
    end
  end

  # "… except for the following provisions which come into force on 5th
  # July 2018— (a) regulation 4; (b) regulations 6 and 7; …" (SI 2018/575
  # reg.1(2)): the provisions are the rows under the statement
  defp following(subject, row, rows) do
    if subject =~ @list_subject,
      do: row |> children(rows) |> Enum.map_join(", ", &(&1.text || "")),
      else: subject
  end

  defp chained(subject, tail) do
    case Regex.run(@and_dated, tail) do
      [_, first, next, rest] -> [{subject, first} | chained(next, rest)]
      nil -> [{subject, tail}]
    end
  end

  defp except_date(tail, subject, made) do
    case tail_treatment(tail, made) do
      {:provision_dated, %Date{} = d} -> {:provision_dated, d}
      _ -> if Regex.match?(@own_numbered, subject), do: {:provision_unread, nil}
    end
  end

  # "… shall not come into operation [for some purposes] until <date>"
  # (NISR 2006/1 reg.1(a), (b)): the provisions it names — or, said of the
  # law ("they", "these Regulations"), the rest of it — in partly from the
  # law's start, fully from that date (CV-S04)
  @not_until ~r/^(.*?)\bshall\s+not\s+(?:come|be\s+brought)\s+into\s+(?:force|operation)\b(.*?)\buntil\s+(.+?)\s*[;.,]?\s*(?:and|or)?\s*$/is
  @the_law ~r/\b(?:they|it|these\s+(?:Regulations|Rules)|this\s+(?:Act|Order|Measure))\b/i

  @that_is_to_say ~r/\d{4}\s*,\s*(?:that\s+is\s+to\s+say|namely)\s*,?\s*(?:[—–]\s*)?(.+)$/is

  # a "not until" statement's subject, and what it excepts: the list after
  # "that is to say" where the subject only heads it ("The following
  # provisions …")
  defp that_is_to_say(subject, until) do
    with true <- subject =~ @list_subject,
         [_, list] <- Regex.run(@that_is_to_say, until) do
      split_except(list)
    else
      _ -> {subject, ""}
    end
  end

  defp not_until(s, row, rows, made, base, start) do
    with %Date{} <- start,
         [_, subject, _qualifier, until] <- Regex.run(@not_until, s),
         {_, %Date{} = d} <- Clause.tail_date("on " <> String.trim(until), made) do
      # "Subject to section 8, …"; "Except so far as relating to the repeal
      # in section 18(3) of the National Health Service Act 1977, subsection
      # (1) (and Schedule 3) shall not come into force until 1st April 1996"
      # (Health Authorities Act 1995 s.5(2), CV-S09 round 5): the carve-out
      # in force from the start, partly, as any "not until"
      subject =
        String.replace(
          subject,
          ~r/^\s*(?:\(\w+\)\s*)?(?:subject\s+to|except\s+(?:so\s+far\s+as|in\s+so\s+far\s+as|as)|save\s+(?:so\s+far\s+as|as))\s+[^,]+,\s*/i,
          ""
        )

      # (the provisions listed after the day are the subject: "The
      # following provisions of this Act shall not come into force until
      # 1st April 1965, that is to say, Parts II, III, and V to VIII other
      # than sections 17(6), …": 1963 c.33 s.94(2))
      {subject, excepted} = that_is_to_say(subject, until)
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
        excluded: refs(excepted, rows, relative_base(refs, base)),
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
  defp clause_sentence_groups(s, row, rows, made, base, start),
    do: s |> sentence_read(row, rows, made, base, start) |> with_mentioned_partly(s, rows, base)

  defp sentence_read(s, row, rows, made, base, start) do
    with nil <- not_until(s, row, rows, made, base, start),
         nil <- later_for(s, row, made, start),
         nil <- by_application(s, row, rows, made, base),
         [] <- except_which(s, row, rows, made, base) do
      clause_sentence_groups(s, row, rows, made, base)
    end
  end

  # "Part II of this Act, in its application to England and Wales, shall
  # come into operation on such day as …, and in its application to
  # Scotland on such day as …" (1969 c.10 s.38(3)): the subject's
  # provisions, one group per country with its own day
  defp by_application(s, row, rows, made, base) do
    with {subject, countries} <- Territorial.by_application(s),
         [_ | _] = refs <- weighted_refs(subject, rows, base) do
      for {place, tail} <- countries,
          do: country_group(tail_treatment(tail, made), place, refs, row, s)
    else
      _ -> nil
    end
  end

  defp country_group({treatment, date}, place, refs, row, s) do
    dated? = treatment == :provision_dated

    %{
      kind: :named,
      refs: refs,
      excluded: [],
      treatment: if(dated?, do: :provision_qualified, else: treatment),
      date: nil,
      qualified_date: if(dated?, do: date),
      territory: place,
      evidence: row.section_id,
      text: s
    }
  end

  # "… shall come into force on 23rd February 2008, except that— (a) in
  # relation to noise arising from …, these Regulations shall come into
  # force on 6th April 2008" (SI 2007/3075 reg.1(a)): the law later for some
  # purposes — as "not until": in partly from its start, fully from that
  # date. (A place is a territory's own date, never this: `@by_country`.)
  @later_for ~r/^\W*(?:\(\w+\)\s*)?(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|in\s+the\s+case\s+of|as\s+respects)\s+([^,]+),\s*(?:these\s+(?:Regulations|Rules)|this\s+(?:Order|Act|Measure)|they|it)\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)$/is
  @place ~r/^(?:England|Wales|Scotland|Northern Ireland|Great Britain|England and Wales)$/i

  defp later_for(s, row, made, %Date{} = start) do
    with [_, purpose, tail] <- Regex.run(@later_for, String.trim(s)),
         false <- Regex.match?(@place, String.trim(purpose)),
         tail = String.replace(tail, ~r/[\s;,.]*(?:and|or)?\s*$/i, ""),
         {:provision_dated, %Date{} = d} <- tail_treatment(tail, made),
         :gt <- Date.compare(d, start) do
      g = %{kind: :remaining, refs: [], excluded: [], evidence: row.section_id, text: s}

      [
        Map.merge(g, %{treatment: :provision_qualified, date: nil, qualified_date: start}),
        Map.merge(g, %{treatment: :provision_dated, date: d, qualified_date: nil})
      ]
    else
      _ -> nil
    end
  end

  defp later_for(_s, _row, _made, _start), do: nil

  defp clause_sentence_groups(s, row, rows, made, base) do
    cond do
      whole_law?(s) and Regex.match?(@open_clause, s) ->
        items =
          for item <- dash_items(row, rows),
              not Regex.match?(@cif, item.text || ""),
              g <- open_item(item, rows, made, base),
              do: g

        PurposeStages.settle(items, &weighted_refs(&1.text, rows, base))

      # another general sentence in the clause than the law's start: the
      # rest of the law, dated ("Other than those regulations specified in
      # paragraph (3) these Regulations come into force on 31 October 2026"
      # beside "… come into force in accordance with paragraphs (2) and (3)":
      # SSI 2025/417 reg.1(2), CV-S04)
      Clause.general?(s) ->
        purpose_stages(s, row, rows, made, base) || general_rest(s, row, made)

      true ->
        excepted_rest(s, row, rows, made, base) || groups(s, row, rows, made, base)
    end
  end

  # a statement of the whole law: a general sentence, or the law's own list
  # item with the law for its subject ("This Order— … (c) comes into
  # force— (i) for the purposes of article 18(1), one month after the day
  # on which it is made; (ii) for all other purposes, on 5th October
  # 2015": SI 2015/776 art.1)
  @bare_open ~r/^\W*(?:\(\w+\)\s*)?(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i

  defp whole_law?(s), do: Clause.general?(s) or Regex.match?(@bare_open, s)

  # the whole law staged by purpose in one statement (`PurposeStages`): the
  # law is the subject, the provision only names the purpose, so the whole
  # law is partly in force on the first day and fully on the second ("…,
  # for the purpose of regulation 10(2), on 20th March 1991 and for all
  # other purposes on 1st September 1991": SI 1991/346 reg.1(1); Jason
  # 2026-11-20)
  defp purpose_stages(s, row, rows, made, base) do
    with [_subject, tail] <- Regex.split(@cif, s, parts: 2),
         [{:partial, purpose, _} | _] = stages <- PurposeStages.read(tail, made) do
      stages
      |> Enum.map(&stage_group(&1, row, s))
      |> PurposeStages.settle(fn _waiting -> weighted_refs(purpose, rows, base) end)
    else
      _ -> nil
    end
  end

  defp stage_group({:full, nil, date}, row, s), do: rest_group(:provision_dated, date, row, s)

  defp stage_group({:partial, _purpose, date}, row, s),
    do: rest_group(:provision_qualified, date, row, s)

  defp rest_group(treatment, date, row, text) do
    %{
      kind: :remaining,
      refs: [],
      excluded: [],
      treatment: treatment,
      date: if(treatment == :provision_qualified, do: nil, else: date),
      qualified_date: if(treatment == :provision_qualified, do: date),
      evidence: row.section_id,
      text: text
    }
  end

  # "except for regulation 4 and regulation 6 to the extent that it applies
  # to regulation 4, they shall come into force on 1st March 1994" (SI
  # 1994/232 reg.1(a)): the rest of the law less what is excepted outright;
  # an item excepted only to an extent comes in with the rest, partly
  @excepted_rest ~r/^\W*(?:\(\w+\)\s*)?(?:except(?:\s+for)?|other\s+than|apart\s+from)\s+(.+?),\s*(?:they|it|these\s+(?:Regulations|Rules)|this\s+(?:Order|Act|Measure))\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)$/is

  defp excepted_rest(s, row, rows, made, base) do
    with [_, excepted, tail] <- Regex.run(@excepted_rest, String.trim(s)),
         {treatment, date} when treatment != :provision_unread <- tail_treatment(tail, made) do
      {plain, _qualified} = ListItems.qualified_last(excepted) || {excepted, ""}

      [
        %{
          kind: :remaining,
          refs: [],
          excluded: refs(plain, rows, base),
          treatment: treatment,
          date: date,
          qualified_date: nil,
          evidence: row.section_id,
          text: s
        }
      ]
    else
      _ -> nil
    end
  end

  # an item whose day is not read is kept, unread, with the reason where
  # the day counts from one not held ("for the purposes of regulations 1, 2
  # and 3 on the 22nd day after the day on which these Regulations are
  # laid": SI 2018/1221 reg.2(a), no laid day held) — never dropped, which
  # left its provisions to the other items' days
  defp open_item(item, rows, made, base) do
    case Clause.item_split(item.text, made) do
      {subject, tail, date} -> open_item(subject, tail, date, item, rows, made, base)
      nil -> [undated_item(item, rows, made, base)]
    end
  end

  defp undated_item(item, rows, made, base) do
    %{
      kind: :unread,
      refs: weighted_refs(item.text, rows, base),
      excluded: [],
      treatment: :provision_unread,
      date: nil,
      qualified_date: nil,
      reason: Clause.item_unread_reason(item.text, made),
      evidence: item.section_id,
      text: item.text
    }
  end

  # an item of a general clause's list: its subject's provisions; "except
  # for regulations 4 and 14, on …" the rest less those (SI 1993/1213
  # reg.1(a)); an item opening with its date, the whole law — fully "for all
  # other purposes", else partly, for the purpose or place it names ("from
  # 1st July 2004 for international shipping": SI 2004/1495 reg.1(a))
  defp open_item("", tail, date, item, _rows, _made, _base) do
    whole? = tail =~ ~r/\bfor\s+all\s+(?:other\s+)?purposes\b/i

    rest =
      String.replace(tail, ~r/^(?:on|from)\s+\S+\s+\S+,?\s+\d{4}[\s;,.]*(?:and|or)?\s*$/i, "")

    partial? = not whole? and rest != ""

    [
      %{
        kind: :remaining,
        refs: [],
        excluded: [],
        treatment: if(partial?, do: :provision_qualified, else: :provision_dated),
        date: if(partial?, do: nil, else: date),
        qualified_date: if(partial?, do: date),
        evidence: item.section_id,
        text: item.text
      }
    ]
  end

  # an item opening with its purpose is the whole law's too: partly for it,
  # fully "for all other purposes" ("(a) insofar as Part 2A of the 1990 Act
  # empowers …, on 16 November 2006; (b) for all other purposes, on 10
  # December 2006": SI 2006/2988 reg.1(2))
  defp open_item(subject, tail, date, item, rows, made, base) do
    # (one naming a provision too: the law is the subject, the provision
    # names the purpose — "for the purposes of article 18(1), one month
    # after …": SI 2015/776 art.1(c)(i); Jason 2026-11-20)
    if Regex.match?(@purpose_item, subject),
      do: open_item("", "#{tail} #{subject}", date, item, rows, made, base),
      else: named_item(subject, tail, item, rows, made, base)
  end

  defp named_item(subject, tail, item, rows, made, base) do
    subject =
      String.replace(
        subject,
        ~r/^(?:except|other\s+than|apart\s+from)\b/i,
        "the remaining provisions \\0"
      )

    groups("#{subject} come into force #{tail}", item, rows, made, base)
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
  # the power to appoint different days is no qualifier of the statement
  # ("…; and different days may be so appointed for different purposes of
  # this Act or for the same purposes in relation to different courts":
  # 1968 c.64 s.20(4))
  @different_days ~r/\s*[;,]\s*and\s+different\s+(?:days|dates)\s+may\s+be\s+(?:so\s+)?appointed\b.*$/is

  # (read without it; the groups keep the sentence as written)
  # … and with "subsection (2) of that section" as the section it means
  # (`ThatProvision`), a qualifier before its item put after it
  defp groups(sentence, row, rows, made, base) do
    case @different_days
         |> Regex.replace(sentence, "")
         |> ThatProvision.name()
         |> ListItems.qualifier_after() do
      ^sentence -> read_groups(sentence, row, rows, made, base)
      plain -> for g <- read_groups(plain, row, rows, made, base), do: %{g | text: sentence}
    end
  end

  defp read_groups(sentence, row, rows, made, base) do
    [subject, tail] = Regex.split(@cif, sentence, parts: 2)
    {tail, inline} = tail_and_list(tail)
    {treatment, date} = tail_treatment(tail, made)

    cond do
      list_head?(subject, tail, inline, row, rows) ->
        list_head(subject, row, rows, made, base)

      treatment == :provision_unread and tied?(subject, tail) ->
        tied(sentence, subject, inline, row, rows, made, base)

      true ->
        sentence_groups(sentence, subject, tail, inline, treatment, date, row, rows, made, base)
    end
  end

  # an inline list follows "namely—" or a dash; else the rows under this one
  defp tail_and_list(tail) do
    case Regex.split(~r/(?:,?\s*namely\s*)?(?:[—–]|:(?=\s))\s*/u, String.trim(tail), parts: 2) do
      [t, list] -> {t, list}
      [t] -> {t, ""}
    end
  end

  defp list_head?(subject, tail, inline, row, rows),
    do:
      tail == "" and inline == "" and not (subject =~ @list_subject) and
        children(row, rows) != []

  # "Section 3 comes into force at the same time as section 1 comes fully
  # into force in relation to premises in England" (2021 c.24 s.4(5)): the
  # subject's provisions wait for the other's day (an event day, undated);
  # what qualifies the other's commencement qualifies nothing here. Never a
  # deeming ("are to be regarded as having come into force at the same time
  # as …": 2011 c.19 s.29(5))
  # … nor one after the law's own other provisions, which its general
  # clause dates ("Regulation 18(2) comes into force immediately after the
  # coming into force of the other regulations": SI 2013/1471 reg.1(3))
  @own_rest ~r/\bthe\s+(?:other|remaining|rest\s+of\s+the)\s+(?:regulations|provisions|articles|sections|rules)\b|\bth(?:ese|is)\s+(?:Regulations|Order|Rules|Act)\b/i

  defp tied?(subject, tail) do
    Clause.tied?(tail) and not (subject =~ ~r/\b(?:regarded|treated|deemed|taken)\s+as\b/i) and
      not (tail =~ @own_rest)
  end

  @tied_words "with another provision"

  defp tied(sentence, subject, inline, row, rows, made, base) do
    read = "#{subject} come into force #{@tied_words}"

    for g <-
          sentence_groups(
            read,
            subject,
            @tied_words,
            inline,
            :provision_by_order,
            nil,
            row,
            rows,
            made,
            base
          ),
        do: g |> Map.put(:tied, true) |> Map.put(:text, sentence)
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
      # (a day an order fixes, kept for the items its qualifier leaves
      # partly in: "on the transfer date", 1986 c.44 s.68(3))
      appointed: treatment == :provision_by_order,
      evidence: row.section_id,
      text: sentence
    }

    cond do
      subject =~ @other_law_list -> []
      subject =~ @list_subject -> list_groups(g, subject, tail, inline, row, rows, base)
      true -> subject_groups(g, sentence, subject, tail, rows, base)
    end
  end

  # a list read item by item (`LawStart.ListItems`): the provisions its
  # items name in full, and those their own qualifiers leave partly in
  defp list_groups(g, subject, tail, inline, row, rows, base) do
    {head, before} = head_and_items(subject)
    {head, aside} = ListItems.head_aside(head)

    # (the rows nested under a dash-ended item are that item's:
    # `LawStart.NestedItems`)
    {flat, nested} = row |> children(rows) |> NestedItems.fold()

    items =
      before
      |> ListItems.split(inline, flat)
      |> Enum.map(&ListItems.read/1)
      |> Kernel.++(nested)
      |> ListItems.in_schedule(head)
      |> ListItems.in_part(head)

    plain? = Enum.any?(items, &(&1.plain != ""))
    qualified? = Enum.any?(items, &(&1.qualified != ""))

    # each item's own "except …" ("Part 7 …, except regulation 73")
    {refs, excluded} = Enum.reduce(items, {[], []}, &item_refs(&1, &2, rows, base))
    named = %{g | refs: refs, excluded: excluded}

    listed =
      partly(
        g,
        Enum.flat_map([aside | Enum.map(items, & &1.qualified)], &weighted_refs(&1, rows, base))
      )

    # a list whose items are all qualified is only the qualified group
    [named |> classify(head <> " " <> tail) |> beside(listed), listed]
    |> Enum.reject(&(&1.treatment == :provision_qualified and &1.refs == []))
    |> Enum.reject(&(&1.kind == :unread and not plain? and qualified?))
  end

  defp subject_groups(g, sentence, subject, tail, rows, base) do
    case bracket_qualified(subject) || trailing_qualified(subject) ||
           ListItems.qualified_last(subject) do
      {plain, qualified} ->
        # "regulations 2, 5, 10 and 11, and, so far as they relate to …,
        # regulations 3, 6 and 7": the qualifier is only the later items'
        named = %{g | refs: weighted_refs(plain, rows, base)}
        listed = partly(g, weighted_refs(qualified, rows, base))

        [named |> classify(plain <> " " <> tail, plain) |> beside(listed), listed]
        |> Enum.reject(&(&1.refs == []))

      nil ->
        whole_subject(g, sentence, subject, rows, base)
    end
  end

  # the items named in full beside a qualified one stay named when the
  # day is unread (an event: "Part III of Schedule 7 and section 109(6) so
  # far as relating to that Part shall come into force on the dissolution
  # of British Telecommunications", 1984 c.12 s.110(4)): an unread rule
  # for them, as the qualified item has
  defp beside(%{kind: :unread, refs: [_ | _]} = named, %{refs: [_ | _]}),
    do: %{named | kind: :named}

  defp beside(named, _listed), do: named

  # the group of the provisions a qualifier leaves partly in, on the
  # statement's date
  defp partly(g, refs),
    do: %{g | refs: refs, treatment: :provision_qualified, date: nil, qualified_date: g.date}

  defp item_refs(item, {refs, excluded}, rows, base) do
    named = weighted_refs(item.plain, rows, base)
    {refs ++ named, excluded ++ refs(item.excepted, rows, relative_base(named, base))}
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
  # s.33 "Sections 33, 34, 41 and (in so far as …) 42"); so too where it
  # is what they are excepted from ("section 261(1) and Schedule 27 and,
  # except so far as relating to any Acts of the Scottish Parliament …,
  # section 261(4) and Schedule 30": 2004 c.33 s.263(10)(b))
  defp trailing_qualified(subject) do
    case Regex.run(
           ~r/^(.*\d.*?),?\s+and,?\s+(?:except\s+)?(?:in\s+)?so\s+far\s+as\b[^,]*,\s*(.*\d.*)$/is,
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

  # an exception set aside between two items is the later item's: "Regulations
  # 24(1)(d)(i) and (2) and 26 and , other than regulation 42, Parts 5 to 7
  # of these Regulations" (SI 2012/2079 reg.1(3)) names the Parts too
  @aside_except ~r/^(.+?\band)\s*,\s*(?:other\s+than|except|apart\s+from)\s+([^,;]+?)\s*,\s*((?:Parts?|Chapters?|regulations?|sections?|articles?|rules?)\s+[0-9IVXL].*)$/is

  defp subject_and_except(subject) do
    case Regex.run(@aside_except, subject) do
      [_, before, aside, later] -> {before <> " " <> later, aside}
      nil -> leading_except(subject) || split_except(subject)
    end
  end

  # an exception leading a Part or Chapter: "Except section 53 (and
  # schedule 4), this Part comes into force on the day after Royal Assent"
  # (asp 2013/5 s.56(1)) names the Part, less what it excepts
  @leading_except ~r/^\W*(?:\(\w+\)\s*)?(?:except(?:\s+for)?|other\s+than|apart\s+from)\s+(.+?),\s*(this\s+(?:Part|Chapter)\b.*|(?:Parts?|Chapters?)\s+[0-9IVXL].*)$/is

  defp leading_except(subject) do
    case Regex.run(@leading_except, subject) do
      [_, excepted, named] -> {named, excepted}
      nil -> nil
    end
  end

  defp whole_subject(g, sentence, subject, rows, base) do
    {subject_in, subject_out} = subject_and_except(subject)
    refs = subject_in |> String.replace(@leading_purpose, "") |> weighted_refs(rows, base)

    # "Regulation 26, with the exception of paragraph (4)": relative to
    # what the subject names
    {_named, excepted, _partly} = mentioned_items(subject_in, rows, base)
    excluded = refs(subject_out, rows, relative_base(refs, base)) ++ excepted

    [classify(%{g | refs: refs, excluded: excluded}, sentence, subject)]
  end

  # a statement pointing to a subsection's list ("The provisions specified
  # in subsection (2) come into force …"; "… and the provisions specified
  # in subsection (6) below (which come into force on the passing of this
  # Act) …": 1994 c.21 s.68(4)), however it is read: each group holding the
  # provisions the list names in full has beside it those the list limits
  defp with_mentioned_partly(groups, s, rows, base) do
    case mentioned_items(s, rows, base) do
      {_named, _excepted, []} -> groups
      {named, _excepted, partly} -> Enum.flat_map(groups, &beside_partly(&1, named, partly))
    end
  end

  defp beside_partly(g, named, partly) do
    if g.refs != [] and g.refs -- named != g.refs,
      do: [g | mentioned_partly(g, partly -- g.refs)],
      else: [g]
  end

  # the provisions the subsection pointed to names with a limit of their
  # own ("in Part 4 of Schedule 5, the repeals to the Environmental
  # Protection Act 1990": CNEA 2005 s.108(2)(h)) come in on the statement's
  # day, partly; country by country where the statement is (s.108(1))
  defp mentioned_partly(_named, []), do: []
  defp mentioned_partly(%{kind: :unread}, _partly), do: []

  defp mentioned_partly(%{treatment: :provision_by_order, territory: place} = named, partly)
       when is_binary(place),
       do: [Map.merge(named, %{kind: :named, refs: partly, excluded: [], limited: true})]

  defp mentioned_partly(named, partly) do
    day = named.date || named.qualified_date

    [
      %{named | kind: :named, refs: partly, excluded: []}
      |> Map.merge(%{treatment: :provision_qualified, date: nil, qualified_date: day})
    ]
  end

  # the items may come before the verb: "The following provisions— section
  # 8, section 317(6) …, shall come into force on such day as …" (1996 c.56
  # s.583(3), 1994 c.29 s.94(2)); the list is classed by its head alone
  defp head_and_items(subject) do
    # (or after "namely", no dash: "The following provisions of this Act,
    # namely sections 13 to 19, this section (except subsection (2)) and
    # the Schedule, shall come into force …": 1968 c.64 s.20(4))
    case Regex.split(~r/(?<=[—–])\s*|,\s*namely\s+(?![—–])/u, subject, parts: 2) do
      [head, items] -> {head, items |> String.trim() |> String.trim_trailing(",")}
      _ -> {subject, ""}
    end
  end

  # a statement left to an order and qualified only by a country is by
  # order for that country, never a partial commencement ("in relation to
  # England, in accordance with provision made by order": CNEA 2005
  # s.108(1)(a))
  defp classify(g, qualifiable, subject \\ "") do
    case g.treatment == :provision_by_order && Territorial.only(qualifiable) do
      place when is_binary(place) ->
        by_order_for(g, place, Regex.match?(@remaining, subject))

      _ ->
        classify_plain(g, qualifiable, subject)
    end
  end

  # (the provisions it names stay named: "other provisions of Parts 1 and 2
  # come into force in relation to England in accordance with provision
  # made by order", FWMA 2010 s.49(3))
  defp by_order_for(%{refs: [_ | _]} = g, place, _rest?), do: Map.put(g, :territory, place)
  defp by_order_for(g, place, true), do: Map.merge(g, %{kind: :remaining, territory: place})
  defp by_order_for(g, _place, false), do: unread(g)

  defp unread(g), do: %{g | kind: :unread, treatment: :provision_unread, date: nil}

  # the rest of a container the statement names ("the remaining provisions
  # of Part 5", SSI 2020/154 reg.1(5); "The remainder of regulation 11",
  # NISR 2008/231 reg.1(5)) is that container's, never the whole law's: the
  # container stays named, and what another statement names within it keeps
  # its own day (the evaluator's most specific rule)
  @container_rest ~r/\b(?:(?:remaining|other)\s+provisions|remainder|rest)\s+of\s+(?:Parts?|Chapters?|regulations?|sections?|articles?|rules?)\s+(?:\d|[IVXL]+\b)/

  defp container_rest?(g, subject),
    do: g.refs != [] and g.treatment != :provision_unread and subject =~ @container_rest

  # provisions described, not named ("the provisions of this Order which
  # confer powers enabling rules or orders to be made … come into force on
  # the making of this Order, but for the purpose only of the exercise of
  # those powers": SI 2010/231 art.1(3)), are not read, whatever qualifies
  # the statement
  @described ~r/\bprovisions\s+of\s+(?:this|these)\s+\w+\s*,?\s+(?:which|that)\b/i

  defp described?(g, subject), do: g.refs == [] and subject =~ @described

  defp classify_plain(g, qualifiable, subject) do
    cond do
      Regex.match?(@qualified, qualifiable) ->
        if described?(g, subject),
          do: unread(g),
          else: %{g | treatment: :provision_qualified, date: nil, qualified_date: g.date}

      container_rest?(g, subject) ->
        g

      Regex.match?(@remaining, subject) and g.treatment != :provision_unread ->
        %{g | kind: :remaining}

      g.refs == [] or g.treatment == :provision_unread ->
        unread(g)

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
    # ("for all remaining purposes, on 28th January 2013": SI 2012/2079
    # reg.1(3A)(b))
    tail =
      String.replace(
        tail,
        ~r/^for\s+all\s+(?:other\s+|remaining\s+)?purposes\s*,?\s+(?=on\b)/i,
        ""
      )

    # an item opening with its extent and closing with its day: "so far as
    # is necessary for the purpose of enabling the Secretary of State to
    # take action …, on 1st October 2012" (SI 2012/2079 reg.1(4)(a)); the
    # extent stays the statement's qualifier
    tail =
      String.replace(
        tail,
        ~r/^(?:in\s+)?so\s+far\s+as\s+(?:[^,()]|\((?:[^()]|\([^()]*\))*\)){1,400},\s+(?=on\s+\d{1,2}(?:st|nd|rd|th)?\s+[A-Z][a-z]+,?\s+\d{4}\W*$)/i,
        ""
      )

    # the day after the purpose: "comes into force, for the purposes of the
    # exercise of the power, on the day on which this Act is passed" (2011
    # c.19 s.38(1)); the purpose stays the statement's qualifier
    tail =
      String.replace(tail, ~r/^,\s*for\s+the\s+purposes?\s+of\s+[^,]{1,200},\s+(?=on\b)/i, "")

    case Clause.tail_date(tail, made) do
      {_, %Date{} = d} ->
        {:provision_dated, d}

      _ ->
        if Clause.by_order?(tail), do: {:provision_by_order, nil}, else: {:provision_unread, nil}
    end
  end

  # what an "except …" is relative to: the first provision named, else the
  # clause's own (a Part's, Chapter's or Schedule's id isn't a provision:
  # "Part 7 …, except regulation 73"; "Chapter 1 of Part 5 (except section
  # 116), Part 5 of Schedule 18": 2007 c.28 s.245(2))
  defp relative_base(named, base) do
    case named
         |> Enum.map(&elem(&1, 0))
         |> Enum.reject(&String.contains?(&1, [":pt.", ":sch"])) do
      [first | _] -> first
      [] -> base
    end
  end

  defp split_except(subject), do: ListItems.split_except(subject)

  @doc """
  The law's own provisions `text` names, bare ("reg.7", "pt.II"), as this
  reader names them over `rows` from the provision `base` — for checks that
  must name refs the same way (`Commencement.Leftovers`).
  """
  @spec refs_in(String.t(), [map()], String.t()) :: [String.t()]
  def refs_in(text, rows, base),
    do: text |> refs(rows, base) |> Enum.map(&(&1 |> String.split(":", parts: 2) |> List.last()))

  # the references a subject names, as section_id prefixes or containers
  defp refs(subject, rows, base),
    do: subject |> weighted_refs(rows, base) |> Enum.map(&elem(&1, 0))

  # each reference with its specificity: a named provision's is its length;
  # a Part's or Chapter's rows weigh 0, so a provision another sentence
  # names wins over its Part ("Part 7 …" vs "Regulation 73 … 2030")
  defp weighted_refs(subject, rows, base, follow? \\ true) do
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
      |> schedule_part_first()
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

  # (where the law holds it; else the regulation stays named)
  defp inward(subject, rows, base) do
    prefix = base |> provision() |> String.split(".", parts: 2) |> hd()

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

    prefix = base |> provision() |> String.split(".", parts: 2) |> hd()
    held = MapSet.new(rows, & &1.section_id)

    this = if Regex.match?(@this, subject), do: [provision(base)], else: []

    this_part = this_part_refs(subject, rows, base, law)

    nouns =
      for s <- Enum.uniq([subject, plain]),
          [_, _noun, list] <- Regex.scan(@noun, s),
          ref <- list_refs(list, prefix, rows),
          uniq: true,
          do: ref

    # "Chapter 1 of Part 6": that Chapter only; else a Part
    chapters =
      for [_, list, p] <- Regex.scan(@chapter_of_part, plain),
          c <- part_list(list),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    own_part = own_part(rows, base)

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

    mentioned = mentioned_refs(subject, rows, base, follow?)

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
            |> schedule_words()
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
    case Enum.find(rows, &(provision(&1.section_id) == provision(base))) do
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

  # (once, never from within the subsection: it naming itself would loop —
  # Petroleum Act 1998 s.52)
  defp mentioned_refs(_subject, _rows, _base, false), do: []

  defp mentioned_refs(subject, rows, base, true),
    do: subject |> mentioned_items(rows, base) |> elem(0)

  # "The provisions mentioned in subsection (3) …": those the subsection
  # lists (Competition Act 1998 s.52(2), CV-S04), each row under it read as
  # a list item — `{the provisions named, those its items except}`: "Part 7
  # above except sections 83(2) and 85", and "the repeals to the
  # Environmental Protection Act 1990, other than the repeal to section 33
  # of that Act" names no section of this Act (CNEA 2005 s.108(2)(h), (n))
  @mentioned ~r/\bprovisions\s+(?:mentioned|specified|listed|referred\s+to)\s+in\s+(?:sub-?section|paragraph)\s+\((\w+)\)/i

  defp mentioned_items(subject, rows, base) do
    items =
      for [_, n] <- Regex.scan(@mentioned, subject),
          prefix = "#{base}(#{n})",
          r <- rows,
          r.section_id == prefix or String.starts_with?(r.section_id, prefix <> "("),
          do: mentioned_item(Map.get(r, :text) || "", rows, base)

    {Enum.flat_map(items, &elem(&1, 0)), Enum.flat_map(items, &elem(&1, 1)),
     Enum.flat_map(items, &elem(&1, 2))}
  end

  # the subsection's lead-in points back to the statement, and names no
  # provision: "The provisions excepted from subsection (3)(f) are the
  # repeal of …" (1999 c.22 s.108(4))
  @mentioned_lead ~r/^\W*(?:\(\w+\)\s*)?The\s+provisions\s+(?:excepted\s+from|(?:mentioned|specified|listed|referred\s+to)\s+in)\s+(?:sub-?section|paragraph)\s+(?:\(\w+\))+\s+are\b\s*[—–:]?\s*/iu

  defp mentioned_item(text, rows, base) do
    item = @mentioned_lead |> Regex.replace(text, "") |> ListItems.read()

    # (an item's qualified provisions are partly in, never named in full:
    # "in Part 4 of Schedule 5, the repeals to …")
    named = weighted_refs(item.plain, rows, base, false)
    partly = weighted_refs(item.qualified, rows, base, false)

    excepted =
      item.excepted
      |> weighted_refs(rows, relative_base(named ++ partly, base), false)
      |> Enum.map(&elem(&1, 0))

    {named, excepted, partly}
  end

  # a Schedule's Part (and paragraph) named after the Schedule: "schedule 7,
  # Part 1, paragraph 6(c)", "schedule 8 Part 3" (SI 2013/3113 reg.1(4)) —
  # written Part first, "paragraph 6(c) of Part 1 of Schedule 7", so the
  # Part is never read as the law's own ("in Schedule 15, Part III and
  # Part V(1)" is `@in_schedule_parts`': AJA 1999 s.108(3)(f))
  @schedule_then_part ~r/(?<![Ii]n\s)\bschedule\s+(\d+[A-Z]*)\s*,?\s+Part\s+([IVXL]+|\d+[A-Z]?)(?:\s*,\s*paragraphs?\s+(\d+[A-Z]*(?:\([^)]+\))*))?/i

  @doc """
  A Schedule's Part (and paragraph) named after the Schedule written Part
  first: "schedule 7, Part 1, paragraph 6(c)" → "paragraph 6(c) of Part 1
  of Schedule 7" (SI 2013/3113 reg.1(4)), so no reader takes the Part for
  the law's own. Pure.
  """
  @spec schedule_part_first(String.t()) :: String.t()
  def schedule_part_first(subject) do
    Regex.replace(@schedule_then_part, subject, fn
      _, n, part, "" -> "Part #{part} of Schedule #{n}"
      _, n, part, para -> "paragraph #{para} of Part #{part} of Schedule #{n}"
    end)
  end

  @in_schedule_parts ~r/\bin\s+Schedule\s+(\d+[A-Z]*)\s*,\s*(Parts?\s+(?:[IVXL]+|\d+)[A-Z]?(?:\(\d+\))*(?:\s*(?:,|and)\s*(?:\(\d+\)|(?:Parts?\s+)?(?:[IVXL]+|\d+)[A-Z]?(?:\(\d+\))*))*)/
  @contained_in ~r/\bthe\s+repeal\s+of\s+[^;.]*?\bcontained\s+in\s+[^,;.]*?\bSchedule\s+\d+[A-Z]*/

  # a Schedule's Parts named after it, each as "Part X of Schedule N" ("in
  # Schedule 15, Part III and Part V(1) and (5)": AJA 1999 s.108(3)(f), a
  # Part's numbered divisions read as the Part); one repeal and where it
  # is ("the repeal of section 67(8) of the Magistrates' Courts Act 1980 …
  # contained in Part V(1) of Schedule 15": s.108(4)) names no Schedule
  defp schedule_words(subject) do
    subject = String.replace(subject, @contained_in, "")

    Regex.replace(@in_schedule_parts, subject, fn _, schedule, parts ->
      parts
      |> String.replace(~r/\(\d+\)/, "")
      |> then(&Regex.scan(~r/\b(?:[IVXL]+|\d+)[A-Z]?\b/, &1))
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.map_join(" and ", &"Part #{&1} of Schedule #{schedule}")
    end)
  end

  # "45(4)(d) and (5)(a) and 48", "17 to 21", "3, 4, 17, 21 and 23"
  defp list_refs(list, prefix, rows) do
    at = number_prefix(prefix, rows)

    tokens =
      Regex.scan(~r/(to|–|-(?=\s*\d))|(\d+[A-Z]*)((?:\([^)]+\))*)|((?:\([^)]+\))+)/, list)

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, brackets], {acc, _last, range?} ->
          ref = "#{at}#{n}#{brackets}"

          acc =
            if range? and acc != [],
              do: acc ++ range_refs(List.last(acc), ref, rows),
              else: acc ++ [ref]

          {acc, n, false}

        # "5(1) to (4)": a bracket range within the number (Petroleum Act
        # 1998 s.52(1), CV-S04)
        [_, "", "", "", brackets], {acc, last, true} when is_binary(last) and acc != [] ->
          {acc ++ bracket_range(List.last(acc), "#{at}#{last}#{brackets}"), last, false}

        [_, "", "", "", brackets], {acc, last, range?} when is_binary(last) ->
          {acc ++ ["#{at}#{last}#{brackets}"], last, range?}

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

  # the items a dash opens: the row's lettered (or roman) items, never a
  # numbered paragraph beside them where the row holds no (1) ("These
  # Regulations come into force— (a) …; (b) …" then "(2) Any provision of
  # these Regulations amending … has the same extent …": SI 2019/74 reg.2)
  defp dash_items(row, rows) do
    items = children(row, rows)
    top = for %{section_id: id} <- items, direct?(row.section_id, id), do: id
    {numbered, lettered} = Enum.split_with(top, &numbered?/1)

    if numbered != [] and lettered != [],
      do: Enum.reject(items, fn i -> Enum.any?(numbered, &covers?(&1, i.section_id)) end),
      else: items
  end

  defp direct?(parent, id), do: Regex.match?(~r/^\(\w+\)$/, String.replace_prefix(id, parent, ""))
  defp numbered?(id), do: Regex.match?(~r/\(\d+[A-Z]*\)$/, id)

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
  # how the law's rows number a provision: "art.Article 5" for EU law's
  # articles, else "art.5" ("Articles 1 and 2 shall apply from …": EUR
  # 2016/879 art.5)
  defp number_prefix(prefix, rows) do
    if Enum.any?(rows, &String.starts_with?(&1.section_id, prefix <> ".Article ")),
      do: prefix <> ".Article ",
      else: prefix <> "."
  end

  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
