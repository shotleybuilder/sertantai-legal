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
    the article that brings it in;
  - the whole Act: "The Employment Medical Advisory Service Act 1972 shall
    come into operation on 1st February 1973" (SI 1973/28), "Apart from the
    provisions mentioned in paragraph (2), the … Act 2007 shall, to the
    extent that it is not already in force, come into force on 6th April
    2008" (SI 2008/401: all but the paragraph's provisions; CV-S04).

  Items: sections (lists, ranges, subsections: "in section 61, subsection
  (6)"), Schedules, "paragraphs … of Schedule N" (or under "the following
  paragraphs of Schedule N—", or "in Schedule N to the Act, paragraphs …").
  "Section 120(1) in so far as it relates to the following paragraphs of
  Schedule 22" brings those paragraphs in fully and the section partly. "So
  far as not already in force" / "for all (remaining) purposes" / "(except
  so far as already in operation)" / "(except as aforesaid)" (SI 1974/1439:
  the rest of a provision an earlier entry brought in partly) is full; any
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
  # … "is the day appointed", "is the appointed day" (WSI 2011/824, CV-S04)
  @appointed ~r/\bis\s+the\s+(?:(?:day|date)\s+appointed|appointed\s+(?:day|date))\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i
  # "The appointed day for the coming into force of <provisions> … is
  # <date>" (Welsh orders: WSI 2017/546)
  @appointed_is ~r/\bthe\s+(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b(.*)\bis\s+(.+)$/isu
  @full ~r/\b(?:(?:in\s*)?so\s*far|insofar|in\s+as\s+far)\s+as\s+(?:it|they|th(?:at|ose|ese)\s+[\w-]+)\s+(?:has|have|is|are)\s+not\s+(?:already|previously|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force)|(?:(?:in\s*)?so\s*far|insofar)\s+as\s+not\s+(?:already|previously|yet|then)\s+in\s+force|\bto\s+the\s+extent\s+(?:that\s+)?(?:it|they)\s+(?:is|are|has|have)\s+not\s+(?:already|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force)|for\s+all\s+(?:remaining\s+|other\s+)?purposes|\(?\s*except\s+(?:in\s+)?so\s+far\s+as\s+(?:it\s+is\s+|they\s+are\s+)?already\s+in\s+(?:operation|force)\s*\)?|\(\s*except\s+as\s+aforesaid\s*\)/i
  @relating ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+to\b|\bto\s+the\s+extent\s+that\s+(?:it|they)\s+relates?\s+to\b|\bas\s+respects\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+(?:gives?|give)\s+effect\s+to\b/i
  @partial ~r/\bthe\s+following\s+repeals\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\b|\bto\s+the\s+extent\b|\bfor\s+the\s+purposes?\s+(?:only\s+)?of\b|\bfor\s+(?:specified|certain|limited|particular)\s+purposes\b|\bexcept\b|\bsave\b|\bin\s+relation\s+to\b/i
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
    # an order never commences itself (NISR 2012/286, read as its own Act's
    # orders when it was the law asked about: CV-S04)
    if order.law_name != act.law and commences?(order, act) do
      aliases = aliases(order, act)

      type_territory = type_territory(order.law_name) || title_territory(order)

      (statements(order, aliases) ++
         whole_act(order, aliases) ++ appointed_for(order, aliases) ++ tables(order, act))
      |> Enum.map(fn r ->
        %{r | commences: act.law, territory: r.territory || head_territory(r) || type_territory}
      end)
    else
      []
    end
  end

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

  @doc "An amending provision's CLML id as a ref: \"section-36-3\" → \"s.36(3)\", \"schedule-11-paragraph-137-a\" → \"sch.11.para.137(a)\"."
  @spec ref(String.t()) :: String.t() | nil
  def ref(id) do
    case String.split(id, "-") do
      # a Schedule, its Parts (nested kept) and paragraph: "schedule-4-part-2-
      # paragraph-3" → sch.4.pt.2.para.3 (the triple, Jason 2026-10-27:
      # unique where numbering restarts in each Part); an unnumbered Schedule
      # is `sch` ("schedule-paragraph-1" → sch.para.1; CV-S02a K10)
      ["schedule" | rest] ->
        case rest do
          [kind | _] when kind in ["part", "paragraph"] -> schedule_ref("sch", rest)
          [s | more] -> schedule_ref("sch.#{s}", more)
          [] -> "sch"
        end

      [kind, n | subs] when kind in ~w(section regulation article) ->
        "#{prefix(kind)}.#{n}" <> brackets(subs)

      _ ->
        nil
    end
  end

  defp schedule_ref(sch, ["part", p | rest]), do: schedule_ref("#{sch}.pt.#{p}", rest)
  defp schedule_ref(sch, ["paragraph", p | subs]), do: "#{sch}.para.#{p}" <> brackets(subs)
  # (anything else after the Schedule or Part, "schedule-part": that)
  defp schedule_ref(sch, _), do: sch

  @doc "The evaluator's context for an amending law's refs: a Schedule paragraph sits in its Schedule."
  @spec context() :: map()
  def context do
    %{
      ancestors: fn ref ->
        # (its Parts, then its Schedule: "sch.4.pt.2.para.3" → sch.4.pt.2,
        # sch.4; "sch.para.3": an unnumbered Schedule's, in `sch`)
        case Regex.run(~r/^(sch(?:\.(?!pt\.|para\.)[^.]+)?)((?:\.pt\.[^.]+)*)\.para\./, ref) do
          [_, sch, pts] ->
            parts = for [p] <- Regex.scan(~r/\.pt\.[^.]+/, pts), do: p
            chain = Enum.scan(parts, sch, &(&2 <> &1))
            Enum.reverse(chain) ++ [sch]

          nil ->
            []
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

    # "the 1989 Act" names the Act unless the order defines it as another
    # (SI 1997/134, CV-S04)
    year =
      case DefinedTerms.of(order)["the #{act.year} act"] do
        %{law: l} when is_binary(l) and l != act.law -> []
        _ -> ["the #{act.year} act"]
      end

    Enum.uniq(
      ["the act" | terms] ++
        year ++ if(act.title, do: [norm("#{act.title} #{act.year}")], else: [])
    )
  end

  @entries_head ~r/\bthe\s+following\s+(?:repeals|entries)\b/i

  # ── statements in articles ──────────────────────────────────────────

  # an article (or paragraph) whose own words state a commencement: its
  # first such line is the statement, the lines below are its items
  defp statements(order, aliases) do
    made = made(order)

    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
        words = Text.words_of(order, id),
        Regex.match?(@cif, words) or Regex.match?(@appointed, words) or
          Regex.match?(@appointed_is, words),
        lines = order |> Doc.element(id) |> Doc.lines() |> Enum.map(&clean_line/1),
        {pre, head, rest} = split_head(lines),
        head != nil,
        {date, inline} <- List.wrap(statement(head, made)),
        # "in so far as it relates to the following repeals in Part I of
        # Schedule 16 …: the repeal of section 1(1)(d) … of the Health and
        # Safety at Work etc. Act 1974; …" (SI 1996/3056): the entries below
        # are other provisions' repeals, never commenced by it
        rest = if(head =~ @entries_head, do: [], else: rest),
        items = Enum.reject(pre ++ [clean_line(inline) | rest], &(&1 == "")),
        rule <- item_rules(items, aliases, date, order.law_name, id, head),
        do: rule
  end

  # ── the day a section of the Act appoints ───────────────────────────

  @appointed_for ~r/\bthe\s+(?:day|date)\s+appointed\s+for\s+the\s+purposes?\s+of\s+(section|article|regulation)\s+(\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s+of\s+(?:the\s+)?(.+?)\s+(?:shall\s+be|is)\s+(.+)$/iu

  # "The day appointed for the purpose of section 18(2) of the Gas Act 1995
  # shall be 1st March 1996" (SI 1996/218 art.2, CV-S04 round 3): the day
  # what that section leaves to "the appointed day" comes in — a rule whose
  # scope is that section's, `resolve_appointed_for/2` reading it from the
  # Act's own rules
  defp appointed_for(order, aliases) do
    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
        line <- order |> Doc.element(id) |> Doc.lines() |> Enum.map(&clean_line/1),
        [_, noun, n, law, tail] <- [Regex.run(@appointed_for, line)],
        Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
          norm(law) in ["act", "the act"],
        [d | _] <- [parse_dates(tail)],
        uniq: true do
      Rule.new(
        commences: :pending,
        scope: ["appointed_for:#{prefix(String.downcase(noun))}.#{n}"],
        when: {:date, d},
        source: %{law: order.law_name, ref: source_ref(id), text: squash(line)},
        treatment: :order_date
      )
    end
  end

  @doc """
  An order's "the day appointed for the purpose of section 18(2)" rules
  given the scope (and except) of the Act's own rule from that section that
  leaves its provisions to the appointed day (`act_rules`: the Act's rules);
  dropped where the Act holds none.
  """
  @spec resolve_appointed_for([Rule.t()], [Rule.t()]) :: [Rule.t()]
  def resolve_appointed_for(rules, act_rules) do
    Enum.flat_map(rules, fn
      %Rule{scope: ["appointed_for:" <> ref]} = r ->
        case Enum.find(
               act_rules,
               &(match?({:appointed, _}, &1.when) and &1.source.law == r.commences and
                   (&1.source.ref == ref or String.starts_with?(&1.source.ref || "", ref <> "(")))
             ) do
          nil -> []
          own -> [%{r | scope: own.scope, except: own.except}]
        end

      r ->
        [r]
    end)
  end

  # ── the whole Act ───────────────────────────────────────────────────

  @apart ~r/^(?:apart\s+from|except(?:\s+for)?|other\s+than)\s+the\s+provisions\s+(?:mentioned|specified|listed|referred\s+to)\s+in\s+(paragraph|article)\s+\(?(\w+)\)?\s*,?\s*/i
  @still ~r/\s*,?\s*(?:shall\s*)?,?\s*(?:(?:to\s+the\s+extent\s+that|in\s*so\s+far\s+as|insofar\s+as|so\s+far\s+as)\s+(?:(?:it\s+is|they\s+are)\s+)?not\s+(?:already|yet)\s+in\s+force)?\s*,?\s*$/i

  # an article whose statement's subject is the Act itself: the whole Act
  # from its date, but for the provisions another paragraph lists
  defp whole_act(order, aliases) do
    made = made(order)
    names = Enum.map(aliases, &String.replace_prefix(&1, "the ", ""))

    rules =
      for id <- order.ids,
          String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
          head =
            order
            |> Doc.element(id)
            |> Doc.lines()
            |> Enum.map(&clean_line/1)
            |> Enum.find(&Regex.match?(@cif, &1)),
          is_binary(head),
          Regex.match?(@cif, head),
          [subject, tail] = Regex.split(@cif, head, parts: 2),
          {apart, subject} = apart(subject),
          subject
          # "The Petroleum Act 1998 (hereinafter referred to as “the Act”)"
          |> String.replace(
            ~r/\s*\((?:hereinafter|in\s+this\s+Order|referred\s+to|“|")[^)]*\)/iu,
            ""
          )
          |> String.replace(@still, "")
          |> norm()
          |> String.replace_prefix("the ", "")
          |> then(&(&1 in names)),
          d = tail_date(tail, made),
          d != nil do
        Rule.new(
          commences: :pending,
          scope: :all,
          except: listed(order, id, apart),
          when: {:date, d},
          source: %{law: order.law_name, ref: source_ref(id), text: squash(head)},
          treatment: :order_date
        )
      end

    # an article and its paragraph state it once: the paragraph's kept
    rules
    |> Enum.reverse()
    |> Enum.uniq_by(&{&1.scope, &1.except, &1.when})
    |> Enum.reverse()
  end

  defp apart(subject) do
    case Regex.run(@apart, subject) do
      [whole, kind, n] -> {{String.downcase(kind), n}, String.replace_prefix(subject, whole, "")}
      nil -> {nil, subject}
    end
  end

  # the provisions the named paragraph (of this article) or article lists
  defp listed(_order, _id, nil), do: []

  defp listed(order, id, {kind, n}) do
    other =
      case kind do
        "paragraph" -> (id |> String.split("-") |> Enum.take(2) |> Enum.join("-")) <> "-" <> n
        "article" -> "article-" <> n
      end

    case Doc.element(order, other) do
      nil ->
        []

      el ->
        el |> Doc.lines() |> Enum.flat_map(&refs(strip_parentheticals(&1), nil)) |> Enum.uniq()
    end
  end

  # {items before the statement, the statement line, the lines after}: an
  # older order lists its items first and states the date last ("The
  # following provisions of the … Act 1981, namely— (a) Part I …; (b) …
  # shall come into force on 28th September 1982": CR-07, SI 1982/1217)
  defp split_head(lines) do
    case Enum.split_while(
           lines,
           &(not (Regex.match?(@cif, &1) or Regex.match?(@appointed, &1) or
                    Regex.match?(@appointed_is, &1)))
         ) do
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
      # "The appointed day for the coming into force of X … is D—": the
      # date after "is"; the items X, or after the dash ("the following")
      match = Regex.run(@appointed_is, head) ->
        [_, subject, tail] = match
        [date_part | after_dash] = Regex.split(~r/[—–:]\s*/u, tail, parts: 2)

        with [d] <- parse_dates(date_part) do
          {d,
           if(subject =~ ~r/\bthe following\b/i, do: Enum.join(after_dash, " "), else: subject)}
        else
          _ -> nil
        end

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
            # a qualifier after the date is the subject's ("Section 120(1) of,
            # and Schedule 22 to, the 1995 Act come into force on 1st April
            # 2015 in so far as they relate to paragraph 81 of Schedule 22":
            # SSI 2015/73, CV-S04 round 4)
            after_date =
              case Regex.run(
                     ~r/\b\d{4}\s*,?\s+((?:(?:in\s*)?so\s*far|insofar)\s+as\b[^—–:]*|to\s+the\s+extent\b[^—–:]*|for\s+the\s+purposes?\s+of\b[^—–:]*)/iu,
                     tail
                   ) do
                [_, q] -> " " <> q
                nil -> ""
              end

            {d,
             if(subject =~ ~r/\bthe following\b/i,
               do: after_dash,
               else: subject <> after_date <> " " <> after_dash
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
    # (never a date's day: "18 March 2011 is the appointed day …": WSI 2011/824)
    |> String.replace(
      ~r/^\(?\d+[A-Z]?\)?(?:\s+\(?\d+\)?)?\s+(?=[A-Z])(?!(?:January|February|March|April|May|June|July|August|September|October|November|December)\b)/u,
      ""
    )
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
          purposes: purposes,
          source: %{law: law, ref: source_ref(id), text: squash("#{head} … #{line}")},
          treatment: :order_date
        )
    end
  end

  # an item: {refs, purposes, territory}, or with the provisions it leaves out
  defp parts({refs, purposes, territory}), do: {refs, purposes, territory, []}
  defp parts({_, _, _, _} = item), do: item

  # ── items in a line ─────────────────────────────────────────────────

  # "Paragraphs 1 to 27(3) and 28 to 43 of Schedule 7, and section 22(1) so
  # far as it relates thereto" (SI 1996/396): the paragraphs as read, the
  # section partly — "thereto" qualifies only the provision it follows
  @thereto ~r/^(.*?),?\s+and\s+((?:sub-?)?sections?\s+\S+(?:\s+and\s+\(\w+\))?)\s+(?:in\s+)?so\s+far\s+as\s+(?:it|they)\s+relates?\s+thereto\b.*$/is

  # a line's items: [{refs, purposes, territory}] and the Schedule context
  # its paragraphs carry to the next lines
  defp items(line, aliases, sch) do
    case Regex.run(@thereto, line) do
      [_, rest, section] ->
        {items, next} = items(rest, aliases, sch)
        qualified = refs(section, nil)

        if qualified == [],
          do: {items, next},
          else: {items ++ [{qualified, :in_relation_to, territory(line)}], next}

      nil ->
        line_items(line, aliases, sch)
    end
  end

  @schedule_entries ~r/^\W*In\s+(?:the\s+Schedule|Schedule\s+(\d+[A-Z]*))?\s*(?:to\s+the\s+Act\s*)?[,—–:]\s*the\s+(repeals?|entr(?:y|ies))\b(.*)$/isu

  defp line_items(line, aliases, sch) do
    case Regex.run(@schedule_entries, line) do
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

        {[{[ref], :in_relation_to, territory(line)} | items], sch}

      nil ->
        own_line_items(line, aliases, sch)
    end
  end

  defp own_line_items(line, aliases, sch) do
    line = drop_other_laws(line, aliases)

    case bracket_items(line) do
      nil -> plain_line_items(line, aliases, sch)
      items -> {items, next_context(line, sch)}
    end
  end

  # "Sections 1, 2, 4 to 28, 100 to 104, 105 (in so far as it is not already
  # in force), 159 and 162(2) (in so far as it relates to Part V of Schedule
  # 16)": each item its own bracketed qualifier, the rest fully (SI 1990/2635
  # reg.3, CV-S04 round 4); nil for any other line
  @relating_tail ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+relates?\s+to\s+(.*)$/is

  @bracket_qualifier ~r/\(\s*(?:(?:in\s*)?so\s*far|insofar|to\s+the\s+extent|for\s+the\s+purposes?\s+of)\b/i

  defp bracket_items(line) do
    with true <- Regex.match?(@bracket_qualifier, line),
         [_, list | tail] <-
           Regex.run(
             ~r/^\W*(?:the\s+)?sections?\s+(\d.*?)(?:,?\s+of\s+the\s+(?:Act|[A-Z](?:[^()]|\([^()]*\))*?\s+Act\s+\d{4})\b(.*))?$/is,
             line
           ),
         false <-
           String.replace(list, ~r/\((?:[^()]|\([^()]*\))*\)/u, "") =~
             ~r/\b(?:Schedule|paragraph|Part)s?\b/,
         items =
           list |> split_items() |> Enum.flat_map(&String.split(&1, ~r/\s+and\s+(?![^()]*\))/u)),
         true <- length(items) > 1 do
      # "… of the Landfill Tax (Scotland) Act 2014 (so far as not then in
      # force)": the list's own qualifier, for items without theirs (SSI 2015/17)
      list_qualifier = tail |> List.first("") |> String.trim() |> bracket_of()

      for item <- items,
          {qualifier} = {bracket_of(item) || list_qualifier},
          plain =
            item
            |> String.replace(~r/\s*\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, "")
            |> String.trim(),
          refs = list_refs(plain, "s."),
          refs != [] do
        purposes =
          cond do
            qualifier == nil -> nil
            Regex.match?(@full, qualifier) -> nil
            true -> purposes(qualifier)
          end

        # "162(2) (in so far as it relates to Part V of Schedule 16)": the
        # section partly, the Schedule's provisions it relates to fully
        related =
          with q when is_binary(q) <- qualifier,
               [_, rel] <- Regex.run(@relating_tail, q),
               [_ | _] = rs <- rel |> refs(nil) |> Enum.filter(&String.starts_with?(&1, "sch.")) do
            [{rs, nil, territory(line)}]
          else
            _ -> []
          end

        [{refs, purposes, territory(line)} | related]
      end
      |> List.flatten()
    else
      _ -> nil
    end
  end

  # an item's own qualifier: its bracket with words in it
  defp bracket_of(item) do
    case Regex.run(~r/\(((?=[^()]*\s)(?:[^()]|\([^()]*\))*)\)\s*$/u, item) do
      [_, q] -> if Regex.match?(@bracket_qualifier, "(" <> q), do: q
      nil -> nil
    end
  end

  defp plain_line_items(line, _aliases, sch) do
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
      cond do
        items = related != "" && bare_items(related, schedule_context(related, sch), territory) ->
          items

        related_refs != [] and Regex.match?(@entries_head, related) ->
          [{related_refs, :in_relation_to, territory}]

        related_refs != [] and paragraphs?(related_refs) ->
          # "… paragraphs 142, 143 … of Schedule 22 in so far as the amendments
          # made by those provisions confer any power to make regulations"
          # (SI 1996/2909): the paragraphs carry that qualifier
          # (never "(in so far as those provisions are not already in force)")
          rest =
            related
            |> String.replace(~r/^.*?\bof\s+Schedule\s+\d+[A-Z]*/is, "")
            |> String.replace(@full, "")

          [{related_refs, if(Regex.match?(@partial, rest), do: purposes(rest)), territory}]

        true ->
          []
      end

    own_item =
      case except_subsections(own, own_refs) do
        nil -> {own_refs, own_purposes, territory}
        except -> {own_refs, nil, territory, except}
      end

    case related == "" and bare_items(own, sch, territory) do
      items when is_list(items) ->
        {items, next_context(line, sch)}

      _ ->
        {[own_item | related_item], next_context(line, sch)}
    end
  end

  # a bare list of a Schedule's paragraphs whose items carry their own
  # qualifiers ("1, 3, … 29(1) in so far as it is not already in force, 30,
  # 32 to 35": SI 1996/186 reg.3, CV-S04 round 2) — each item its own, never
  # one item's qualifier over the list; nil for any other text
  @item_qualifier ~r/\s+(?:(?:in\s+)?so\s*far\s+as|to\s+the\s+extent|except|for\s+the\s+purposes?\s+of|in\s+relation\s+to)\b.*$/is

  defp bare_items(text, sch, territory) do
    if sch && text =~ ~r/^\s*\d/ && (Regex.match?(@partial, text) or Regex.match?(@full, text)) do
      for item <- split_items(text),
          plain = Regex.replace(@item_qualifier, item, ""),
          refs = list_refs(strip_parentheticals(plain), "sch.#{sch}.para."),
          refs != [] do
        qualifier = String.trim_leading(String.replace_prefix(item, plain, ""))

        purposes =
          cond do
            qualifier == "" -> nil
            Regex.match?(@full, qualifier) -> nil
            true -> purposes(qualifier)
          end

        {refs, purposes, territory}
      end
    end
  end

  # the items of a list at its top-level commas and semicolons
  defp split_items(text) do
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

  # "Section 33 (except subsection (1)(a) and (b))": the section, but for
  # those (SI 1974/1439 Sch. 2, CV-S04 round 2); nil when it says none
  defp except_subsections(text, [ref]) do
    with [_, list] <-
           Regex.run(
             ~r/\(\s*except\s+(?:sub-?sections?|paragraphs?)\s+((?:\([0-9A-Za-z]+\)|\s|,|and)+)\)/i,
             text
           ),
         [_ | _] = chains <- Regex.scan(~r/(?:\([0-9A-Za-z]+\))+/, list) |> List.flatten() do
      number = String.replace(ref, ~r/^[a-z.]+\./i, "")
      prefix = String.replace_suffix(ref, number, "")

      chains
      |> Enum.map_reduce(nil, fn chain, last ->
        full = if last, do: sibling(last, chain), else: number <> chain
        {prefix <> full, full}
      end)
      |> elem(0)
    else
      _ -> nil
    end
  end

  defp except_subsections(_text, _refs), do: nil

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
  # "… the following repeals:— The Employment Medical Advisory Service Act
  # 1972 – sections 1 and 6 …" (SI 1974/1439 Sch. 2): a law's title then a
  # dash heads that law's provisions, to the end of the line (CV-S04)
  @titled ~r/\b(?:the\s+)?((?:[A-Z][\w()',-]*\s+)(?:(?:[A-Z][\w()',-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\s*[–—-]\s+.*$/u

  # "… the repeals to the Game Licences Act 1860 …", "in relation to the
  # Water Resources Act 1991, the repeal of sections 1 to 14 …": what follows
  # is that law's (SI 1996/396, SI 1996/186; CV-S04 round 3)
  # … to the end of its item: never the Act's own "in Part VI of Schedule 16
  # to the Act" after it (SI 1991/685); "in the Town and Country Planning Act
  # 1990, sections 226 and 245" (SI 2004/2593)
  @other_law_tail ~r/\b(?:(?:the\s+)?repeals?\s+(?:to|of|in|relating\s+to)|in\s+relation\s+to|in)\s+(?:the\s+)?((?:[A-Z][\w()',-]*\s+)(?:(?:[A-Z][\w()',-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\b.*?(?=\s+in\s+(?:Part\s+\w+\s+of\s+)?Schedule\s+\d+[A-Z]*\s+to\s+the\s+Act\b|;|$)/u

  # the words a provision is amended by, quoted, are never refs ("in section
  # 33(1) of the 1990 Act the words “… section 54 …”": SSI 2015/73); an item
  # ending in another law's name is that law's ("paragraph 17(4) of Schedule
  # 9, and paragraph 3(1) and (2) of Schedule 11, to the Local Government
  # (Wales) Act 1994": SI 1996/186) — CV-S04 round 4
  @quoted ~r/“[^”]*”|"[^"]*"|‘[^’]*’/u
  @ends_other_law ~r/,\s+to\s+the\s+((?:\d{4}\s+)?[A-Z(][\w()',.-]*(?:\s+(?:[A-Z(][\w()',.-]*|of|and|for|the|in|on|at|to|with|etc\.))*\s+(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\s*[,.]?\s*$/u

  defp drop_other_laws(line, aliases) do
    own? = fn law ->
      Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
        norm(law) in ["act", "the act"]
    end

    line =
      line
      |> String.replace(@quoted, " ")
      |> String.split(~r/;\s*/u)
      |> Enum.reject(fn item ->
        case Regex.run(@ends_other_law, item) do
          [_, law] -> not own?.(law)
          nil -> false
        end
      end)
      |> Enum.join("; ")

    line =
      Regex.replace(@other_law_tail, line, fn whole, law ->
        if Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
             norm(law) in ["act", "the act"],
           do: whole,
           else: ""
      end)

    line =
      Regex.replace(@titled, line, fn whole, law ->
        if Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
             norm(law) in ["act", "the act"],
           do: whole,
           else: ""
      end)

    Regex.replace(
      ~r/\b(?:sections?|paragraphs?|Schedules?|regulations?|articles?)\s+\d+[A-Z]*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*(?:\d+[A-Z]*)?(?:\([0-9A-Za-z]+\))*)*(?:\s*\([^()]*\))?,?\s+(?:of|to|into)\s+(?:Schedule\s+\d+[A-Z]*\s+to\s+)?(?:the\s+)?((?:\d{4}\s+)?(?:[A-Z(][\w()',.-]*\s+){0,10}(?:(?:of|and|for|the|in|on|at|to|with|etc\.)\s+(?:[A-Z(][\w()',.-]*\s+){0,8})*(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)/u,
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
              ~r/(?<![Ii]n )(?<!said )\bParts?\s+((?>(?:[IVXL]+[A-Z]?|\d+[A-Z]?)(?:\s*(?:,|and|to)\s*(?:[IVXL]+[A-Z]?|\d+[A-Z]?))*))\b(?!\s+(?:of|to)\s+(?:the\s+)?Schedule|\s+thereof)/,
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
          {["#{from}..#{prefix}#{n}#{b}" | rest], n <> b, false}

        [_, "", n, b], {acc, _last, _} ->
          {["#{prefix}#{n}#{b}" | acc], n <> b, false}

        # "2(1) to (3)": a bracket range within the last number; "33(1)(a)
        # and (b)": a sibling at the bracket's own depth (s.33(1)(b), CV-S04)
        [_, "", "", "", b], {[from | rest], last, true} when is_binary(last) ->
          {["#{from}..#{prefix}#{sibling(last, b)}" | rest], last, false}

        [_, "", "", "", b], {acc, last, _} when is_binary(last) ->
          {["#{prefix}#{sibling(last, b)}" | acc], sibling(last, b), false}

        _, state ->
          state
      end)

    Enum.reverse(refs)
  end

  # the brackets `b` in place of as many of `last`'s own: "33(1)(a)" + "(b)"
  # → "33(1)(b)"; "2(1)" + "(3)" → "2(3)"
  defp sibling(last, b) do
    depth = length(Regex.scan(~r/\(/, b))
    brackets = Regex.scan(~r/\([0-9A-Za-z]+\)/, last) |> List.flatten()
    number = String.replace(last, ~r/\(.*$/, "")
    keep = Enum.take(brackets, max(length(brackets) - depth, 0))
    number <> Enum.join(keep) <> b
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
        {row, purpose, sch} <- with_schedules(table_rows(el), table_schedule(order, el)),
        text <-
          if(row =~ @schedule_entries,
            do: [row],
            else: row |> drop_other_laws(["the act"]) |> provision_segments()
          ),
        item <- elem(items(text, ["the act"], sch), 0),
        {refs, purposes, territory, except} = parts(item),
        refs != [],
        do:
          Rule.new(
            commences: :pending,
            scope: refs,
            except: except,
            when: {:date, date},
            territory: territory,
            purposes: table_purposes(purpose, purposes),
            source: %{
              law: order.law_name,
              ref: source_ref(id),
              text: squash("#{row} | #{purpose}")
            },
            treatment: :order_schedule
          )
  end

  # a table cell's provisions, each with its own qualifier: "Section 11(4)
  # and (5) and Section 11(6) (so far as aforesaid)" → "Section 11(4) and
  # (5)" fully, "Section 11(6) (so far as aforesaid)" partly (SI 1974/1439,
  # CV-S04 round 3); split only outside brackets, before a provision noun
  defp provision_segments(text) do
    cuts =
      for [{at, len}] <-
            Regex.scan(
              ~r/,?\s+and\s+(?=(?:sub-?)?(?:[Ss]ections?|[Ss]chedules?|[Pp]aragraphs?|[Pp]arts?)\b)/u,
              text,
              return: :index
            ),
          depth(binary_part(text, 0, at)) == 0,
          do: {at, len}

    {segments, rest} =
      Enum.reduce(Enum.reverse(cuts), {[], text}, fn {at, len}, {acc, t} ->
        {[binary_part(t, at + len, byte_size(t) - at - len) | acc], binary_part(t, 0, at)}
      end)

    [rest | segments] |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  defp depth(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0, fn
      "(", d -> d + 1
      ")", d -> max(d - 1, 0)
      _, d -> d
    end)
  end

  # each row with the Schedule an earlier row names: "Schedule 6" then
  # "paragraph 5 | For all purposes" is Schedule 6's paragraph 5 (SI
  # 2000/2974, CV-S04); a section's row ends it
  defp with_schedules(rows, first) do
    rows
    |> Enum.map_reduce(first, fn {text, purpose}, sch ->
      sch =
        case Regex.run(~r/^\s*Schedule\s+(\d+[A-Z]*)\b/i, text) do
          [_, n] -> n
          nil -> if text =~ ~r/^\s*(?:sections?|in\s+section)\b/i, do: nil, else: sch
        end

      {{text, purpose, sch}, sch}
    end)
    |> elem(0)
  end

  # the Act's Schedule a table lists the paragraphs of: its title's
  # ("EXTENT OF COMMENCEMENT OF SCHEDULE 7": SI 1991/2905), else the
  # article bringing it in ("… Schedule 7 to the Act specified in …")
  defp table_schedule(order, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    words =
      with ref when ref != nil <- xpath(el, ~x"./Reference"),
           [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)) do
        Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}")
      else
        _ -> ""
      end

    with nil <- capture(~r/\bSchedule\s+(\d+[A-Z]*)\b(?!\s+to\s+th(?:is|ese)\b)/i, title),
         nil <- capture(~r/\bSchedule\s+(\d+[A-Z]*)\s+to\s+the\b/i, words) do
      nil
    end
  end

  defp capture(re, text) do
    case Regex.run(re, text) do
      [_, n] -> n
      nil -> nil
    end
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

  @purpose_opening ~r/^\W*(?:(?:in\s+)?so\s+far|insofar|to\s+the\s+extent|for\s+(?:the\s+)?(?:purposes?|specified|certain)|except|only|in\s+relation\s+to|as\s+respects)\b/i

  defp table_purposes(purpose, from_text) do
    cond do
      purpose in [nil, ""] or purpose =~ ~r/^for all (?:remaining |other )?purposes\.?$/i ->
        from_text

      # the table's second column is mostly its subject ("Minor and
      # consequential amendments"): a purpose only when it opens with one
      # — never a subject naming purposes ("Definition of “county” for the
      # purposes of the … Act 1986": SI 1995/2490)
      Regex.match?(@partial, purpose) and Regex.match?(@purpose_opening, purpose) ->
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
