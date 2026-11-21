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

  alias __MODULE__.{Asides, Entries, LastItemLimit, OtherLaw, ScheduleParts}
  alias __MODULE__.{SectionHeads, Sibling, Territory}
  alias SertantaiLegal.Scraper.Commencement.Rule

  alias SertantaiLegal.Scraper.LawStart.Clause

  @type act :: %{law: String.t(), title: String.t() | nil, year: String.t()}

  @cif ~r/\b(?:shall\s+)?(?:come|comes)\s+into\s+(?:force|operation)\b/i
  # … "is the day appointed", "is the appointed day" (WSI 2011/824, CV-S04)
  @appointed ~r/\bis\s+the\s+(?:(?:day|date)\s+appointed|appointed\s+(?:day|date))\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i
  # "The appointed day for the coming into force of <provisions> … is
  # <date>" (Welsh orders: WSI 2017/546)
  @appointed_is ~r/\bthe\s+(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b(.*)\bis\s+(.+)$/isu
  @full ~r/\b(?:(?:in\s*)?so\s*far|insofar|in\s+as\s+far)\s+as\s+(?:it|they|th(?:at|ose|ese)\s+[\w-]+)\s+(?:has|have|is|are)\s+not\s+(?:already|previously|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force|come\s+into\s+(?:force|operation))|(?:(?:in\s*)?so\s*far|insofar)\s+as\s+not\s+(?:already|previously|yet|then)\s+in\s+force|\bto\s+the\s+extent\s+(?:that\s+)?(?:it|they)\s+(?:is|are|has|have)\s+not\s+(?:already|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+force|come\s+into\s+(?:force|operation))|for\s+all\s+(?:remaining\s+|other\s+)?purposes|\(?\s*except\s+(?:in\s+)?so\s+far\s+as\s+(?:it\s+is\s+|they\s+are\s+)?already\s+in\s+(?:operation|force)\s*\)?|\(\s*except\s+as\s+aforesaid\s*\)/i
  @relating ~r/\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+to\b|\bto\s+the\s+extent\s+that\s+(?:it|they)\s+relates?\s+to\b|\bas\s+respects\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\s+(?:it|they)\s+(?:gives?|give)\s+effect\s+to\b/i
  @partial ~r/\bthe\s+following\s+repeals\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\b|\bto\s+the\s+extent\b|\bfor\s+the\s+purposes?\s+(?:only\s+)?of\b|\bfor\s+(?:specified|certain|limited|particular)\s+purposes\b|\bexcept\b|\bsave\b|\bin\s+relation\s+to\b/i

  @doc "The rules an order states for the law `act` it commences ([] when it doesn't commence it)."
  @spec rules(Doc.t(), act()) :: [Rule.t()]
  def rules(%Doc{} = order, act) do
    # an order never commences itself (NISR 2012/286, read as its own Act's
    # orders when it was the law asked about: CV-S04)
    if order.law_name != act.law and commences?(order, act) do
      aliases = aliases(order, act)

      type_territory =
        Territory.of_type(order.law_name, act.law) || Territory.of_title(full_title(order))

      (statements(order, aliases) ++
         whole_act(order, aliases) ++
         appointed_for(order, aliases) ++ tables(order, act) ++ schedule_lists(order, aliases))
      |> Enum.flat_map(&own_articles(&1, act))
      |> Enum.map(fn r ->
        %{r | commences: act.law, territory: r.territory || head_territory(r) || type_territory}
      end)
    else
      []
    end
  end

  # the law types whose provisions are Articles or regulations (an Order in
  # Council: NISI 1992/1728); an Act's are sections
  @instruments ~w(nisi uksi ssi wsi nisr uksro nisro ukmo ukci)

  # an Article named in an order is the commenced law's only where that law
  # is an instrument; for an Act it is the order's own ("Article 3 comes
  # into force on 1st April 2015": SSI 2015/139), never a provision of the Act
  defp own_articles(%Rule{scope: scope} = rule, act) when is_list(scope) do
    if (act.law |> String.split("_") |> Enum.at(1)) in @instruments do
      [rule]
    else
      case Enum.reject(scope, &String.starts_with?(&1, "reg.")) do
        [] -> []
        kept -> [%{rule | scope: kept}]
      end
    end
  end

  defp own_articles(rule, _act), do: [rule]

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
      # the year it ends with, never one inside it (SI 2015/1637: "The
      # Deregulation Act 2015 (…) Order 2015" is not the Deregulation Act)
      t -> t |> String.replace(~r/\s+\d{4}\s*$/, "") |> String.trim()
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

  @doc "True when the order commences `act` (its \"the Act\", else its title named in its words)."
  @spec commences?(Doc.t(), act()) :: boolean()
  def commences?(order, act) do
    case DefinedTerms.of(order)["the act"] do
      %{law: law} when is_binary(law) -> law == act.law
      %{title: t} when is_binary(t) -> named?(t, act)
      _ -> Enum.any?(order.ids, &named?(Text.words_of(order, &1), act))
    end
  end

  # the Act's title and year, never as the tail of a longer title: "the
  # Police and Fire Reform (Scotland) Act 2012" is not the Scotland Act 2012
  # (SSI 2013/51, listed for both)
  @before_title ~w(the of to under by in and as with for said a an)

  defp named?(text, %{title: title, year: year}) when is_binary(title) do
    name = norm("#{title} #{year}")

    ~r/(?:^|(\w+) )#{Regex.escape(name)}(?: |$)/
    |> Regex.scan(norm(text))
    |> Enum.any?(fn
      [_, before] -> before in @before_title
      [_] -> true
    end)
  end

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

    # (a lettered paragraph is a statement of its own where the article's
    # words state none: "Except as provided by Article 2 of this Order— (a)
    # the following provisions … shall come into operation on 1st December
    # 1964 …; (b) …": SI 1964/1045)
    for id <- order.ids,
        String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*|-[a-z])?$/),
        words = Text.words_of(order, id),
        Regex.match?(@cif, words) or Regex.match?(@appointed, words) or
          Regex.match?(@appointed_is, words),
        lines = order |> Doc.element(id) |> Doc.lines() |> join_open() |> Enum.map(&clean_line/1),
        {pre, head, rest} = split_head(lines),
        head != nil,
        not already_in_force?(head),
        {date, inline} <- List.wrap(statement(head, made)),
        # "The following provisions of the 2023 Act come into force …": the
        # 2023 Act's, never the order's other Act's (SI 2024/452)
        not OtherLaw.head?(head, &own_law?(&1, aliases)),
        # "in so far as it relates to the following repeals in Part I of
        # Schedule 16 …: the repeal of section 1(1)(d) … of the Health and
        # Safety at Work etc. Act 1974; …" (SI 1996/3056): the entries below
        # are other provisions' repeals, never commenced by it
        rest = if(head =~ @entries_head, do: [], else: rest),
        items = Enum.reject(pre ++ [clean_line(inline) | rest], &(&1 == "")),
        q <- [list_qualifier(head)],
        rule <-
          Enum.map(item_rules(items, aliases, date, order.law_name, id, head), &qualified(&1, q)) ++
            elsewhere_rules(order, id, head, aliases, date),
        do: rule
  end

  # "… after the amendments made by paragraphs 1(2)(a) and 8(3) of Schedule
  # 5 to the 1994 Act have come into force, those sections shall have effect
  # as if …" (SI 1994/3262 art.3(2)): provisions that "have come into force"
  # are spoken of as in force, never brought in — a head whose every "come
  # into force" is so worded states no commencement
  @in_force_already ~r/\b(?:has|have|had|having)\s+come\s+into\s+(?:force|operation)\b/i

  defp already_in_force?(head) do
    said = length(Regex.scan(@in_force_already, head))
    said > 0 and said == length(Regex.scan(@cif, head))
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
  @still ~r/\s*,?\s*(?:shall\s*)?,?\s*(?:(?:to\s+the\s+extent\s+that|in\s*so\s+far\s+as|insofar\s+as|so\s+far\s+as)\s+(?:(?:it\s+is|they\s+are)\s+)?not\s+(?:already|yet|then)\s+in\s+(?:force|operation))?\s*,?\s*$/i
  # "Subject to article 3, the provisions of the … Act, so far as not then in
  # force, shall come into force, for all purposes, on …" (SSI 2006/19 art.2)
  # (the comma left out: "Subject to article 3 the 2004 Act shall, insofar
  # as it is not already in force, come into force on …": SI 2004/2304)
  @whole_lead ~r/^\W*(?:subject\s+to\s+(?:article|regulation|paragraph)\s+\(?\w+\)?\s*,?\s*)?(?:the\s+)?(?:provisions\s+of\s+)?/i

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
            |> Enum.find(&states?/1),
          is_binary(head),
          {subject, d} <- List.wrap(whole_statement(head, made)),
          d != nil,
          {apart, subject} = apart(subject),
          subject = String.replace(subject, @whole_lead, ""),
          {subject, excepted} = rest_of(subject),
          subject
          # "The Petroleum Act 1998 (hereinafter referred to as “the Act”)"
          |> String.replace(
            ~r/\s*\((?:hereinafter|in\s+this\s+Order|referred\s+to|“|")[^)]*\)/iu,
            ""
          )
          |> String.replace(@still, "")
          |> norm()
          |> String.replace_prefix("the ", "")
          |> then(&(&1 in names)) do
        Rule.new(
          commences: :pending,
          scope: :all,
          except: listed(order, id, apart) ++ excepted,
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

  defp states?(line),
    do:
      Regex.match?(@cif, line) or Regex.match?(@appointed, line) or
        Regex.match?(@appointed_is, line)

  # {the statement's subject, its date}: "<subject> shall come into force on
  # <date>"; "The day appointed for the coming into operation of <subject>
  # is <date>" (NISR 2010/328); "<date> is the day appointed for the coming
  # into force of <subject>" (SSI 2013/51)
  defp whole_statement(head, made) do
    cond do
      match = Regex.run(@appointed_is, head) ->
        [_, subject, tail] = match
        {subject, one_date(tail)}

      Regex.match?(@appointed, head) ->
        [before, subject] = Regex.split(@appointed, head, parts: 2)
        {String.replace(subject, ~r/\s*\.\s*$/, ""), one_date(before)}

      true ->
        [subject, tail] = Regex.split(@cif, head, parts: 2)
        {subject, tail_date(tail, made)}
    end
  end

  defp one_date(text) do
    case parse_dates(text) do
      [d] -> d
      _ -> nil
    end
  end

  # "The rest of the Act, except sections 85 to 87, …" (SI 1996/3146
  # art.3): the Act, less the provisions excepted — {"the Act", their refs}
  @rest_of ~r/^\s*(?:the\s+)?(?:rest|remainder)\s+of\s+(.+?)(?:\s*,?\s+except\s+((?:sections?|regulations?|articles?|paragraphs?|Schedules?)\s+[^,]+?))?\s*,?\s*$/i

  defp rest_of(subject) do
    case Regex.run(@rest_of, subject) do
      [_, act] -> {act, []}
      [_, act, except] -> {act, refs(Asides.strip(except), nil)}
      nil -> {subject, []}
    end
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
        el |> Doc.lines() |> Enum.flat_map(&refs(Asides.strip(&1), nil)) |> Enum.uniq()
    end
  end

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
        |> item_rules(aliases, date, order.law_name, id, head)
        |> Enum.map(&%{&1 | purposes: &1.purposes || qualifier})
    end
  end

  defp head_qualifier(head) do
    if Regex.match?(@partial, head) and not Regex.match?(@full, head),
      do: purposes(head)
  end

  defp elsewhere(order, id, head) do
    for other <- pointed_to(order, id, head),
        el = Doc.element(order, other),
        el != nil,
        line <- el |> Doc.lines() |> join_open() |> Enum.map(&clean_line/1),
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
    subject = head |> String.split(@cif, parts: 2) |> hd()

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
           &(not (Regex.match?(@cif, &1) or Regex.match?(@appointed, &1) or
                    Regex.match?(@appointed_is, &1)))
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

  defp first_items(header, items) do
    case Regex.run(@namely_entries, header) do
      [_, entries] -> [entries]
      nil -> items
    end
  end

  # up to the dash or colon that opens a list; a colon inside a bracketed
  # heading opens none ("the Water Industry Act 1991 (temporary bans:
  # supplemental), to make an order under …": SI 2010/2169 art.3(3))
  @to_dash ~S"(?:\([^()]*\)|[^—–:])*"

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
          case Regex.split(~r/(?:[—–]|:(?![^()]*\)))\s*/u, tail, parts: 2) do
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
            # SSI 2015/73, CV-S04 round 4; after a made-relative day, "… on the
            # day after this Order is made so far as they relate to …": SI
            # 2009/1261 art.4)
            after_date =
              case Regex.run(
                     ~r/(?:(?<!\d)\d{4}|\bmade)\s*,?\s+((?:(?:in\s*)?so\s*far|insofar)\s+as\b#{@to_dash}|to\s+the\s+extent\b#{@to_dash}|for\s+the\s+purposes?\s+of\b#{@to_dash})/iu,
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
        # (after a qualifier: ", for the purpose of making regulations …, on
        # the day after …": SI 2015/425 art.2)
        t =
          tail
          |> String.split(~r/[—–:]/u, parts: 2)
          |> hd()
          |> String.replace(
            ~r/^\W*(?:for\s+the\s+purposes?\s+of|(?:in\s*)?so\s*far\s+as|insofar\s+as|to\s+the\s+extent)\b[^,]*,\s*/i,
            ""
          )
          |> String.trim()

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
    # (a line under "in section 86—" is read as that section's: its words
    # stay the line's own)
    {rules, _sch} =
      Enum.reduce(SectionHeads.read(lines), {[], nil}, fn {line, read}, {acc, sch} ->
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
  # (in an aside: "paragraphs 10 to 14 of Schedule 3 (and section 44(1) so
  # far as relating thereto)": SI 1999/987)
  @thereto ~r/^(.*?),?\s+\(?and\s+((?:sub-?)?sections?\s+\S+(?:\s+and\s+\(\w+\))?)\s+(?:in\s+)?so\s+far\s+as\s+(?:(?:it|they)\s+relates?|relating)\s+thereto\b.*$/is

  # a line's items: [{refs, purposes, territory}] and the Schedule context
  # its paragraphs carry to the next lines
  defp items(line, aliases, sch) do
    case Regex.run(@thereto, line) do
      [_, rest, section] ->
        {items, next} = items(rest, aliases, sch)
        qualified = refs(section, nil)

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

  defp split_items(before, last, aliases, sch) do
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

  @schedule_entries ~r/^\W*In\s+(?:the\s+Schedule|Schedule\s+(\d+[A-Z]*))?\s*(?:to\s+the\s+Act\s*)?[,—–:]\s*the\s+(repeals?|entr(?:y|ies))\b(.*)$/isu

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

        {[{[ref], :in_relation_to, Territory.of(line)} | items], sch}

      nil ->
        own_line_items(line, aliases, sch)
    end
  end

  # (an item's bracketed heading is no territory and no purpose of its own:
  # "section 86 (water and sewerage undertakers in England: …)", SI 2022/48)
  defp own_line_items(line, aliases, sch) do
    line = line |> drop_other_laws(aliases) |> Asides.drop_headings()

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
           list
           |> split_items()
           |> Enum.flat_map(&String.split(&1, ~r/\s+and\s+(?![^()]*\))/u))
           |> bare_brackets(),
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
            [{rs, nil, Territory.of(line)}]
          else
            _ -> []
          end

        [{refs, purposes, Territory.of(line)} | related]
      end
      |> List.flatten()
    else
      _ -> nil
    end
  end

  # a bare "(7)" after an item: one item with it where that has no qualifier
  # of its own ("10(6) and (7) (so far as aforesaid)", its qualifier both's:
  # SI 1974/1439), else its section's own ("83(1) (so far as it relates to
  # …) and (2)": s.83(2) fully, SI 1964/1045)
  defp bare_brackets(items), do: items |> Enum.reduce([], &bare_bracket/2) |> Enum.reverse()

  defp bare_bracket(item, [prev | rest] = acc) do
    with [_, number] <- Regex.run(~r/^(\d+[A-Z]*)/u, prev),
         true <- item =~ ~r/^\(\w+\)/u do
      if bracket_of(prev),
        do: [after_qualified(prev, number, item) | acc],
        else: [prev <> " and " <> item | rest]
    else
      _ -> [item | acc]
    end
  end

  defp bare_bracket(item, []), do: [item]

  # the bare bracket at its own level after the qualified item's last
  # designator: "118(1)(a), …, (m) (in so far as it relates to section 111),
  # (n)" → 118(1)(n) (SI 1992/3253 art.3)
  defp after_qualified(prev, number, item) do
    [_, bracket, rest] = Regex.run(~r/^((?:\(\w+\))+)(.*)$/su, item)

    case prev |> without_qualifiers() |> list_refs("") |> List.last() do
      nil -> number <> item
      last -> Sibling.of(last |> String.split("..") |> List.last(), bracket) <> rest
    end
  end

  defp without_qualifiers(item),
    do: String.replace(item, ~r/\s*\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, "")

  # an item's own qualifier: its bracket with words in it
  defp bracket_of(item) do
    case Regex.run(~r/\(((?=[^()]*\s)(?:[^()]|\([^()]*\))*)\)\s*$/u, item) do
      [_, q] -> if Regex.match?(@bracket_qualifier, "(" <> q), do: q
      nil -> nil
    end
  end

  defp plain_line_items(line, _aliases, sch) do
    # (the rest of it, for one place: "Schedule 8 in so far as it relates to
    # England and Wales and has not already been commenced", SI 1992/2984)
    {line, place} = Territory.completing(line)
    territory = place || Territory.of(line)
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

  # "Part I of the 1998 Act except section 4" (SI 1998/1658): the Part,
  # the section excepted — never both commenced (CV-06 round 2)
  defp split_excepted(own, sch) do
    case Regex.split(~r/\s+except\s+(?=(?:sections?|regulations?|articles?)\s+\d)/i, own,
           parts: 2
         ) do
      [main, ex] -> {main, refs(Asides.strip(ex), sch)}
      [_] -> {own, []}
    end
  end

  # "… the following paragraphs of Schedule 22— 1, 3, 5 to 12": a bare
  # list on the line, or a line of only numbers under such a heading
  defp own_refs(own, related, sch) do
    refs(Asides.strip(own), sch) ++
      if(related == "", do: bare_paragraphs(own, sch), else: [])
  end

  defp own_purposes(line, ""),
    do: if(Regex.match?(@partial, Regex.replace(@full, line, "")), do: purposes(line))

  defp own_purposes(_line, related), do: purposes(related)

  defp own_item(own, own_refs, excepted, purposes, territory) do
    case {excepted, except_subsections(own, own_refs)} do
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
        refs = refs(Asides.strip(related), context) ++ bare_paragraphs(related, sch)
        related_ref_items(related, refs, territory)
    end
  end

  defp related_ref_items(_related, [], _territory), do: []

  defp related_ref_items(related, refs, territory) do
    cond do
      Regex.match?(@entries_head, related) ->
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
      |> String.replace(@full, "")

    asides = paragraph_asides(related, refs)
    except = for {ref, aside} <- asides, e <- excepted(ref, aside), do: e
    partial = for {ref, aside} <- asides, excepted(ref, aside) == [], partial?(aside), do: ref
    purposes = if(Regex.match?(@partial, rest), do: purposes(rest))

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

  defp excepted(ref, aside), do: except_subsections("(" <> aside <> ")", [ref]) || []

  defp partial?(aside),
    do: Regex.match?(@partial, aside) and not Regex.match?(@full, aside)

  # a bare list of a Schedule's paragraphs whose items carry their own
  # qualifiers ("1, 3, … 29(1) in so far as it is not already in force, 30,
  # 32 to 35": SI 1996/186 reg.3, CV-S04 round 2) — each item its own, never
  # one item's qualifier over the list; nil for any other text
  @item_qualifier ~r/\s+(?:(?:in\s+)?so\s*far\s+as|to\s+the\s+extent|except|for\s+the\s+purposes?\s+of|in\s+relation\s+to)\b.*$/is

  defp bare_items(text, sch, territory) do
    if sch && text =~ ~r/^\s*\d/ && (Regex.match?(@partial, text) or Regex.match?(@full, text)) do
      for item <- split_items(text),
          plain = Regex.replace(@item_qualifier, item, ""),
          refs = list_refs(Asides.strip(plain), "sch.#{sch}.para."),
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

  # a line whose bracket is still open goes on in the next: legislation.gov.uk
  # splits one item across list items inside its aside ("… section 31(2)(b)
  # of the Control of" | "Pollution Act 1974) and (3), 20, …": SI 1991/1042
  # art.2(1), CV-S09 round 6)
  defp join_open(lines) do
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

  # an aside naming another law qualifies its item only: "16(1), (2) (in so
  # far as it inserts a new paragraph (v) in section 31(2)(b) of the
  # Control of Pollution Act 1974) and (3), 20, …" — the other law's tail
  # had eaten the list to its end (SI 1991/1042 art.2(1), CV-S09 round 6)
  @law_named ~r/\b(?:Act|Order|Regulations|Measure)\s+\d{4}\b/u

  defp drop_law_asides(line) do
    {out, aside, _} =
      line
      |> String.graphemes()
      |> Enum.reduce({"", "", 0}, fn
        "(", {o, _a, 0} -> {o, "(", 1}
        "(", {o, a, d} -> {o, a <> "(", d + 1}
        ")", {o, a, 1} -> {o <> keep_aside(a <> ")"), "", 0}
        ")", {o, a, d} when d > 1 -> {o, a <> ")", d - 1}
        ch, {o, a, 0} -> {o <> ch, a, 0}
        ch, {o, a, d} -> {o, a <> ch, d}
      end)

    out <> aside
  end

  # (a qualifying aside leaves its item partly in force: "section 30 (except
  # for the purposes of any inquiry … under section 98 … of the 1990 Act)":
  # SI 1991/2728 art.3)
  defp keep_aside(aside) do
    cond do
      not Regex.match?(@law_named, aside) -> aside
      Regex.match?(@full, aside) -> ""
      Regex.match?(@partial, aside) -> " (for certain purposes)"
      true -> ""
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
             ~r/\(\s*except\s+(?:sub-?)?(?:sections?|paragraphs?)\s+((?:\([0-9A-Za-z]+\)|\s|,|and)+)\)/i,
             text
           ),
         [_ | _] = chains <- Regex.scan(~r/(?:\([0-9A-Za-z]+\))+/, list) |> List.flatten() do
      number = String.replace(ref, ~r/^[a-z.]+\./i, "")
      prefix = String.replace_suffix(ref, number, "")

      chains
      |> Enum.map_reduce(nil, fn chain, last ->
        full = if last, do: Sibling.of(last, chain), else: number <> chain
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
        list_refs(Asides.strip(list), "sch.#{s}.para.")

      nil ->
        if sch && text =~ ~r/^\s*\d/,
          do: list_refs(Asides.strip(text), "sch.#{sch}.para."),
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

  # a statement's own place ("… come into force in relation to England on …")
  # reaches all its items; a table row's is its own, never its subject
  # column's ("Section 14 | Disposal of waste in England and Wales": SI
  # 1988/818)
  defp head_territory(%Rule{treatment: :order_schedule}), do: nil

  defp head_territory(%Rule{source: %{text: text}}) when is_binary(text),
    do: text |> String.split(" … ", parts: 2) |> hd() |> Territory.of()

  defp head_territory(_rule), do: nil

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
  # a table row naming only a Part by its title in brackets: "Part I (Waste
  # on Land)"; a bare "Part II" is an item (SI 1991/2187 "Part II", "Part III")
  @part_heading ~r/^\s*Part\s+(?:[IVXL]+|\d+)[A-Z]?\s*\([^()]*\s[^()]*\)\s*$/

  # an item opening with another law's title: "The Public Health Act 1936,
  # sections 72(1) to (5), and 73 to 76;" (SI 1988/818, the repeals its
  # s.108(2) row names)
  @opens_other_law ~r/^\s*(?:the\s+)?((?:[A-Z(][\w()',.-]*\s+){1,10}(?:Act|Order|Regulations|Measure)\s+\d{4})\s*,/u

  # "sections 2 and 3 of the Gas Act 1986": another law's provisions
  # (opening its sentence: "Section 105 of the 2023 Act … comes into force":
  # SI 2024/452 reg.4; a Part: "for the purposes of the application of Part 1
  # of the 2006 Act": SI 2021/1322; with its Chapter and Schedule: "section
  # 63(3)(b), Chapter 1 of Part 4 and section 86 of, and Schedule 5 to, the
  # Police Act 1996": SI 2004/913; "sections 1(3) and 32(5) of and Schedule 2
  # to the 1996 Act": SI 1999/3271)
  @other_law_provisions ~r/\b(?i:sections?|paragraphs?|Schedules?|regulations?|articles?|Parts?)\s+\d+(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*(?:Chapter\s+\w+\s+of\s+Part\s+\w+|(?:sections?\s+)?(?:\d+(?:[A-Z]+\d*)*)?(?:\([0-9A-Za-z]+\))*))*(?:\s*\([^()]*\))?,?\s+(?:of|to|into),?\s+(?:and\s+(?:(?:Schedules?|paragraphs?|Parts?|of|and|\d+[A-Z]*(?:\([0-9A-Za-z]+\))*|\([0-9A-Za-z]+\))[\s,]+)+?to,?\s+)?(?:Schedule\s+\d+[A-Z]*\s+to\s+)?(?:the\s+)?((?:\d{4}\s+)?(?:[A-Z(][\w()',.-]*\s+){0,10}(?:(?:of|and|for|the|in|on|at|to|with|etc\.)\s+(?:[A-Z(][\w()',.-]*\s+){0,8})*(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)/u

  # "Articles 3 to 20 and 49A to 52 of and Schedules 1, 2, 3 and 5 to the
  # Fire Services (Northern Ireland) Order 1984" (NISR 2006/257 art.2(e)):
  # another Order's Articles, what a repeals Schedule relates to
  @other_order_articles ~r/\bArticles?\s+\d[^;]*?\s+(?:of|to)\s+the\s+((?:[A-Z(][\w()',.-]*\s+)(?:(?:[A-Z(][\w()',.-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}Order\s+\d{4})/u

  @quoted ~r/“[^”]*”|"[^"]*"|‘[^’]*’/u
  @ends_other_law ~r/,\s+to\s+the\s+((?:\d{4}\s+)?[A-Z(][\w()',.-]*(?:\s+(?:[A-Z(][\w()',.-]*|of|and|for|the|in|on|at|to|with|etc\.))*\s+(?:Act|Order|Regulations|Measure)(?:\s+\d{4})?)\s*[,.]?\s*$/u

  # the headings that go with a range are no provisions of their own, and
  # the range still belongs to the law named after them: "sections 33A to
  # 33C and 33E to 33O including italic headings immediately preceding
  # section 33J and section 33O of the 2000 Act" (SI 2012/57 art.4(1))
  @italic_headings ~r/,?\s+including\s+(?:the\s+)?italic\s+(?:cross-?)?headings?\s+(?:immediately\s+)?(?:preceding|before)\s+(?:that\s+section|(?:sections?\s+)?\d+(?:[A-Z]+\d*)*(?:\s+and\s+(?:sections?\s+)?\d+(?:[A-Z]+\d*)*)*)/iu

  defp drop_other_laws(line, aliases) do
    own? = &own_law?(&1, aliases)

    line =
      line
      |> String.replace(@quoted, " ")
      |> String.replace(@italic_headings, "")
      |> drop_law_asides()
      |> String.split(~r/;\s*/u)
      |> Enum.reject(&other_law_item?(&1, own?))
      |> Enum.map_join("; ", &OtherLaw.drop_that_law(&1, own?))

    keep_own = fn whole, law -> if own?.(law), do: whole, else: "" end

    [@other_order_articles, @other_law_tail, @titled, @other_law_provisions]
    |> Enum.reduce(line, fn re, line ->
      Regex.replace(re, line, keep_own)
    end)
  end

  # "the Act", or a name its aliases hold
  defp own_law?(law, aliases),
    do:
      Enum.any?(aliases, &String.contains?(norm("the " <> law), &1)) or
        norm(law) in ["act", "the act"] or short_title?(norm(law), aliases)

  # the Act's title without its year, or cut at "Act" before its bracket:
  # "Section 116 of the Environment Act, insofar as …" (SI 1998/781),
  # "Schedule 3 to the Environmental Better Regulation Act (Northern
  # Ireland) 2016" (NISR 2016/332)
  defp short_title?(name, aliases),
    do: name =~ ~r/^[a-z].* / and Enum.any?(aliases, &String.starts_with?(&1, name <> " "))

  # an item ending or opening with another law's name
  defp other_law_item?(item, own?) do
    case Regex.run(@ends_other_law, item) || Regex.run(@opens_other_law, item) do
      [_, law] -> not own?.(law)
      nil -> false
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

  defp refs(text, sch) do
    {of_section, text} = text |> ScheduleParts.as_place() |> subsections_of()
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
        part_refs(text, sch) ++ bare ++ paragraph_refs(text, sch)
    )
    |> Enum.reject(&(&1 =~ ~r/^s\.\(/))
  end

  defp section_refs(text) do
    for [_, list] <- Regex.scan(~r/\bsections?\s+#{@list}/i, text),
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
  defp schedule_part_refs(text) do
    for [_, list, n] <-
          Regex.scan(
            ~r/\bParts?\s+(#{@part}(?:\s*(?:,|and)\s*#{@part})*)\s+of\s+Schedule\s+(\d+[A-Z]*)\b#{@own}/,
            text
          ),
        p <- String.split(list, ~r/\s*(?:,|and)\s*/, trim: true),
        do: {n, "sch.#{n}.pt.#{p}"}
  end

  # "in Schedule 13 to the Act, paragraphs …" is where, not what; "Schedule
  # 1 to this Order" is the order's own (AR-12: SI 1999/2830)
  defp schedule_refs(text, bare, schedule_parts) do
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
  end

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

  defp paragraph_refs(text, nil) do
    for [_, list, s] <-
          Regex.scan(~r/\bparagraphs?\s+#{@list}\s+of\s+Schedule\s+(\d+[A-Z]*)/i, text),
        r <- list_refs(list, "sch.#{s}.para."),
        do: r
  end

  defp paragraph_refs(text, s) do
    for [_, list] <- Regex.scan(~r/\bparagraphs?\s+#{@list}/i, text),
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
  defp list_refs(list, prefix) do
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
        {place, limit} = {schedule_territory(order, el), schedule_limit(order, el)},
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
            territory: territory || column_territory(purpose) || place,
            purposes: table_purposes(purpose, purposes) || limit,
            source: %{
              law: order.law_name,
              ref: source_ref(id),
              text: squash("#{row} | #{purpose}")
            },
            treatment: :order_schedule
          )
  end

  # a Schedule (or each of its Parts) listing the provisions as items, not a
  # table: "SCHEDULE 1 PROVISIONS COMING INTO FORCE ON 8TH JUNE 2005 Article
  # 2(1) — Section 1(2). Section 1(3), except paragraph (e). …" (SI
  # 2005/1444), dated as a table is (its title, its Reference, the article
  # bringing it in); a Schedule with Parts is read by its Parts
  defp schedule_lists(order, aliases) do
    for id <- order.ids,
        String.match?(id, ~r/^schedule(-\d+[A-Z]*)?(?:-part-[IVXL\d]+[A-Z]?)?$/),
        not has_parts?(order, id),
        el = Doc.element(order, id),
        table_rows(el) == [],
        date = schedule_date(order, el),
        date != nil,
        head = "Schedule list #{id}",
        {place, limit} = {schedule_territory(order, el), schedule_limit(order, el)},
        rule <- item_rules(list_lines(el), aliases, date, order.law_name, id, head),
        do: %{
          rule
          | treatment: :order_schedule,
            territory: rule.territory || place,
            purposes: rule.purposes || limit
        }
  end

  # the one place the articles bringing a Schedule in name: "The provisions
  # … specified in the Schedule to this Order … shall come into force in
  # England and Wales … on 6th June 1988" (SI 1988/818 art.2) reaches each
  # row that names none; nil where they name none, or more than one
  defp schedule_territory(order, el) do
    Territory.only([reference_words(order, el) | intro_words(order, el)])
  end

  # the articles bringing a Schedule (or its Schedule, for a Part) in, where
  # they bring it in "Except in relation to" some cases: partly in force
  # ("Except in relation to the premises to which Article 2 of this Order
  # applies, the provisions … specified in … each of the Parts of Schedule 1
  # …": SI 1964/191 art.1, covered markets); nil where none so limits it
  @except_cases ~r/^\W*(?:\d+\s+)?(?:\(\d+\)\s*)?(?:Except|Save)\s+(?:in\s+relation\s+to|as\s+respects)\b/i

  defp schedule_limit(order, el) do
    id = xpath(el, ~x"./@id"s)
    schedule = String.replace(id, ~r/-part-[IVXL\d]+[A-Z]?$/, "")

    words =
      [reference_words(order, el) | intro_words(order, el)] ++ whole_words(order, schedule, id)

    if Enum.any?(words, &Regex.match?(@except_cases, &1)), do: :in_relation_to
  end

  # (a Part's Schedule, as its articles name it: "each of the Parts of
  # Schedule 1")
  defp whole_words(_order, id, id), do: []

  defp whole_words(order, schedule, _id) do
    case Doc.element(order, schedule) do
      nil -> []
      whole -> intro_words(order, whole)
    end
  end

  defp has_parts?(order, id),
    do: Enum.any?(order.ids, &String.match?(&1, ~r/^#{Regex.escape(id)}-part-[IVXL\d]+[A-Z]?$/))

  # the items, never the Schedule's number, title or Reference
  defp list_lines(el) do
    el
    |> xpath(
      ~x"./*[not(local-name()='Number' or local-name()='Title' or local-name()='TitleBlock' or local-name()='Reference')]"l
    )
    |> Enum.flat_map(&Doc.lines/1)
    |> join_open()
    |> Enum.map(&clean_line/1)
    |> Enum.reject(&(&1 == ""))
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

  # Parts dated in their titles, each read alone; an Appendix Part with no
  # table of provisions — a list, or a repeals table of other Acts
  # (Chapter | Short Title | Extent of repeal) — leaves the Schedule's own
  # table to it (SI 1977/1365)
  defp dated_parts?(order, id) do
    not String.contains?(id, "-part-") and
      Enum.any?(order.ids, fn part ->
        String.match?(part, ~r/^#{Regex.escape(id)}-part-[IVXL\d]+[A-Z]?$/) and
          part_date(order, part) != nil and
          order |> Doc.element(part) |> table_rows() |> Enum.any?(&provision_row?/1)
      end)
  end

  defp provision_row?({first, _}),
    do:
      first =~
        ~r/^\W*(?:sub-?)?(?:sections?|schedules?|parts?|paragraphs?|in\s+(?:section|schedule))\b/i

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

  # a table's second column, where it is a purpose ("In relation to Wales"),
  # never where it is the provision's subject
  defp column_territory(purpose) when is_binary(purpose),
    do: if(purpose =~ @purpose_opening, do: Territory.of(purpose))

  defp column_territory(_purpose), do: nil

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
    # a repealed Act by its chapter ("1894 c. 60.": an Appendix of repeals,
    # SI 1995/965) is no provision of the Act's
    |> Enum.reject(fn cells ->
      List.first(cells, "") =~ ~r/^[\w&.,\s]{0,40}\bc\.\s*\d+\s*\.?\s*$/
    end)
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
    |> then(fn {acc, parent} -> flush_last(acc, parent) end)
    |> Enum.reverse()
  end

  # a row with no subject is a heading for the rows under it ("Section 44" over
  # "paragraph 3 …"); with none under it, it is an item itself (AR-15: SI
  # 1999/2830 "Section 31 and in Schedule 7, …" has no subject cell) — but a
  # Part's name with rows after it groups them, never commences the Part (SI
  # 1988/818 "Part VI (Miscellaneous and General)" over its sections had COPA
  # 1974 s.101 in force)
  defp flush(acc, {text, false}) do
    if text =~ @part_heading, do: acc, else: [{text, ""} | acc]
  end

  defp flush(acc, _parent), do: acc

  defp flush_last(acc, {text, false}), do: [{text, ""} | acc]
  defp flush_last(acc, _parent), do: acc

  defp schedule_date(order, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    case parse_dates(title) do
      [d] -> d
      _ -> article_date(order, el) || intro_date(order, el)
    end
  end

  # a Schedule with no date and no Reference: the one date of the articles
  # bringing it in ("The provisions … specified in column 1 of the Schedule
  # to this order … shall come into force on 14th June 1976": SI 1976/731)
  defp intro_date(order, el) do
    case order |> intro_words(el) |> Enum.flat_map(&parse_dates/1) |> Enum.uniq() do
      [d] -> d
      _ -> nil
    end
  end

  # the words of the articles that bring the Schedule (or its Part) in
  defp intro_words(order, el) do
    id = xpath(el, ~x"./@id"s)
    names = if String.contains?(id, "-part-"), do: part_named(id), else: schedule_named(id)

    order.ids
    |> Enum.filter(&String.match?(&1, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/))
    |> Enum.map(&Text.words_of(order, &1))
    |> Enum.filter(&(Regex.match?(@cif, &1) and Regex.match?(names, &1)))
  end

  # the words of the article the Schedule's Reference names ("Article 2")
  defp reference_words(order, el) do
    with ref when ref != nil <- xpath(el, ~x"./Reference"),
         [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)) do
      Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}")
    else
      _ -> ""
    end
  end

  defp schedule_named("schedule"),
    do:
      ~r/\bthe\s+Schedule\b(?!\s+\d)(?:\s+(?:to\s+th(?:is|e)\s+(?:Order|order|Regulations)|hereto))?(?!\s+to\s+the\s+(?:\d{4}\s+|said\s+|principal\s+)?Act)/

  defp schedule_named("schedule-" <> n),
    do:
      ~r/\bSchedule\s+#{Regex.escape(n)}\b(?!\s+to\s+the\s+(?:\d{4}\s+|said\s+|principal\s+)?Act)/

  defp schedule_named(_id), do: ~r/(?!)/

  # "Part 1 of the Schedule hereto" (SI 2002/1014), "Part I of Schedule 2"
  defp part_named("schedule-part-" <> p),
    do: ~r/\bPart\s+#{Regex.escape(p)}\s+of\s+the\s+Schedule\b(?!\s+\d)/

  defp part_named("schedule-" <> rest) do
    case String.split(rest, "-part-") do
      [n, p] -> ~r/\bPart\s+#{Regex.escape(p)}\s+of\s+Schedule\s+#{Regex.escape(n)}\b/
      _ -> nil
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
