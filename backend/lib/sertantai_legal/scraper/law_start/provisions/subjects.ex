defmodule SertantaiLegal.Scraper.LawStart.Provisions.Subjects do
  @moduledoc """
  A sentence's subject and a list's items as groups, each with its qualifiers and exceptions ("Sections 33, 34, 41 and (in so far as …) 42"). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{ListItems, NestedItems}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Mentioned, Refs, Treatment, Words}

  @qualified Words.qualified()

  # a provision that only names a statement's purpose, before its subject
  # ("In relation to an offence under regulation 3(2), regulations 6 to 8
  # come into force …": SI 2017/1312 reg.1(4)), is not in its scope
  @leading_purpose ~r/^\W*(?:\(\w+\)\s*)?(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|in\s+the\s+case\s+of|as\s+respects)\s+[^,;]+,\s*(?=(?:the\s+)?(?:sections?|regulations?|articles?|rules?|paragraphs?|Parts?|Chapters?|Schedules?)\b)/i

  # a list read item by item (`LawStart.ListItems`): the provisions its
  # items name in full, and those their own qualifiers leave partly in
  @doc "A list read item by item: the provisions its items name in full, and those their qualifiers leave partly in."
  @spec list_groups(map(), String.t(), String.t(), String.t(), map(), [map()], String.t()) ::
          [map()]
  def list_groups(g, subject, tail, inline, row, rows, base) do
    {head, before} = head_and_items(subject)
    {head, aside} = ListItems.head_aside(head)

    # (the rows nested under a dash-ended item are that item's:
    # `LawStart.NestedItems`)
    {flat, nested} = row |> Refs.children(rows) |> NestedItems.fold()

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
        Enum.flat_map(
          [aside | Enum.map(items, & &1.qualified)],
          &Refs.weighted_refs(&1, rows, base)
        )
      )

    # a list whose items are all qualified is only the qualified group
    [named |> Treatment.classify(head <> " " <> tail) |> beside(listed), listed]
    |> Enum.reject(&(&1.treatment == :provision_qualified and &1.refs == []))
    |> Enum.reject(&(&1.kind == :unread and not plain? and qualified?))
  end

  @doc "A subject's groups: named in full, and qualified."
  @spec subject_groups(map(), String.t(), String.t(), String.t(), [map()], String.t()) :: [map()]
  def subject_groups(g, sentence, subject, tail, rows, base) do
    case bracket_qualified(subject) || trailing_qualified(subject) ||
           ListItems.qualified_last(subject) do
      {plain, qualified} ->
        # "regulations 2, 5, 10 and 11, and, so far as they relate to …,
        # regulations 3, 6 and 7": the qualifier is only the later items'
        named = %{g | refs: Refs.weighted_refs(plain, rows, base)}
        listed = partly(g, Refs.weighted_refs(qualified, rows, base))

        [named |> Treatment.classify(plain <> " " <> tail, plain) |> beside(listed), listed]
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
    named = Refs.weighted_refs(item.plain, rows, base)

    {refs ++ named,
     excluded ++ Refs.refs(item.excepted, rows, Treatment.relative_base(named, base))}
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
      nil -> leading_except(subject) || Refs.split_except(subject)
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
    refs = subject_in |> String.replace(@leading_purpose, "") |> Refs.weighted_refs(rows, base)

    # "Regulation 26, with the exception of paragraph (4)": relative to
    # what the subject names
    {_named, excepted, _partly} = Mentioned.mentioned_items(subject_in, rows, base)
    excluded = Refs.refs(subject_out, rows, Treatment.relative_base(refs, base)) ++ excepted

    [Treatment.classify(%{g | refs: refs, excluded: excluded}, sentence, subject)]
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
end
