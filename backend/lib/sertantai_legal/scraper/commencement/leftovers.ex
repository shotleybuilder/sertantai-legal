defmodule SertantaiLegal.Scraper.Commencement.Leftovers do
  @moduledoc """
  The words of a commencement statement that bear on when provisions came
  into force and that no rule read from it uses: the long tail of forms
  the readers half-read, found in code over every statement held, not by
  sampling (Jason 2026-11-05, after two agent rounds of whack-a-mole on
  Maritime Safety). Kinds:

  - `:date` — a stated date no rule's `when` holds ("… 30th November 2019"
    after a ";": SI 2018/1107);
  - `:exception` — a provision after "except", "other than", "apart from"
    or "save that" in no rule's exception (SI 2012/2267 reg.3(3)(b)), nor
    dated apart beside a rule for the rest ("save that regulations 9 and
    12(1)(b) shall come into force on …"); an order's "rest of the Act,
    except sections 85 to 87" read as those sections is one (SI 1996/3146);
  - `:provision` — a numbered provision of the law's own in no rule's
    scope or exception;
  - `:qualifier` — "in relation to", "for the purposes of", "so far as",
    "to the extent that" with no partial rule (SI 2007/3075 reg.1(a)); a
    completing "so far as not already in force", "for all other purposes"
    never counts;
  - `:relative_day` — "the 22nd day after", "laid", "notified", "the end of
    the period" with no relative rule (SI 2018/1221).

  A mention ("before regulation 2 comes into force") has none; another
  law's provisions are never the statement's own (the reader's ref
  extractor, given as `refs`, leaves them out). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, OrderPatterns, Rule, SentencePatterns}
  alias SertantaiLegal.Scraper.LawStart.{Clause, Provisions}

  @type leftover :: %{
          kind: :date | :exception | :provision | :qualifier | :relative_day,
          words: String.t()
        }

  @months ~w(January February March April May June July August September October November December)
  @date Regex.compile!(
          "\\b\\d{1,2}\\s*(?:st|nd|rd|th)?\\s+(?:day\\s+of\\s+)?(?:#{Enum.join(@months, "|")}),?\\s+\\d{4}\\b"
        )
  @except ~r/\b(?:except(?:\s+for)?|other\s+than|apart\s+from|save\s+that)\s+(?!(?:in\s+relation\s+to|(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent|for\s+the\s+purposes?\s+of|as\s+(?:already|aforesaid))\b)([^,;]+?)(?=\s*(?:,|;|\bwhich\b|\b(?:shall|comes?|is\s+to|are\s+to)\b|$))/i
  @completing ~r/\b(?:(?:(?:in\s+)?so\s+far|insofar|to\s+the\s+extent)\s+(?:as|that)\s+(?:(?:it|they|th(?:at|ose|ese)\s+[\w-]+)\s+(?:is|are|has|have)\s+)?not\s+(?:already\s+|yet\s+|previously\s+|then\s+)?(?:been\s+)?(?:in\s+force|commenced|brought\s+into\s+force)|for\s+all\s+(?:other\s+|remaining\s+)?purposes|except\s+(?:(?:in\s+)?so\s+far\s+)?as\s+(?:it\s+is\s+|they\s+are\s+)?already\s+in\s+(?:force|operation)|except\s+as\s+aforesaid)\b/i
  @qualifier ~r/\b(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\b/i
  @place ~r/\b(?:in\s+relation\s+to|as\s+respects)\s+(?:England\s+and\s+Wales|Great\s+Britain|England|Wales|Scotland|Northern\s+Ireland)\b/i
  @relative ~r/\bthe\s+(?:\w+\s+)?day\s+after\b|\blaid\b|\bnotified\b|\bthe\s+end\s+of\s+the\s+period\b/i

  # a power to provide for something to come into force, never a statement
  # ("… include power to provide for the provision to come into force
  # although the agreement has not come into force": MSA 1995 s.84B(10))
  @power ~r/\b(?:power|powers|may|shall)\b[^.;]{0,80}\bprovide\s+for\b[^.;]{0,120}\bto\s+come\s+into\s+(?:force|operation)\b|\bmay\s+be\s+made\s+so\s+as\s+to\s+come\s+into\b/i

  # another instrument coming into force — regulations an Act requires, a
  # code's amendments, arrangements, a notice — never the law's own
  # provisions ("The regulations required by subsection (1) must come into
  # force …": asp 2010/5 s.38(2)); "These Regulations" is the law
  @instrument ~r/^\W*(?:(?:the|any|an?|such)\s+)?(?:[\w-]+\s+){0,3}(?:regulations|orders?|schemes?|codes?(?:\s+of\s+practice)?|arrangements|amendments|notices?|directions?|byelaws|determinations?|designations?|instruments?)\b(?!\s*\d|\s+of\s+this\s+(?:Act|Order))[^.;]{0,160}?\b(?:must|shall|may|will)?\s*(?:comes?|come)\s+into\b/i

  # a pointer to where something else is provided, never what is excepted
  # or named ("Except as provided by subsection (2)", "Subject to
  # subsection (2)", "in accordance with …": s.183(1) of 2017 c.3)
  @pointer ~r/\b(?:except\s+as\s+(?:otherwise\s+)?(?:provided|mentioned|specified|set\s+out)\s+(?:for\s+)?(?:by|in|under)|subject\s+to|in\s+accordance\s+with|(?:as|to\s+the\s+extent)\s+(?:provided|mentioned|specified)\s+(?:by|in|under))\s+[^,;]*/i

  # the order's power over its own transition, never a qualifier of the
  # day: "…, and, for the purposes of the transition …, the Order
  # appointing the day may provide that …" (1971 c.19 s.6(5))
  @order_may ~r/[,;]\s*and,?\s+[^;]*?\bthe\s+(?:Order|order|instrument)\s+(?:appointing|bringing)\b[^;]*?\bmay\s+(?:provide|make|contain)\b.*$/is

  # (also another Act's provision an order of the family's commences: NISR
  # 2012/286 "Section 2(1)(d) of the Corporate Manslaughter … Act 2007 shall
  # come into force …"; a counterfactual mention: "had the Order in Council
  # come into force before …", 1994 c.21 s.8(4))
  # something else coming into force, or its terms: a deemed day of a
  # thing that is no provision ("the Concession shall be taken to have
  # come into operation": 1987 c.53 s.4(3)), EU law (2018 c.16 s.8(4)), a
  # reading rule ("References in subsections (1) to (5) to provision …":
  # 2014 c.21 s.55(6)), what another enactment provides (1982 c.16 s.97(6)),
  # a limit on a scheme's day ("The day specified by a scheme … for the
  # scheme to come into force must not fall after …": 2000 c.21 s.92(9))
  @not_ours ~r/^\W*(?:for\s+the\s+purposes\s+of\s+this\s+(?:Act|Part),\s*)?the\s+(?!(?:provisions?|sections?|Act|Part|Schedule|regulations?|articles?)\b)[a-z][\w-]*\s+(?:shall|is\s+to)\s+be\s+(?:taken|treated|deemed)\s+to\s+have\s+come\s+into\b|\bEU\s+law\b[^.;]*\bcomes?\s+into\b|^\W*References?\s+in\s+(?:sub)?(?:sections?|paragraphs?|regulations?)\b|\b(?:enactment|Act|order|instrument)\s+provides\s+that\b[^.;]*\bcome\s+into\b|^\W*(?:Sections?|Regulations?|Articles?|Paragraphs?|Schedules?|Parts?)\s+[\w()]+(?:\s*(?:,|and|to)\s*[\w()]+)*\s+of\s+the\s+(?:[A-Z][\w(),'-]*\s+){1,14}(?:Act|Order|Regulations)(?:\s+\([^)]*\))?\s+\d{4}\b[^.;]*?\b(?:shall\s+)?comes?\s+into\b|\bhad\s+the\s+[^.;]{1,60}?\bcome\s+into\s+(?:force|operation)\b|\bfor\s+the\s+(?:scheme|order|regulations|instrument|code)\s+to\s+come\s+into\s+(?:force|operation)\b/i

  # the entries a repeal names are other Acts' provisions ("Schedule 10, the
  # following repeals:— The Employment Medical Advisory Service Act 1972-
  # sections 1 and 6 …": SI 1974/1439 Sch. 2)
  # how a provision applies, never when it comes in ("…, save that the
  # references to “civil partner” in … regulation 2 shall not apply in
  # relation to any time before …": SI 2005/881 reg.1(1))
  @not_applying ~r/,?\s*save\s+that\b[^.;]*?\bshall\s+not\s+apply\b.*$/is

  @repeal_entries ~r/\bthe\s+following\s+(?:repeals|entries)\b.*$/is

  # another law's provisions, before a range's dash or a list's commas part
  # them from their Act ("sections 47–50 of the Countryside and Rights of
  # Way Act 2000": SI 2006/1176 art.6; "relating to sections 5, 6 and 28 of
  # the Local Government Act 1999": 2007 c.28 s.245(4)), and a repeal of
  # another Act's provision ("the repeal of section 6 of the 1989 Act": SI
  # 2015/425 art.4(3))
  @other_law ~r/\b(?:(?:sub-?)?sections?|regulations?|paragraphs?|articles?)\s+[\w()]+(?:\s*(?:,|and|to|–|-)\s*[\w()]+)*\s+(?:of|to)\s+the\s+(?:\(?[A-Z][\w(),'.-]*\s+|(?:and|of|the|for|in|on|to|etc\.?)\s+){1,16}(?:Act|Order|Regulations|Measure)\s+\d{4}\b|\bthe\s+repeals?\s+(?:of|to|in)\s+[^,;]*?\bof\s+the\s+\d{4}\s+(?:Act|Order|Regulations)\b/u

  # no time stated and no rule read: a condition or description, never a
  # statement ("… until section 55 comes into force")
  @time ~r/\bon\b|\bfrom\b|\bat\s+the\s+end\b|\bday\b|\bdate\b|\bby\s+order\b|\bappoint|\bpass(?:ed|ing)\b|\bmade\b|\bexit\b/i

  @doc """
  The leftovers of `statement` (a sentence, with its list items when it
  opens a list) given the `rules` read from it — the law's own rule too
  when its start was read from it — and `refs`, the reader's own ref
  extractor (text → bare refs: "reg.7", "s.85..s.87").
  """
  @spec of(String.t(), [Rule.t()], (String.t() -> [String.t()])) :: [leftover()]
  def of(statement, rules, refs) do
    statement =
      @pointer
      |> Regex.replace(statement, ",")
      |> then(&Regex.replace(@order_may, &1, "."))
      |> then(&Regex.replace(@repeal_entries, &1, ""))
      |> then(&Regex.replace(@not_applying, &1, "."))
      # quoted words are words, never provisions ("the words “section 48,”":
      # SI 1996/1609)
      |> then(&Regex.replace(~r/“[^”]*”/u, &1, "“”"))
      |> close_brackets()

    # (a commencement only in quoted words is an amendment's text: SI
    # 2026/82 reg.12(2))
    if not (statement =~ ~r/\binto\s+(?:force|operation)\b/i) or Clause.mention?(statement) or
         power?(statement) or instrument?(statement) or
         Regex.match?(@not_ours, statement) or no_when?(statement, rules) do
      []
    else
      (dates(statement, rules) ++
         exceptions(statement, rules, refs) ++
         provisions(statement, rules, refs) ++
         qualifiers(statement, rules) ++ relative_days(statement, rules))
      |> Enum.uniq()
    end
  end

  @relates_to ~r/\b(?:(?:in\s+)?so\s+far|insofar)\s+as\s+(?:it|they)\s+relates?\s+to\s+[^);]*/i

  # a bracket the text leaves open closes at its end (legislation.gov.uk's
  # "Section 83(3) (so far as it relates to section 29(2), (4) and (5)": SI
  # 1964/191)
  defp close_brackets(s) do
    open = length(String.split(s, "(")) - length(String.split(s, ")"))
    if open > 0, do: s <> String.duplicate(")", open), else: s
  end

  defp power?(s), do: Regex.match?(@power, s)

  defp instrument?(s) do
    # (after a lead-in: "For the purpose of this article, a CFD transfer
    # notice comes into force—": SSI 2009/140 reg.21B(8))
    s =
      String.replace(
        s,
        ~r/^\W*(?:for\s+the\s+purposes?\s+of|subject\s+to)\s+[^,]{1,120},\s*/i,
        ""
      )

    Regex.match?(@instrument, s) and
      not (s =~ ~r/^\W*(?:These|This)\s+(?:Regulations|Order|Rules)\b/)
  end

  defp no_when?(s, []),
    do: not Regex.match?(@time, String.replace(s, ~r/^.*?\binto\s+(?:force|operation)\b/is, ""))

  defp no_when?(_s, _rules), do: false

  defp dates(s, rules) do
    held = for %Rule{when: {:date, d}} <- rules, into: MapSet.new(), do: d

    for [words] <- Regex.scan(@date, s),
        d = Clause.date_at_start(words),
        d != nil,
        not MapSet.member?(held, d),
        do: %{kind: :date, words: words}
  end

  defp exceptions(s, rules, refs) do
    s = other_law(s)
    excepted = Enum.flat_map(rules, & &1.except)
    general? = Enum.any?(rules, &(&1.scope in [:all, :rest]))

    named =
      if general?,
        do: Enum.flat_map(rules, &List.wrap(if is_list(&1.scope), do: &1.scope)),
        else: []

    for [_, words] <- Regex.scan(@except, s),
        ref <- refs.(words),
        not schedule?(ref),
        not covered?(ref, excepted ++ named),
        do: %{kind: :exception, words: ref}
  end

  defp provisions(s, rules, refs) do
    s = other_law(s)
    used = Enum.flat_map(rules, &(List.wrap(if is_list(&1.scope), do: &1.scope) ++ &1.except))
    excepted = for [_, words] <- Regex.scan(@except, s), ref <- refs.(words), do: ref
    # "the following provisions of Part 1 …": the Part is where they are
    container? = s =~ ~r/\bprovisions\s+of\s+(?:Parts?|Chapters?)\b/i

    # what a partial rule's qualifier relates to is its object, never
    # commenced ("Section 83(3) (so far as it relates to section 29(2), (4)
    # and (5))": SI 1964/191)
    s =
      if Enum.any?(rules, &(not Rule.full?(&1))),
        do: Regex.replace(@relates_to, s, ""),
        else: s

    for segment <- @except |> Regex.replace(s, ",") |> segments(),
        ref <- refs.(segment),
        not schedule?(ref),
        not (container? and String.starts_with?(ref, ["pt.", "ch."])),
        ref not in excepted,
        not covered?(ref, used),
        not with_the_whole?(s, rules),
        do: %{kind: :provision, words: ref}
  end

  defp other_law(s), do: Regex.replace(@other_law, s, "another law")

  # one time for the whole law, stated once: the provisions it names come
  # in with it ("This section and sections 44 to 52 come into force on such
  # day as …", the Act wholly by order: asp 2009/12 s.100(2))
  defp with_the_whole?(s, rules) do
    Enum.any?(rules, &(&1.scope == :all and &1.except == [])) and
      length(Regex.scan(@date, s)) <= 1 and not Regex.match?(@except, s)
  end

  defp qualifiers(s, rules) do
    partial? = Enum.any?(rules, &(not Rule.full?(&1)))

    # (never the order power's own words: "different days may be appointed
    # … in relation to premises of different classes": 1963 c.41 s.91(2);
    # nor a place, "in relation to England": SI 2009/2096 art.2(2))
    text =
      s
      |> String.replace(@completing, "")
      |> String.replace(@place, "")
      |> String.replace(
        ~r/\b(?:different|a\s+later|an\s+earlier)\s+days?\s+may\s+be\s+appointed\b[^.;]*/i,
        ""
      )

    case Regex.run(@qualifier, text) do
      [words] when not partial? -> [%{kind: :qualifier, words: words}]
      _ -> []
    end
  end

  # a relative day the reader resolved: a relative rule, or a date the text
  # doesn't state (counted from the making or passing) — never where a
  # named day ("exit day") could give that date
  defp relative_days(s, rules) do
    stated =
      for [w] <- Regex.scan(@date, s),
          d = Clause.date_at_start(w),
          d != nil,
          into: MapSet.new(),
          do: d

    named_day? = s =~ ~r/\b(?:exit|IP\s+completion|implementation\s+period\s+completion)\s+day\b/i

    relative? =
      Enum.any?(rules, fn
        %Rule{when: {:after, _, _}} -> true
        %Rule{when: {:date, d}} -> not named_day? and not MapSet.member?(stated, d)
        _ -> false
      end)

    case Regex.run(@relative, s) do
      [words] when not relative? -> [%{kind: :relative_day, words: words}]
      _ -> []
    end
  end

  # ── a law's own clause ───────────────────────────────────────────────

  @open ~r/(?:into\s+(?:force|operation)|as\s+follows|following\s+dates?|except\s+that)\s*[—–:-]?\s*$/iu

  @doc """
  The statement a sentence of row `row_id` makes — with its list items when
  it opens a list ("… shall come into force —", "… except that—") — and the
  rules `read` (`OwnClause.read/2`) holds from it: from the row or an item
  under it, their words part of the statement (or it of theirs).
  """
  @spec statement(String.t(), String.t(), [map()], map()) :: {String.t(), [Rule.t()]}
  def statement(row_id, sentence, rows, %{rules: rules}) do
    items =
      if Regex.match?(@open, sentence),
        do: for(r <- rows, String.starts_with?(r.section_id, row_id <> "("), do: r.text || ""),
        else: []

    text = Enum.join([sentence | items], " ")
    base = row_id |> bare() |> provision()
    squashed = squash(text)

    # (an item's rule carries the sentence the reader made of it — "regulations
    # 4 and 14 come into force on …" — so an item row's rules are its own)
    item? = &(items != [] and String.starts_with?(&1, bare(row_id) <> "("))

    own =
      for %Rule{source: %{ref: ref, text: t}} = r <- rules,
          is_binary(ref) and is_binary(t),
          provision(ref) == base,
          item?.(ref) or String.contains?(squashed, squash(t)) or
            String.contains?(squash(t), squash(sentence)),
          do: r

    {text, own}
  end

  @doc "Each commencement sentence of a law's `rows` with its leftovers, given the law's reading."
  @spec for_law([map()], map(), [{String.t(), String.t()}]) :: [
          {String.t(), String.t(), [leftover()]}
        ]
  def for_law(rows, read, sentences) do
    for {row_id, sentence} <- sentences do
      {text, own} = statement(row_id, sentence, rows, read)
      refs = &Provisions.refs_in(&1, rows, provision(row_id))

      if own == [] and outside?(text, refs),
        do: {row_id, sentence, []},
        else: {row_id, sentence, of(text, own, refs)}
    end
  end

  # a statement naming provisions none of which the law's rows hold (a
  # scoped LAT: 2023 c.55 holds 408 rows, never s.58) reaches no row
  defp outside?(text, refs) do
    subject = text |> String.split(~r/\binto\s+(?:force|operation)\b/i, parts: 2) |> hd()
    Order.refs_in(subject) != [] and refs.(subject) == []
  end

  @type statement :: %{
          row: String.t(),
          sentence: String.t(),
          form: map(),
          outcome: map(),
          pattern: String.t(),
          leftovers: [leftover()]
        }

  @doc """
  Each commencement sentence of a law's `rows` as the catalogue classes it
  (`SentencePatterns`: form, outcome, pattern key) with its leftovers,
  given the law's reading — the one reading the catalogue and the family
  gate share. Another instrument's commencement has none (it names none
  of the law's own provisions).
  """
  @spec sentences([map()], map()) :: [statement()]
  def sentences(rows, read) do
    found = SentencePatterns.sentences(rows)

    for {{row_id, s}, {_, _, left}} <- Enum.zip(found, for_law(rows, read, found)) do
      f = SentencePatterns.form(s)
      o = SentencePatterns.outcome(s, read)

      %{
        row: row_id,
        sentence: s,
        form: f,
        outcome: o,
        pattern: SentencePatterns.key(f, o.class),
        # (a mention the catalogue classes so, as SI 2015/1947 reg.96(7))
        leftovers: if(f.subject == "instrument" or f.role == "mention", do: [], else: left)
      }
    end
  end

  @doc """
  Each statement of a commencement order (`OrderPatterns.units/1`) as the
  order catalogue classes it, with its leftovers given the order's `rules`.
  """
  @spec order_units(Doc.t(), [Rule.t()]) :: [map()]
  def order_units(doc, rules) do
    units = OrderPatterns.units(doc)

    for unit <- units, not repeats_paragraph?(unit, units) do
      f = OrderPatterns.form(unit)
      o = OrderPatterns.outcome(unit, rules)

      %{
        unit: unit,
        form: f,
        outcome: o,
        pattern: OrderPatterns.key(f, o.class),
        leftovers: if(own_lead?(doc, unit), do: [], else: order_leftovers(unit, rules))
      }
    end
  end

  # an article whose first line is its first paragraph's ("… 1st March
  # 2005. 2"): one statement, the paragraph's (SI 2005/442 art.2)
  defp repeats_paragraph?(%{id: id, text: text}, units) do
    Enum.any?(units, fn %{id: other, text: t} ->
      String.starts_with?(other, id <> "-") and t != "" and String.starts_with?(text, t)
    end)
  end

  # the tail of the order's own "This Order— (a) may be cited as …, and (b)
  # comes into force on …" (SI 2009/3345 art.1)
  defp own_lead?(doc, %{text: text, id: id}) do
    text =~ ~r/^\W*(?:shall\s+)?comes?\s+into\b/i and
      doc
      |> Doc.element(id)
      |> Doc.lines()
      |> Enum.any?(&(&1 =~ ~r/^\W*(?:\d+\s+)*(?:This|These)\s+(?:Order|Regulations)\s*[—–-]/))
  end

  # the order's own commencement and a table's header commence none of the
  # Act; a table row's provisions are its first cell (the next is a subject)
  defp order_leftovers(%{kind: kind}, _rules) when kind in ["own", "table_header"], do: []

  defp order_leftovers(unit, rules) do
    text = if unit.kind == "table", do: unit.text |> String.split(" | ") |> hd(), else: unit.text
    own = OrderPatterns.own_rules(unit, rules)

    cond do
      own_articles?(text) -> []
      # a statement bringing in its Schedule's table: the rows' rules use its words
      own == [] and text =~ ~r/\bSchedule\b|\bcolumn\b/ -> of(text, rules, &Order.refs_in/1)
      true -> of(text, own, &Order.refs_in/1)
    end
  end

  # the order's own articles ("This article and article 2 come into force …",
  # "The following provisions of this Order …", "Article 3 comes into force …")
  defp own_articles?(text),
    # its own paragraphs, its title ("Paragraphs (1) and (2) shall come
    # into force …": SI 2005/2714; "This paragraph, paragraph (3) …": SI
    # 2025/1370; "The title of these Regulations is …": WSI 2024/447)
    do:
      text =~ ~r/^\W*(?:This|These)\s+(?:articles?|Order|regulations?|Regulations)\b/ or
        text =~
          ~r/^\W*The\s+(?:remaining\s+|other\s+|following\s+)?provisions\s+of\s+this\s+(?:Order|instrument)\b/ or
        text =~ ~r/^\W*Articles?\s+\d[^.]*?\b(?:comes?|shall\s+come)\s+into\b/ or
        text =~
          ~r/^\W*(?:Paragraphs?\s+\(\d+[A-Z]?\)|This\s+paragraph\b|The\s+title\s+of\s+th(?:is|ese)\b)/

  # ── the review: a statement's status ────────────────────────────────

  @doc """
  A leftover's reviewed status (`leftovers.json`), nil when it has none: a
  statement named apart from its group (`"<shape> @ <row>"`: a laid-relative
  day, limit C, beside the group's real misses) first, else its group's.
  """
  @spec status(String.t(), map(), String.t() | nil) :: String.t() | nil
  def status(shape, reviewed, row \\ nil),
    do: Map.get(reviewed, "#{shape} @ #{row}") || Map.get(reviewed, shape)

  @doc "True for a status that names the leftover as a known limit (the family gate passes it)."
  @spec named?(String.t() | nil) :: boolean()
  def named?("known: " <> _), do: true
  def named?(_status), do: false

  # ── the family gate ─────────────────────────────────────────────────

  @type item :: %{
          source: :own | :order | :amending,
          law: String.t(),
          ref: String.t(),
          shape: String.t(),
          words: [String.t()],
          reach: integer(),
          status: String.t() | nil
        }

  @doc "A leftover reaching a family: where it is, its group's shape, its words, reach and status."
  @spec item(
          atom(),
          String.t(),
          String.t(),
          String.t(),
          [leftover()],
          integer(),
          String.t() | nil
        ) ::
          item()
  def item(source, law, ref, shape, leftovers, reach, status),
    do: %{
      source: source,
      law: law,
      ref: ref,
      shape: shape,
      words: Enum.map(leftovers, & &1.words),
      reach: reach,
      status: status
    }

  @doc """
  The family gate over its leftovers: `pass?` when every one is named
  (`known:`); the failing ones (`fix:`, `check:`, no status) widest reach
  first; counts by status.
  """
  @spec gate([item()]) :: %{pass?: boolean(), failing: [item()], counts: map()}
  def gate(items) do
    failing =
      items |> Enum.reject(&named?(&1.status)) |> Enum.sort_by(&{-&1.reach, &1.law, &1.ref})

    %{
      pass?: failing == [],
      failing: failing,
      counts: Enum.frequencies_by(items, &status_kind(&1.status))
    }
  end

  defp status_kind("known: " <> _), do: :known
  defp status_kind("fix: " <> _), do: :fix
  defp status_kind("check: " <> _), do: :check
  defp status_kind(_none), do: :unreviewed

  # ── groups, ranked by reach ─────────────────────────────────────────

  @type groups :: %{String.t() => %{count: integer(), laws: map(), examples: [map()]}}

  @doc "A group's shape: the statement's pattern and the kinds left over."
  @spec shape(String.t(), [leftover()]) :: String.t()
  def shape(pattern, leftovers),
    do:
      pattern <>
        " | left: " <>
        (leftovers
         |> Enum.map(&to_string(&1.kind))
         |> Enum.uniq()
         |> Enum.sort()
         |> Enum.join("+"))

  @doc """
  Adds one statement's leftovers to `groups` under its shape: the count,
  each law with its reach (its LAT rows, or the changes it makes on ours),
  up to 3 examples from different laws.
  """
  @spec add(groups(), String.t(), String.t(), String.t(), [leftover()], integer()) :: groups()
  def add(groups, _shape, _law, _row, [], _reach), do: groups

  def add(groups, shape, law, row, leftovers, reach) do
    g = Map.get(groups, shape, %{count: 0, laws: %{}, examples: []})
    example = %{"law" => law, "row" => row, "words" => Enum.map(leftovers, & &1.words)}

    examples =
      if length(g.examples) < 3 and law not in Enum.map(g.examples, & &1["law"]),
        do: g.examples ++ [example],
        else: g.examples

    Map.put(groups, shape, %{
      count: g.count + 1,
      laws: Map.put(g.laws, law, reach),
      examples: examples
    })
  end

  @doc "The groups by reach (the sum of their laws'), widest first: `{shape, reach, group}`."
  @spec ranked(groups()) :: [{String.t(), integer(), map()}]
  def ranked(groups) do
    groups
    |> Enum.map(fn {shape, g} -> {shape, g.laws |> Map.values() |> Enum.sum(), g} end)
    |> Enum.sort_by(fn {shape, reach, _} -> {-reach, shape} end)
  end

  @doc "The summary a catalogue prints: the groups, the widest `n` with their review status, those with none."
  @spec summary([{String.t(), integer(), map()}], map(), integer()) :: [String.t()]
  def summary(ranked, reviewed, n \\ 30) do
    statements = ranked |> Enum.map(&elem(&1, 2).count) |> Enum.sum()
    unreviewed = Enum.count(ranked, fn {shape, _, _} -> not Map.has_key?(reviewed, shape) end)

    [
      "\nleftovers by shape (words no rule uses): #{length(ranked)} groups, #{statements} statements"
    ] ++
      for(
        {shape, reach, g} <- Enum.take(ranked, n),
        do: "  #{reach} reach, #{g.count}: #{shape} [#{Map.get(reviewed, shape, "no status")}]"
      ) ++ ["leftover groups with no status: #{unreviewed}"]
  end

  @doc "The groups as their generated file: shape → reach, count, laws, examples."
  @spec to_json(groups()) :: map()
  def to_json(groups) do
    Map.new(ranked(groups), fn {shape, reach, g} ->
      {shape,
       %{
         "reach" => reach,
         "count" => g.count,
         "laws" => map_size(g.laws),
         "examples" => g.examples
       }}
    end)
  end

  @doc "The ranked groups as report lines."
  @spec lines([{String.t(), integer(), map()}]) :: [String.t()]
  def lines(ranked) do
    for {shape, reach, g} <- ranked,
        line <-
          ["#{reach} reach, #{g.count} statements, #{map_size(g.laws)} laws — #{shape}"] ++
            for(
              e <- g.examples,
              do: "    #{e["law"]} #{e["row"]}: #{Enum.join(e["words"], " · ")}"
            ),
        do: line
  end

  defp bare(sid), do: sid |> String.split(":", parts: 2) |> List.last()
  defp provision(ref), do: ref |> String.split("(", parts: 2) |> hd()
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()

  # the statement's clauses: commas, semicolons, dashes and "which" part
  # them, so another law's provision never hides the statement's own (the
  # extractor drops a clause naming another law)
  defp segments(s), do: String.split(s, ~r/[,;—–]|\bwhich\b/u, trim: true)

  # Schedules aren't parsed into rows (a v0.1 limit): never counted
  defp schedule?(ref), do: String.starts_with?(ref, ["sch", "annex"])

  # a ref is used by a scope or exception naming it or a provision holding it
  # — or its subsections the rules name ("Subsections (1) to (3) … of section
  # 190": SI 2009/2260, the rules s.190(1)…)
  defp covered?(ref, used),
    do:
      Enum.any?(
        used,
        &(ref == &1 or String.starts_with?(ref, [&1 <> "(", &1 <> "."]) or
            String.starts_with?(&1, ref <> "("))
      )
end
