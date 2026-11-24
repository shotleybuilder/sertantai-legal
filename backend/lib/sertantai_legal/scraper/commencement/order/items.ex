defmodule SertantaiLegal.Scraper.Commencement.Order.Items do
  @moduledoc """
  A commencement statement's items as refs in the commenced law's grammar:
  lists, ranges, Schedule paragraphs, and what each item relates to.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Brackets,
    Entries,
    LastItemLimit,
    OtherLaw,
    Purposes,
    RelatedList,
    SectionHeads,
    Territory,
    Words
  }

  alias SertantaiLegal.Scraper.Commencement.Text.{Asides, ScheduleParts}
  alias SertantaiLegal.Scraper.Commencement.{Rule, TextRefs}

  @relating ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+to\b|\bto\s+the\s+extent\s+that\s+(?:it|they)\s+relates?\s+to\b|\bas\s+respects\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+(?:gives?|give)\s+effect\s+to\b/i

  @doc "A statement's item lines as rules dated `date`."
  @spec item_rules([String.t()], [String.t()], Date.t(), String.t(), String.t(), String.t()) :: [
          Rule.t()
        ]
  def item_rules(lines, aliases, date, law, id, head) do
    # (a line under "in section 86—" is read as that section's: its words
    # stay the line's own)
    {rules, _sch} =
      lines
      |> RelatedList.drop_sections()
      |> SectionHeads.read()
      |> Enum.reduce({[], nil}, fn {line, read}, {acc, sch} ->
        {items, sch} = items(read, aliases, sch)

        # "section 8 (bulk supply …) as follows—" heads the items below it
        items = if heading?(line), do: [], else: items
        {acc ++ Enum.map(items, &item_rule(&1, date, law, id, head, line)), sch}
      end)

    Enum.reject(rules, &is_nil/1)
  end

  defp heading?(line), do: line =~ ~r/\bas\s+follows\s*[—–:.]?\s*$/iu

  defp item_rule(item, date, law, id, head, line) do
    case parts(item) do
      {[], _, _, _} ->
        nil

      {refs, purposes, territory, except} ->
        Rule.new(
          commences: :pending,
          scope: refs,
          except: except,
          when: {:date, date},
          territory: territory,
          purposes: purposes || limited_below(line),
          source: %{law: law, ref: Words.source_ref(id), text: Words.squash("#{head} … #{line}")},
          treatment: :order_date
        )
    end
  end

  # "section 56 (licensing of water suppliers), but— (i) in its application
  # to paragraphs 2 and 4 of Schedule 4, only in so far as …" (SI 2004/641
  # art.3(l)): the limits follow in the line's list, so the item is partial
  defp limited_below(line), do: if(line =~ ~r/,?\s+but\s*$/iu, do: :in_relation_to)

  # an item: {refs, purposes, territory}, or with the provisions it leaves out
  @doc "An item with the provisions it leaves out (none when it names none)."
  @spec parts(tuple()) :: tuple()
  def parts({refs, purposes, territory}), do: {refs, purposes, territory, []}
  def parts({_, _, _, _} = item), do: item

  # ── items in a line ─────────────────────────────────────────────────

  # "Paragraphs 1 to 27(3) and 28 to 43 of Schedule 7, and section 22(1) so
  # far as it relates thereto" (SI 1996/396): the paragraphs as read, the
  # section partly — "thereto" qualifies only the provision it follows
  # (in an aside: "paragraphs 10 to 14 of Schedule 3 (and section 44(1) so
  # far as relating thereto)": SI 1999/987; "and subsection (1) in so far as
  # it relates to those subsections": SI 2006/984)
  @thereto ~r/^(.*?),?\s+\(?and\s+((?:sub-?)?sections?\s+\S+(?:\s+and\s+\(\w+\))?)\s+(?:in\s+)?so\s+far\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+(?:thereto|to\s+th(?:ose|ese|at|is)\s+(?:sub-?)?(?:sections?|paragraphs?|provisions?))\b.*$/is

  # "in section 25 (…), subsection (1), in so far as it relates to
  # subsection (2), and subsections (2) and (4)" (SI 2004/641 art.3(h)): the
  # qualifier closes at its comma; the subsections after ", and" stand alone
  @relates_then_and ~r/^(.*?,\s+(?:in\s+)?so\s+far\s+as\s+(?:it|they)\s+relates?\s+to\s+[^,;]+?),\s+and\s+((?:sub-?)?sections?\s+\(.+)$/isu

  # a bare "subsection (1)" is the subsection of the section its line is
  # "in" ("in section 8 (…), subsections (3) to (7) and subsection (1) in so
  # far as it relates to those subsections": SI 2006/984 art.2(e))
  defp under_section(rest, section) do
    case {section =~ ~r/^sub-?sections?\b/i,
          Regex.run(~r/^\W*in\s+section\s+(\d+[A-Z]*)\b/i, rest)} do
      {true, [_, n]} -> "in section #{n}, #{section}"
      _ -> section
    end
  end

  # a line's items: [{refs, purposes, territory}] and the Schedule context
  # its paragraphs carry to the next lines
  @doc "A line's items and the Schedule context its paragraphs carry to the next lines."
  @spec items(String.t(), [String.t()], String.t() | nil) :: {[tuple()], String.t() | nil}
  def items(line, aliases, sch) do
    case Regex.run(@relates_then_and, line) do
      [_, qualified, rest] ->
        {first, next} = items(qualified, aliases, sch)
        {more, next} = items(under_section(line, rest), aliases, next)
        {first ++ more, next}

      nil ->
        thereto_items(line, aliases, sch)
    end
  end

  defp thereto_items(line, aliases, sch) do
    case Regex.run(@thereto, line) do
      [_, rest, section] ->
        {items, next} = items(rest, aliases, sch)
        qualified = TextRefs.refs(under_section(rest, section), nil)

        if qualified == [],
          do: {items, next},
          else: {items ++ [{qualified, :in_relation_to, Territory.of(line)}], next}

      nil ->
        last_limit_items(line, aliases, sch)
    end
  end

  # "Sections 86(2), … and 96(2) and (3) of the Act, and section 162(1) of
  # the Act in so far as it relates to paragraphs 10(3) … of Schedule 15"
  # (SI 1991/96 reg.2): the limit is the last item's, the items before it
  # come in fully
  defp last_limit_items(line, aliases, sch) do
    whole = line_items(line, aliases, sch)

    case LastItemLimit.split(line) do
      {before, last} -> split_items(before, last, aliases, sch) |> keeping(whole)
      nil -> whole
    end
  end

  @doc "The items of a line's head and its limited last part."
  @spec split_items(String.t(), String.t(), [String.t()], String.t() | nil) ::
          {[tuple()], String.t() | nil}
  def split_items(before, last, aliases, sch) do
    {items, next} = items(before, aliases, sch)
    {limited, next} = line_items(last, aliases, next)
    {items ++ limited, next}
  end

  # the split reading only where it names every provision the line read
  # whole names ("…, and section 184 and paragraph 7 of that Schedule in so
  # far as they relate to those paragraphs": WSI 2006/345 — "that Schedule"
  # is lost apart from its list)
  defp keeping({items, _} = split, {whole_items, _} = whole) do
    if item_refs(whole_items) -- item_refs(items) == [], do: split, else: whole
  end

  defp item_refs(items), do: Enum.flat_map(items, &(&1 |> parts() |> elem(0)))

  # "in Part 2 of Schedule 15 (…) the entries relating to—", "Part 1(A) (…)
  # of Schedule 15": that Part, partly (SI 2007/709)
  defp line_items(line, aliases, sch) do
    case ScheduleParts.partial_ref(line) || Entries.head_ref(line) do
      nil -> entry_line_items(line, aliases, sch)
      part -> {[{[part], :in_relation_to, Territory.of(line)}], sch}
    end
  end

  # "The entries relating to Schedule 2, Schedule 3 and Schedule 6 of the
  # Railways Act 1993.": an entry of the repeals Schedule its head names,
  # never the Act's own provisions (SI 2005/1909 Sch.)
  defp entry_line_items(line, aliases, sch) do
    if Entries.entry?(line), do: {[], sch}, else: schedule_line_items(line, aliases, sch)
  end

  defp schedule_line_items(line, aliases, sch) do
    case Regex.run(Words.schedule_entries(), line) do
      # "In Schedule 18, the repeals to …": those entries of that Schedule —
      # and the line's own provisions after them ("… and section 196
      # insofar as it relates to that repeal": SI 2006/1680); "In the
      # Schedule—the entries relating to sections 11 to 14 … of … the
      # Firearms (Amendment) Act 1997" describes the entries only (SI
      # 1997/3114)
      [_, n, kind, rest] ->
        ref = if n == "", do: "sch", else: "sch.#{n}"

        {items, _} =
          if kind =~ ~r/^entr/i, do: {[], sch}, else: own_line_items(rest, aliases, sch)

        {[{[ref], :in_relation_to, Territory.of(line)} | items], sch}

      nil ->
        own_line_items(line, aliases, sch)
    end
  end

  # (an item's bracketed heading is no territory and no purpose of its own:
  # "section 86 (water and sewerage undertakers in England: …)", SI 2022/48)
  defp own_line_items(line, aliases, sch) do
    line = line |> OtherLaw.drop_other_laws(aliases) |> Asides.drop_headings()

    case Brackets.bracket_items(line) do
      nil -> plain_line_items(line, aliases, sch)
      items -> {items, next_context(line, sch)}
    end
  end

  # "section 34 (the Authority) except in so far as subsection (2) gives
  # effect to Schedule 1 for the purposes of …" (SI 2005/2714 art.4(a)): the
  # section fully but that subsection, the subsection partly
  @except_in_so_far ~r/^(.*?),?\s+except\s+(?:in\s+)?so\s+far\s+as\s+(?:sub-?)?section\s+((?:\([0-9A-Za-z]+\))+)\s+\S/iu

  defp plain_line_items(line, aliases, sch) do
    with [_, own, sub] <- Regex.run(@except_in_so_far, line),
         [ref] <- TextRefs.refs(Asides.strip(own), sch),
         true <- ref =~ ~r/^s\.\d+[A-Z]*$/ do
      territory = Territory.of(line)
      {[{[ref], nil, territory, [ref <> sub]}, {[ref <> sub], :in_relation_to, territory}], sch}
    else
      _ -> plain_items(line, aliases, sch)
    end
  end

  # (an undertaker's place is the place: "section 3 (…), so far as relating
  # to undertakers whose areas are wholly or mainly in England" — SI
  # 2025/726 reg.2 — England's, as Decision 11 reads "wholly or mainly
  # English undertakers")
  @undertakers_place ~r/,?\s*(?:(?:in\s*)?so\s*far\s+as\s+(?:it\s+relates|they\s+relate|relating)\s+to|in\s+relation\s+to)\s+undertakers\s+whose\s+areas\s+are\s+wholly\s+or\s+mainly\s+in\s+(?:England|Wales)\s*(?=[;,.]|$)/iu

  defp plain_items(line, _aliases, sch) do
    # (the rest of it, for one place: "Schedule 8 in so far as it relates to
    # England and Wales and has not already been commenced", SI 1992/2984)
    {line, place} = Territory.completing(line)
    territory = place || Territory.of(line)
    line = String.replace(line, @undertakers_place, "")
    {own, related} = split_related(line)
    sch = line |> ScheduleParts.as_place() |> schedule_context(sch)
    {own, excepted} = split_excepted(own, sch)
    own_refs = own_refs(own, related, sch)

    items =
      with "" <- related,
           items when is_list(items) <- bare_items(own, sch, territory) do
        items
      else
        _ ->
          purposes = own_purposes(line, related)

          [
            own_item(own, own_refs, excepted, purposes, territory)
            | related_items(related, sch, territory)
          ]
      end

    {items, next_context(line, sch)}
  end

  # "section 120(1) in so far as it relates to the following paragraphs of
  # Schedule 22": the section partly, the paragraphs fully
  defp split_related(line) do
    case Regex.split(@relating, line, parts: 2) do
      [own, related] -> {own, related}
      [own] -> {own, ""}
    end
  end

  # "Part I of the 1998 Act except section 4" (SI 1998/1658); "Chapter 6 …
  # of Part 5 …, except for sections 85 to 87" (WSI 2018/35): the Part,
  # the section excepted — never both commenced (CV-06 round 2)
  defp split_excepted(own, sch) do
    case Regex.split(
           ~r/\s*,?\s+except(?:\s+for)?\s+(?=(?:sections?|regulations?|articles?)\s+\d)/i,
           own,
           parts: 2
         ) do
      [main, ex] -> {main, TextRefs.refs(Asides.strip(ex), sch)}
      [_] -> {own, []}
    end
  end

  # "… the following paragraphs of Schedule 22— 1, 3, 5 to 12": a bare
  # list on the line, or a line of only numbers under such a heading
  defp own_refs(own, related, sch) do
    TextRefs.refs(Asides.strip(own), sch) ++
      if(related == "", do: bare_paragraphs(own, sch), else: [])
  end

  # (a place alone is the territory, never a purpose: "section 69 (…), in
  # so far as it applies in relation to England" — SI 2004/641 art.2(a);
  # "… in so far as they extend to England and Wales" — SI 2000/800 art.2 —
  # so England's and Wales's days together bring it fully in)
  @place_only ~r/,?\s*(?:(?:in\s*)?so\s*far\s+as\s+(?:it|they)\s+(?:(?:applies|apply|extends?)\s+(?:in\s+relation\s+to|as\s+respects)|extends?\s+to)|in\s+relation\s+to|as\s+respects)\s+(?:England\s+and\s+Wales|Great\s+Britain|England|Wales|Scotland|Northern\s+Ireland)(?:\s+only)?\s*(?=[;,.]|$)/iu

  defp own_purposes(line, "") do
    words = line |> String.replace(Words.full(), "") |> String.replace(@place_only, "")
    if Regex.match?(Words.partial(), words), do: Purposes.purposes(words)
  end

  defp own_purposes(_line, related), do: Purposes.purposes(related)

  defp own_item(own, own_refs, excepted, purposes, territory) do
    case {excepted, Purposes.except_subsections(own, own_refs)} do
      {[_ | _], _} -> {own_refs, nil, territory, excepted}
      {[], nil} -> {own_refs, purposes, territory}
      {[], except} -> {own_refs, nil, territory, except}
    end
  end

  # what the section relates to: a bare list with its items' own
  # qualifiers, else the refs named
  defp related_items("", _sch, _territory), do: []

  defp related_items(related, sch, territory) do
    context = schedule_context(related, sch)

    case bare_items(related, context, territory) do
      items when is_list(items) ->
        items

      _ ->
        refs = TextRefs.refs(Asides.strip(related), context) ++ bare_paragraphs(related, sch)
        related_ref_items(related, refs, territory)
    end
  end

  defp related_ref_items(_related, [], _territory), do: []

  defp related_ref_items(related, refs, territory) do
    cond do
      Regex.match?(Words.entries_head(), related) ->
        [{refs, :in_relation_to, territory}]

      # "… paragraphs 142, 143 … of Schedule 22 in so far as the amendments
      # made by those provisions confer any power to make regulations"
      # (SI 1996/2909): the paragraphs carry that qualifier
      # (never "(in so far as those provisions are not already in force)")
      paragraphs?(refs) ->
        paragraph_items(related, refs, territory)

      true ->
        []
    end
  end

  # the paragraphs a section relates to, each with its own aside: "paragraphs
  # 1, 2 (except sub-paragraphs (2) and (9)(b)), 3 to 7, … 35 (insofar as it
  # adds …), 36 … of Schedule 10" — paragraph 2 less those, 35 partly, the
  # rest as the list's own qualifier has them (SI 1995/2950 art.2(1))
  defp paragraph_items(related, refs, territory) do
    rest =
      related
      |> String.replace(~r/^.*?\bof\s+Schedule\s+\d+[A-Z]*/is, "")
      |> String.replace(Words.full(), "")

    asides = paragraph_asides(related, refs)
    except = for {ref, aside} <- asides, e <- Purposes.excepted(ref, aside), do: e

    partial =
      for {ref, aside} <- asides,
          Purposes.excepted(ref, aside) == [],
          Purposes.partial?(aside),
          do: ref

    purposes = if(Regex.match?(Words.partial(), rest), do: Purposes.purposes(rest))

    [{refs -- partial, purposes, territory, except}] ++
      if(partial == [], do: [], else: [{partial, :in_relation_to, territory}])
  end

  # {a paragraph the list names, its aside}: only where the list is of one
  # Schedule's paragraphs
  defp paragraph_asides(related, refs) do
    case Enum.uniq(for r <- refs, do: String.replace(r, ~r/(?<=\.para\.).*$/, "")) do
      [prefix] ->
        for {n, aside} <- Asides.items(related),
            (prefix <> n) in refs,
            do: {prefix <> n, aside}

      _ ->
        []
    end
  end

  # a bare list of a Schedule's paragraphs whose items carry their own
  # qualifiers ("1, 3, … 29(1) in so far as it is not already in force, 30,
  # 32 to 35": SI 1996/186 reg.3, CV-S04 round 2) — each item its own, never
  # one item's qualifier over the list; nil for any other text
  @item_qualifier ~r/\s+(?:(?:in\s+)?so\s*far\s+as|to\s+the\s+extent|except|for\s+the\s+purposes?\s+of|in\s+relation\s+to)\b.*$/is

  defp bare_items(text, sch, territory) do
    if sch && text =~ ~r/^\s*\d/ &&
         (Regex.match?(Words.partial(), text) or Regex.match?(Words.full(), text)) do
      for item <- split_items(text),
          plain = Regex.replace(@item_qualifier, item, ""),
          refs = TextRefs.list_refs(Asides.strip(plain), "sch.#{sch}.para."),
          refs != [] do
        qualifier = String.trim_leading(String.replace_prefix(item, plain, ""))

        {refs, Purposes.of_qualifier(qualifier), territory}
      end
    end
  end

  # a line whose bracket is still open goes on in the next: legislation.gov.uk
  # splits one item across list items inside its aside ("… section 31(2)(b)
  # of the Control of" | "Pollution Act 1974) and (3), 20, …": SI 1991/1042
  # art.2(1), CV-S09 round 6)
  @doc "Lines whose bracket is still open joined to the line that closes it."
  @spec join_open([String.t()]) :: [String.t()]
  def join_open(lines) do
    lines
    |> Enum.reduce([], fn
      line, [prev | rest] = acc ->
        if open?(prev), do: [prev <> " " <> line | rest], else: [line | acc]

      line, [] ->
        [line]
    end)
    |> Enum.reverse()
  end

  defp open?(line),
    do: length(String.split(line, "(")) > length(String.split(line, ")"))

  # the items of a list at its top-level commas and semicolons
  def split_items(text) do
    {items, cur, _} =
      text
      |> String.graphemes()
      |> Enum.reduce({[], "", 0}, fn
        "(", {is, c, d} -> {is, c <> "(", d + 1}
        ")", {is, c, d} -> {is, c <> ")", max(d - 1, 0)}
        sep, {is, c, 0} when sep in [",", ";"] -> {[c | is], "", 0}
        ch, {is, c, d} -> {is, c <> ch, d}
      end)

    [cur | items] |> Enum.reverse() |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  @doc "True when every ref is a Schedule's."
  @spec paragraphs?([String.t()]) :: boolean()
  def paragraphs?(refs), do: Enum.all?(refs, &String.starts_with?(&1, "sch."))

  defp bare_paragraphs(text, sch) do
    case Regex.run(
           ~r/\bfollowing\s+paragraphs\s+of\s+Schedule\s+(\d+[A-Z]*)\s*[—–:]\s*(.+)$/iu,
           text
         ) do
      [_, s, list] ->
        TextRefs.list_refs(Asides.strip(list), "sch.#{s}.para.")

      nil ->
        if sch && text =~ ~r/^\s*\d/,
          do: TextRefs.list_refs(Asides.strip(text), "sch.#{sch}.para."),
          else: []
    end
  end

  # the Schedule a line's bare paragraphs belong to
  defp schedule_context(line, sch) do
    cond do
      m = Regex.run(~r/\bparagraphs?\b.*?\bof\s+Schedule\s+(\d+[A-Z]*)/i, line) ->
        Enum.at(m, 1)

      m = Regex.run(~r/\bprovisions\s+(?:of|in)\s+Schedule\s+(\d+[A-Z]*)\s*[—–:]/iu, line) ->
        Enum.at(m, 1)

      # "Schedule 6, paragraphs 18(1), (3) and (5), … and 20" (a table row: SI 1997/1082)
      m = Regex.run(~r/\bSchedule\s+(\d+[A-Z]*)\s*,\s*paragraphs?\b/i, line) ->
        Enum.at(m, 1)

      m = Regex.run(~r/\bin\s+Schedule\s+(\d+[A-Z]*)\b/i, line) ->
        Enum.at(m, 1)

      line =~ ~r/^\s*(?:sections?|in\s+section)\b/i ->
        nil

      true ->
        sch
    end
  end

  # the context for the next lines: set by "the following paragraphs of
  # Schedule N—", or "the provisions of Schedule 6 to the Act referred to in
  # sub-paragraphs (b) to (s) below" (SI 2003/272 art.2(a))
  @heads_paragraphs ~r/\bfollowing\s+paragraphs\s+of\s+Schedule\s+(\d+[A-Z]*)|\bprovisions\s+of\s+Schedule\s+(\d+[A-Z]*)\b[^;]*?\b(?:referred\s+to|specified|mentioned|listed|set\s+out)\s+in\s+(?:sub-?)?paragraphs?\b[^;]*?\bbelow\b/i

  defp next_context(line, sch) do
    case Regex.run(@heads_paragraphs, line) do
      [_ | found] -> Enum.find(found, &(&1 != ""))
      nil -> if line =~ ~r/^\s*(?:sections?|in\s+section)\b/i, do: nil, else: sch
    end
  end
end
