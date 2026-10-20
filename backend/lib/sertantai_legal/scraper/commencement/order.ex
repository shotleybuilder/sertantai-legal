defmodule SertantaiLegal.Scraper.Commencement.Order do
  @moduledoc """
  A commencement order as rules (commencement-rules CR-04): what the order
  brings into force of the law it commences, when, where and how far.

  Statements read (an article or paragraph whose own words carry them):

  - "<items> come(s) into force on <date>" — the items inline ("Sections 17
    to 22 of, and Schedule 4 to, the Act …") or listed below ("The following
    provisions … come into force on 1st October 2006— section 1(4); …");
  - "<date> is the day appointed for the coming into force of <items>";
  - a Schedule table of provisions and purposes, dated by its title or by
    the article that brings it in.

  Items: sections (lists, ranges, subsections: "in section 61, subsection
  (6)"), Schedules, "paragraphs … of Schedule N" (or under "the following
  paragraphs of Schedule N—", or "in Schedule N to the Act, paragraphs …").
  "Section 120(1) in so far as it relates to the following paragraphs of
  Schedule 22" brings those paragraphs in fully and the section partly. "So
  far as not already in force" / "for all (remaining) purposes" is full; any
  other "so far as" / "for the purposes of" / "except" is partial (the four
  purposes); "in relation to Wales" is the territory. Another law's
  provisions ("section 70 of the Transport Act 1962") are never the Act's.

  Refs in the commenced law's grammar: "s.17..s.22", "s.36(3)", "sch.4",
  "sch.10.para.3..sch.10.para.6", "sch.21.para.2(1)". `ref/1` turns an
  amending provision's CLML id into one; `context/0` gives the evaluator
  the Schedule a paragraph belongs to. Pure: the order and the Act's
  identity come in.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc, Text}
  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.LawStart.Clause

  @type act :: %{law: String.t(), title: String.t() | nil, year: String.t()}

  @cif ~r/\b(?:shall\s+)?(?:come|comes)\s+into\s+(?:force|operation)\b/i
  @appointed ~r/\bis\s+the\s+(?:day|date)\s+appointed\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i
  @full ~r/\b(?:so|in so|insofar|in as)\s*far\s+as\s+(?:it|they|that\s+[\w-]+)\s+(?:has|have|is|are)\s+not\s+(?:already|previously|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force)|so\s+far\s+as\s+not\s+(?:already|previously|yet)\s+in\s+force|for\s+all\s+(?:remaining\s+|other\s+)?purposes/i
  @relating ~r/\b(?:so|in so|insofar)\s*far\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+to\b|\bto\s+the\s+extent\s+that\s+(?:it|they)\s+relates?\s+to\b|\bas\s+respects\b|\b(?:so|in so|insofar)\s*far\s+as\s+(?:it|they)\s+(?:gives?|give)\s+effect\s+to\b/i
  @partial ~r/\b(?:so|in so|insofar)\s*far\s+as\b|\bto\s+the\s+extent\b|\bfor\s+the\s+purposes?\s+(?:only\s+)?of\b|\bfor\s+(?:specified|certain|limited|particular)\s+purposes\b|\bexcept\b|\bsave\b|\bin\s+relation\s+to\b/i
  @places %{
    "england and wales" => "E+W",
    "great britain" => "E+W+S",
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI"
  }

  @doc "The rules an order states for the law `act` it commences ([] when it doesn't commence it)."
  @spec rules(Doc.t(), act()) :: [Rule.t()]
  def rules(%Doc{} = order, act) do
    if commences?(order, act) do
      aliases = aliases(order, act)

      type_territory = type_territory(order.law_name) || title_territory(order)

      (statements(order, aliases) ++ tables(order, act))
      |> Enum.map(fn r ->
        %{r | commences: act.law, territory: r.territory || head_territory(r) || type_territory}
      end)
    else
      []
    end
  end

  @doc "An amending provision's CLML id as a ref: \"section-36-3\" → \"s.36(3)\", \"schedule-11-paragraph-137-a\" → \"sch.11.para.137(a)\"."
  @spec ref(String.t()) :: String.t() | nil
  def ref(id) do
    case String.split(id, "-") do
      ["schedule", s, "paragraph", p | subs] ->
        "sch.#{s}.para.#{p}" <> brackets(subs)

      # a Part of a Schedule (AR-12: "Section 9 and Part III of Schedule 4")
      ["schedule", s, "part", p | _] ->
        "sch.#{s}.pt.#{p}"

      ["schedule", s | _] ->
        "sch.#{s}"

      [kind, n | subs] when kind in ~w(section regulation article) ->
        "#{prefix(kind)}.#{n}" <> brackets(subs)

      _ ->
        nil
    end
  end

  @doc "The evaluator's context for an amending law's refs: a Schedule paragraph sits in its Schedule."
  @spec context() :: map()
  def context do
    %{
      ancestors: fn ref ->
        case Regex.run(~r/^(sch\.[^.]+)\.para\./, ref) do
          [_, sch] -> [sch]
          nil -> []
        end
      end
    }
  end

  @doc "The law's title from its own CLML (`dc:title`), without the year: for an Act `uk_lrt` doesn't hold."
  @spec title(Doc.t()) :: String.t() | nil
  def title(doc) do
    case full_title(doc) do
      nil -> nil
      t -> t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()
    end
  end

  defp full_title(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      case root
           |> xpath(
             ~x"//*[local-name()='title' and namespace-uri()='http://purl.org/dc/elements/1.1/']/text()"s
           )
           |> to_string() do
        "" -> nil
        t -> t
      end
    end)
  end

  # ── does the order commence the Act ─────────────────────────────────

  defp commences?(order, act) do
    case DefinedTerms.of(order)["the act"] do
      %{law: law} when is_binary(law) -> law == act.law
      %{title: t} when is_binary(t) -> named?(t, act)
      _ -> Enum.any?(order.ids, &named?(Text.words_of(order, &1), act))
    end
  end

  defp named?(text, %{title: title, year: year}) when is_binary(title),
    do: String.contains?(norm(text), norm("#{title} #{year}"))

  defp named?(_text, _act), do: false

  # the ways the order names the Act: "the Act", a term meaning it ("the
  # 2006 Act"), its title
  defp aliases(order, act) do
    terms =
      for {term, %{law: l, title: t}} <- DefinedTerms.of(order),
          l == act.law or (is_binary(t) and named?(t, act)),
          do: term

    Enum.uniq(
      ["the act" | terms] ++ if(act.title, do: [norm("#{act.title} #{act.year}")], else: [])
    )
  end

  # ── statements in articles ──────────────────────────────────────────

  # an article (or paragraph) whose own words state a commencement: its
  # first such line is the statement, the lines below are its items
  defp statements(order, aliases) do
    made = made(order)

    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
        words = Text.words_of(order, id),
        Regex.match?(@cif, words) or Regex.match?(@appointed, words),
        lines = order |> Doc.element(id) |> Doc.lines() |> Enum.map(&clean_line/1),
        {pre, head, rest} = split_head(lines),
        head != nil,
        {date, inline} <- List.wrap(statement(head, made)),
        items = Enum.reject(pre ++ [clean_line(inline) | rest], &(&1 == "")),
        rule <- item_rules(items, aliases, date, order.law_name, id, head),
        do: rule
  end

  # {items before the statement, the statement line, the lines after}: an
  # older order lists its items first and states the date last ("The
  # following provisions of the … Act 1981, namely— (a) Part I …; (b) …
  # shall come into force on 28th September 1982": CR-07, SI 1982/1217)
  defp split_head(lines) do
    case Enum.split_while(lines, &(not (Regex.match?(@cif, &1) or Regex.match?(@appointed, &1)))) do
      {before, [head | rest]} ->
        case Enum.split_while(before, &(not (&1 =~ ~r/\b(?:namely|the following)\b/i))) do
          {_, [_header | items]} -> {items, head, Enum.reject(rest, &(&1 == ""))}
          _ -> {[], head, Enum.reject(rest, &(&1 == ""))}
        end

      _ ->
        {[], nil, []}
    end
  end

  # {date, the items stated inline} | nil
  defp statement(head, made) do
    cond do
      Regex.match?(@appointed, head) ->
        [before, after_] = Regex.split(@appointed, head, parts: 2)
        with [d] <- parse_dates(before), do: {d, after_}, else: (_ -> nil)

      Regex.match?(@cif, head) ->
        [subject, tail] = Regex.split(@cif, head, parts: 2)

        # a list after the dash on the same line ("… on 21st September 1995—
        # section 116 …") is inline too
        after_dash =
          case Regex.split(~r/[—–:]\s*/u, tail, parts: 2) do
            [_, rest] -> rest
            _ -> ""
          end

        case tail_date(tail, made) do
          nil ->
            nil

          d ->
            {d,
             if(subject =~ ~r/\bthe following\b/i,
               do: after_dash,
               else: subject <> " " <> after_dash
             )}
        end

      true ->
        nil
    end
  end

  # a statement's date: one stated, else counted from the order's making
  # ("the day after this Order is made": LR-33's reading)
  defp tail_date(tail, made) do
    case parse_dates(tail) do
      [d] ->
        d

      [] ->
        t = tail |> String.split(~r/[—–:]/u, parts: 2) |> hd() |> String.trim()
        t = if t =~ ~r/^on\b/i, do: t, else: "on " <> t

        case Clause.tail_date(t, made) do
          {_, %Date{} = d} -> d
          _ -> nil
        end

      _ ->
        nil
    end
  end

  # the order's made date (CLML metadata)
  defp made(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      with d when d != "" <- root |> xpath(~x"//*[local-name()='Made']/@Date"s) |> to_string(),
           {:ok, date} <- Date.from_iso8601(d) do
        date
      else
        _ -> nil
      end
    end)
  end

  # a line's leading number label and the next item's trailing label ("… of— a")
  defp clean_line(line) do
    line
    |> String.replace(~r/^\(?\d+[A-Z]?\)?(?:\s+\(?\d+\)?)?\s+(?=[A-Z])/u, "")
    |> String.replace(
      ~r/[;,—–:]?\s*(?:and|or)?\s*\(?(?:[a-z]{1,2}|[ivx]{1,5}|\d{1,2})\)?\.?\s*$/u,
      fn m ->
        if m =~ ~r/[;—–:]/u, do: "", else: m
      end
    )
    |> String.trim()
  end

  defp item_rules(lines, aliases, date, law, id, head) do
    {rules, _sch} =
      Enum.reduce(lines, {[], nil}, fn line, {acc, sch} ->
        {items, sch} = items(line, aliases, sch)

        # "section 8 (bulk supply …) as follows—" heads the items below it
        items = if heading?(line), do: [], else: items
        {acc ++ Enum.map(items, &item_rule(&1, date, law, id, head, line)), sch}
      end)

    Enum.reject(rules, &is_nil/1)
  end

  defp heading?(line), do: line =~ ~r/\bas\s+follows\s*[—–:.]?\s*$/iu

  defp item_rule({[], _purposes, _territory}, _date, _law, _id, _head, _line), do: nil

  defp item_rule({refs, purposes, territory}, date, law, id, head, line) do
    Rule.new(
      commences: :pending,
      scope: refs,
      when: {:date, date},
      territory: territory,
      purposes: purposes,
      source: %{law: law, ref: source_ref(id), text: squash("#{head} … #{line}")},
      treatment: :order_date
    )
  end

  # ── items in a line ─────────────────────────────────────────────────

  # a line's items: [{refs, purposes, territory}] and the Schedule context
  # its paragraphs carry to the next lines
  defp items(line, aliases, sch) do
    line = drop_other_laws(line, aliases)
    territory = territory(line)

    # "section 120(1) in so far as it relates to the following paragraphs of
    # Schedule 22": the section partly, the paragraphs fully
    {own, related} =
      case Regex.split(@relating, line, parts: 2) do
        [own, related] -> {own, related}
        [own] -> {own, ""}
      end

    sch = schedule_context(line, sch)

    # "… the following paragraphs of Schedule 22— 1, 3, 5 to 12": a bare
    # list on the line, or a line of only numbers under such a heading
    own_refs =
      refs(strip_parentheticals(own), sch) ++
        if(related == "", do: bare_paragraphs(own, sch), else: [])

    related_refs =
      refs(strip_parentheticals(related), schedule_context(related, sch)) ++
        bare_paragraphs(related, sch)

    own_purposes =
      cond do
        related != "" ->
          purposes(related)

        Regex.match?(@full, line) and not Regex.match?(@partial, Regex.replace(@full, line, "")) ->
          nil

        Regex.match?(@partial, Regex.replace(@full, line, "")) ->
          purposes(line)

        true ->
          nil
      end

    related_item =
      if related_refs != [] and paragraphs?(related_refs),
        do: [{related_refs, nil, territory}],
        else: []

    {[{own_refs, own_purposes, territory} | related_item], next_context(line, sch)}
  end

  defp paragraphs?(refs), do: Enum.all?(refs, &String.starts_with?(&1, "sch."))

  defp bare_paragraphs(text, sch) do
    case Regex.run(
           ~r/\bfollowing\s+paragraphs\s+of\s+Schedule\s+(\d+[A-Z]*)\s*[—–:]\s*(.+)$/iu,
           text
         ) do
      [_, s, list] ->
        list_refs(strip_parentheticals(list), "sch.#{s}.para.")

      nil ->
        if sch && text =~ ~r/^\s*\d/,
          do: list_refs(strip_parentheticals(text), "sch.#{sch}.para."),
          else: []
    end
  end

  defp purposes(text) do
    cond do
      text =~
          ~r/\bmak(?:e|ing)\s+(?:regulations|an?\s+order|orders|rules|subordinate\s+legislation)\b|\bconfers?\s+(?:a\s+)?power\b/i ->
        :for_making_secondary_legislation

      text =~ ~r/\bspecified\s+purposes\b/i ->
        :for_specified_purposes

      true ->
        :in_relation_to
    end
  end

  defp territory(line) do
    case Regex.run(
           ~r/\b(?:in relation to|in|as respects)\s+(England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\b(?!\s+(?:Act|Order|Regulations))/i,
           line
         ) do
      [_, place] -> Map.get(@places, String.downcase(place))
      nil -> nil
    end
  end

  # a statement's own place ("… come into force in relation to England on …")
  # reaches all its items
  defp head_territory(%Rule{source: %{text: text}}) when is_binary(text),
    do: text |> String.split(" … ", parts: 2) |> hd() |> territory()

  defp head_territory(_rule), do: nil

  # a devolved instrument commences in relation to its own territory (a
  # Welsh order made by the Welsh Ministers: Wales)
  defp type_territory(law_name) do
    case law_name |> String.split("_") |> Enum.at(1) do
      "wsi" -> "W"
      "ssi" -> "S"
      "nisr" -> "NI"
      _ -> nil
    end
  end

  # an order made for one territory says so in its title: "The Environment
  # Act 1995 (Commencement No. 16 …) (England) Order 2000" (SI 2000/340)
  defp title_territory(order) do
    case Regex.run(
           ~r/\((England and Wales|England|Wales|Scotland|Northern Ireland)\)\s+(?:Order|Regulations)\b/,
           full_title(order) || ""
         ) do
      [_, place] -> Map.get(@places, String.downcase(place))
      nil -> nil
    end
  end

  # "(so far as not already in force)", "(which introduces Schedule 4)",
  # "(codes of conduct)": asides, not refs
  defp strip_parentheticals(text), do: String.replace(text, ~r/\((?:[^()]*\s[^()]*)\)/u, "")

  # a line naming another law's provisions keeps only the Act's
  defp drop_other_laws(line, aliases) do
    Regex.replace(
      ~r/\b(?:sections?|paragraphs?|Schedules?|regulations?|articles?)\s+\d+[A-Z]*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)*(?:\s*\([^()]*\))?,?\s+(?:of|to|into)\s+(?:the\s+)?((?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,10}(?:(?:of|and|for|the|in|on)\s+(?:[A-Z][\w()',-]*\s+){1,8})*(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)/u,
      line,
      fn whole, law ->
        if Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
             norm(law) in ["act", "the act"],
           do: whole,
           else: ""
      end
    )
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

  # the context for the next lines: set by "the following paragraphs of Schedule N—"
  defp next_context(line, sch) do
    case Regex.run(~r/\bfollowing\s+paragraphs\s+of\s+Schedule\s+(\d+[A-Z]*)/i, line) do
      [_, s] -> s
      nil -> if line =~ ~r/^\s*(?:sections?|in\s+section)\b/i, do: nil, else: sch
    end
  end

  # not the order's own Schedule ("Schedule 1 to this Order")
  @own ~S"(?!\s+to\s+th(?:is|ese)\s)"

  @list ~S"((?:(?:\s*(?:,|and|to|–|-)\s*)?(?:\d+[A-Z]*(?:\([0-9A-Za-z]+\))*|\([0-9A-Za-z]+\)(?:\([0-9A-Za-z]+\))*))+)"

  defp refs(text, sch) do
    {of_section, text} = subsections_of(text)

    sections =
      for [_, list] <- Regex.scan(~r/\bsections?\s+#{@list}/i, text),
          r <- list_refs(list, "s."),
          do: r

    # "in section 61, subsection (6) and subsection (1)"
    subsections =
      case Regex.run(~r/\bin\s+section\s+(\d+[A-Z]*)\s*,\s*(.*)$/i, text) do
        [_, n, rest] ->
          for [_, b] <- Regex.scan(~r/\bsub-?sections?\s+((?:\([0-9A-Za-z]+\))+)/i, rest),
              do: "s.#{n}#{b}"

        nil ->
          []
      end

    # a wrapped list's tail "… 28, 29 and 30 of Schedule 15" (its "paragraphs"
    # on the line before: SI 1991/1042): those paragraphs
    bare =
      for [_, list, n] <-
            Regex.scan(
              ~r/(?<![Ss]ections\s)(?<![Ss]ection\s)((?:\d+[A-Z]*(?:\([0-9A-Za-z]+\))*\s*(?:,|and)\s*)+\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s+of\s+Schedule\s+(\d+[A-Z]*)/,
              text
            ),
          not (text =~ ~r/\b(?:paragraphs?|sections?)\b/i),
          r <- list_refs(list, "sch.#{n}.para."),
          do: r

    # "Part III of Schedule 4": that Part (AR-12)
    schedule_parts =
      for [_, p, n] <-
            Regex.scan(
              ~r/\bPart\s+([IVXL]+[A-Z]?|\d+[A-Z]?)\s+of\s+Schedule\s+(\d+[A-Z]*)\b#{@own}/,
              text
            ),
          do: {n, "sch.#{n}.pt.#{p}"}

    # "in Schedule 13 to the Act, paragraphs …" is where, not what; "Schedule
    # 1 to this Order" is the order's own (AR-12: SI 1999/2830)
    schedules =
      for [_, list] <-
            Regex.scan(
              ~r/(?<![Ii]n )\bSchedules?\s+#{@list}\b(?!\s*,?\s*paragraph)#{@own}/,
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

    # "Part I", "Parts III and IV" of the Act (not "Part II of Schedule 17";
    # "in Part II, the repeals of …" is where in a repeals Schedule; "the
    # said Part I" is the order's own, AR-15: SI 1997/3114)
    parts =
      for [_, list] <-
            Regex.scan(
              ~r/(?<![Ii]n )(?<!said )\bParts?\s+((?:[IVXL]+[A-Z]?|\d+[A-Z]?)(?:\s*(?:,|and|to)\s*(?:[IVXL]+[A-Z]?|\d+[A-Z]?))*)\b(?!\s+(?:of|to)\s+(?:the\s+)?Schedule|\s+thereof)/,
              text
            ),
          not (text =~ ~r/\bof\s+Schedule\b/i and sch != nil),
          p <- String.split(list, ~r/\s*(?:,|and|to)\s*/, trim: true),
          do: "pt.#{p}"

    paragraphs =
      case sch do
        nil ->
          for [_, list, s] <-
                Regex.scan(~r/\bparagraphs?\s+#{@list}\s+of\s+Schedule\s+(\d+[A-Z]*)/i, text),
              r <- list_refs(list, "sch.#{s}.para."),
              do: r

        s ->
          for [_, list] <- Regex.scan(~r/\bparagraphs?\s+#{@list}/i, text),
              r <- list_refs(list, "sch.#{s}.para."),
              do: r
      end

    Enum.uniq(
      of_section ++
        sections ++
        subsections ++
        schedules ++ Enum.map(schedule_parts, &elem(&1, 1)) ++ parts ++ bare ++ paragraphs
    )
    |> Enum.reject(&(&1 =~ ~r/^s\.\(/))
  end

  # "Subsections (1) to (5) of section 18", "sub-sections (2), (3) and (4)
  # of section 34": those subsections, never the section (AR-14: SI
  # 1999/2830, SI 2004/1572); the phrase is taken out of the text so its
  # "section 18" isn't read as the whole section
  @subsections_of ~r/\bsub-?sections?\s+((?:\([0-9A-Za-z]+\)\s*(?:,|and|to|–)?\s*)+)of\s+section\s+(\d+[A-Z]*)\b/i

  defp subsections_of(text) do
    for [phrase, list, n] <- Regex.scan(@subsections_of, text), reduce: {[], text} do
      {refs, t} -> {refs ++ bracket_refs(list, "s.#{n}"), String.replace(t, phrase, " ")}
    end
  end

  # "(1) to (5)" → s.18(1)..s.18(5); "(2), (3) and (4)" → each
  defp bracket_refs(list, base) do
    Regex.scan(~r/\(([0-9A-Za-z]+)\)|\b(to)\b|(–)/, list)
    |> Enum.reduce({[], false}, fn
      [_, b], {[from | rest], true} -> {["#{from}..#{base}(#{b})" | rest], false}
      [_, b], {acc, _} -> {["#{base}(#{b})" | acc], false}
      _range, {acc, _} -> {acc, true}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  # "17 to 22", "1, 3 to 6, and 10 to 14", "2(1) to (3)", "105(1)"
  defp list_refs(list, prefix) do
    tokens =
      Regex.scan(
        ~r/(to|–|-(?=\s*\d))|(\d+[A-Z]*)((?:\([0-9A-Za-z]+\))*)|((?:\([0-9A-Za-z]+\))+)/,
        list
      )

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, b], {acc, _last, true} when acc != [] ->
          [from | rest] = acc
          {["#{from}..#{prefix}#{n}#{b}" | rest], n, false}

        [_, "", n, b], {acc, _last, _} ->
          {["#{prefix}#{n}#{b}" | acc], n, false}

        # "2(1) to (3)": a bracket range within the last number
        [_, "", "", "", b], {[from | rest], last, true} when is_binary(last) ->
          {["#{from}..#{prefix}#{last}#{b}" | rest], last, false}

        [_, "", "", "", b], {acc, last, _} when is_binary(last) ->
          {["#{prefix}#{last}#{b}" | acc], last, false}

        _, state ->
          state
      end)

    Enum.reverse(refs)
  end

  # ── Schedule tables ──────────────────────────

  # a Schedule dated by its title (or its article), or each of its Parts by
  # its own ("PART II PROVISIONS COMING INTO FORCE ON 15th DECEMBER 1999":
  # SI 1999/2830, AR-12) — never both
  defp tables(order, _act) do
    for id <- order.ids,
        String.match?(id, ~r/^schedule(-\d+[A-Z]*)?(?:-part-[IVXL\d]+[A-Z]?)?$/),
        not dated_parts?(order, id),
        el = Doc.element(order, id),
        date = schedule_date(order, el),
        date != nil,
        {text, purpose} <- table_rows(el),
        {refs, purposes, territory} <- elem(items(text, ["the act"], nil), 0),
        refs != [],
        do:
          Rule.new(
            commences: :pending,
            scope: refs,
            when: {:date, date},
            territory: territory,
            purposes: table_purposes(purpose, purposes),
            source: %{
              law: order.law_name,
              ref: source_ref(id),
              text: squash("#{text} | #{purpose}")
            },
            treatment: :order_schedule
          )
  end

  defp dated_parts?(order, id) do
    not String.contains?(id, "-part-") and
      Enum.any?(order.ids, fn part ->
        String.match?(part, ~r/^#{Regex.escape(id)}-part-[IVXL\d]+[A-Z]?$/) and
          part_date(order, part) != nil
      end)
  end

  defp part_date(order, id) do
    order
    |> Doc.element(id)
    |> xpath(~x"./TitleBlock/Title | ./Title"l)
    |> Enum.map_join(" ", &Doc.text/1)
    |> parse_dates()
    |> case do
      [d] -> d
      _ -> nil
    end
  end

  defp table_purposes(purpose, from_text) do
    cond do
      purpose in [nil, ""] or purpose =~ ~r/^for all (?:remaining |other )?purposes\.?$/i ->
        from_text

      # the table's second column is mostly its subject ("Minor and
      # consequential amendments"): a purpose only when it words one
      Regex.match?(@partial, purpose) ->
        from_text || purposes(purpose)

      true ->
        from_text
    end
  end

  defp table_rows(el) do
    el
    |> xpath(~x".//*[local-name()='tbody']/*[local-name()='tr']"l)
    |> Enum.map(fn tr -> tr |> xpath(~x"./*[local-name()='td']"l) |> Enum.map(&Doc.text/1) end)
    |> Enum.reduce({[], nil}, fn
      [first | rest], {acc, parent} ->
        purpose = List.first(rest)

        cond do
          purpose in [nil, ""] ->
            {flush(acc, parent), {first, false}}

          parent && first =~ ~r/^(sub)?(sections?|paragraphs?)\b/ ->
            {text, _} = parent
            {[{"#{text} #{first}", purpose} | acc], {text, true}}

          true ->
            {[{first, purpose} | flush(acc, parent)], nil}
        end

      _, acc ->
        acc
    end)
    |> then(fn {acc, parent} -> flush(acc, parent) end)
    |> Enum.reverse()
  end

  # a row with no subject is a heading for the rows under it ("Section 44" over
  # "paragraph 3 …"); with none under it, it is an item itself (AR-15: SI
  # 1999/2830 "Section 31 and in Schedule 7, …" has no subject cell)
  defp flush(acc, {text, false}), do: [{text, ""} | acc]
  defp flush(acc, _parent), do: acc

  defp schedule_date(order, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    case parse_dates(title) do
      [d] -> d
      _ -> article_date(order, el)
    end
  end

  defp article_date(order, el) do
    with ref when ref != nil <- xpath(el, ~x"./Reference"),
         [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)),
         words =
           Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}") do
      case parse_dates(words) do
        [d] -> d
        _ -> nil
      end
    else
      _ -> nil
    end
  end

  # ── helpers ─────────────────────────────────────────────────────────

  @months ~w(january february march april may june july august september october november december)
  @date ~r/(\d{1,2})(?:st|nd|rd|th)? (January|February|March|April|May|June|July|August|September|October|November|December),? (\d{4})/i

  # "1st October 2001", "2 April 1994" → dates, in order
  defp parse_dates(w) do
    for [_, day, month, year] <- Regex.scan(@date, w) do
      m = Enum.find_index(@months, &(&1 == String.downcase(month))) + 1
      Date.new!(String.to_integer(year), m, String.to_integer(day))
    end
  end

  defp source_ref(id), do: ref(id) || id

  defp prefix("section"), do: "s"
  defp prefix("regulation"), do: "reg"
  # domestic instruments number articles as `reg.` (LAT's convention; `art.` is EU)
  defp prefix("article"), do: "reg"

  defp brackets(subs), do: Enum.map_join(subs, &"(#{&1})")

  defp squash(t), do: t |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp norm(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, " ") |> String.trim()
end
