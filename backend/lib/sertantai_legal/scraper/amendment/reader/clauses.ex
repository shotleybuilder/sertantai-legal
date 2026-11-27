defmodule SertantaiLegal.Scraper.Amendment.Reader.Clauses do
  @moduledoc """
  An amending instruction's clauses and operation (AR-03, AR-08;
  decomposed from `Amendment.Reader`, run time 2026-10-25): the clauses
  one per operation, the verb with captions aside, captions and quoted
  words stripped, where a clause is (its located brackets). Pure; calls
  `Reader.Brackets` only.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Operation, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader.Brackets

  # "the following paragraph", "a new subsection": the insertion is a provision
  @provision_named ~r/\b(?:following|new)\s+(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|provisions?|schedules?|parts?|chapters?)\b/i
  # "in subsection (1)", "In section 7(1)(a)": where the clause is
  # a bracketed group, brackets inside it at any depth ("(traceability of
  # … Regulations (Northern Ireland) 2013 (ITOER (NI) 2013))": SI 2019/696
  # Sch.31 para 9, Fire and OH&S 2026-11-15), quotes inside allowed
  @group ~S{(?<g>\((?:[^()“”"]|[“"][^”"]*[”"]|(?&g))*\))}
  @quote_or_group Regex.compile!("[“\"][^”\"]*[”\"]|" <> @group, "u")
  @place ~r/\bin\s+(?:sub-?)?(?:sections?|paragraphs?|sub-?paragraphs?|regulations?|articles?|rules?)\s+(?:\d+[A-Z]*\s*)?((?:\([0-9A-Za-z]+\))+)/i
  @aside Regex.compile!(
           "[“\"][^”\"]*[”\"]|" <> @group <> "(?!\\s*(?:Act|Regulations|Order|Rules|\\d{4})\\b)",
           "u"
         )

  @doc """
  The text without its captions, a title's own brackets kept ("Planning
  (Listed Buildings and Conservation Areas) Act 1990")
  """
  @spec asides(String.t()) :: String.t()
  def asides(s) do
    Regex.replace(@aside, s, fn m, _ ->
      if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: ""
    end)
  end

  @doc """
  The brackets of where the clause is ("in subsection (1)", "In section
  7(1)(a)" → ["1", "a"]).
  """
  @spec located_brackets(String.t()) :: [String.t()]
  def located_brackets(i) do
    i
    |> strip_captions()
    |> unquote_words()
    |> then(&Regex.scan(@place, &1, capture: :all_but_first))
    |> Enum.flat_map(&Brackets.plain_brackets(hd(&1)))
    |> Enum.filter(&Brackets.bracket?/1)
  end

  @doc """
  The instruction's clauses, one per operation: split at "and" or ";"
  outside quotes and captions, a piece with no verb joined to the next
  ("Sections 4 and 5 are repealed") or, last, to the one before
  """
  @spec clauses(Text.t()) :: [Text.t()]
  def clauses(%Text{instruction: i} = text) do
    masked = Regex.replace(@quote_or_group, i, fn m, _ -> String.duplicate("x", byte_size(m)) end)

    cuts =
      for [{pos, len}] <- Regex.scan(~r/;\s*|,?\s+and\s+/, masked, return: :index),
          not deleted_for?(masked, pos, len),
          do: pos + len

    pieces =
      [0 | cuts]
      |> Enum.zip(cuts ++ [byte_size(i)])
      |> Enum.map(fn {a, b} -> {binary_part(i, a, b - a), binary_part(masked, a, b - a)} end)

    pieces
    |> Enum.reduce([], fn {piece, m}, acc ->
      case acc do
        [{open, om, false} | rest] -> [{open <> piece, om <> m, verb?(om <> m)} | rest]
        _ -> [{piece, m, verb?(m)} | acc]
      end
    end)
    |> then(fn
      [{last, _, false}, {prev, pm, _} | rest] -> [{prev <> last, pm, true} | rest]
      acc -> acc
    end)
    |> Enum.reverse()
    |> Enum.map(fn {piece, _, _} -> %{text | instruction: String.trim(piece)} end)
    |> case do
      [_] -> [text]
      cs -> cs
    end
  end

  defp verb?(masked), do: Operation.of(%Text{id: nil, instruction: masked}) != nil

  # "delete “X” and substitute “Y”", "delete the full stop and substitute
  # …": one substitution, never cut (SSI 2000/432 reg.3(3); Waste, Water
  # and Climate 2026-11-26)
  defp deleted_for?(masked, pos, len) do
    binary_part(masked, 0, pos) =~
      ~r/\b(?:delete|omit)\s+(?:the\s+(?:words?\s+)?)?(?:x{2,}|full\s+stop|comma|semi-?colon|colon)\s*$/iu and
      binary_part(masked, pos + len, byte_size(masked) - pos - len) =~ ~r/^substitute\b/iu
  end

  @doc """
  Words the instruction doesn't spell out: an emptied quote ("“”": the
  quote held only markup — 1991 c.39 s.1(2)) or "each of the following is
  omitted—" with no kind of provision named (a list of words: 2004 c.5)
  """
  @spec words_unnamed?(String.t()) :: boolean()
  def words_unnamed?(i),
    do:
      i =~ ~r/[“"]\s*[”"]/u or
        (i =~ ~r/\bthe following (?:is|are|shall be) (?:omitted|repealed|revoked)\b/i and
           not (i =~ @provision_named))

  # "in paragraph (c)(ii) of that subsection—shall be omitted; (i) the
  # words “…”, and (ii) the word “…”": what is omitted is its list items,
  # all words (1995/25 Sch. 22 para 30(6)(b), run time 2026-10-26)
  # (so too "In section 17 (…)— (a) in subsection (1), the words …; …
  # shall cease to have effect": LGSA 1994 Sch.13 para 119(10), parked bug
  # container-verb-after-items, 2026-11-10)
  defp words_listed?(%Text{instruction: i, items: [_ | _] = items}),
    do:
      i =~
        ~r/[—–]\s*(?:(?:shall\s+be|are|is|be)\s+(?:omitted|repealed|revoked)\b|shall\s+cease\s+to\s+have\s+effect\b)/iu and
        Enum.all?(items, &(&1 =~ ~r/^\s*(?:in\s+[^,;]+,\s*)?the\s+words?\b/i))

  defp words_listed?(_text), do: false

  # words quoted as inline amendments leave an empty slot in the
  # instruction's own words ("omit <quote>," → "omit ,"; "after <quote>
  # insert <quote>." → "after insert ."): the quote is words, unless a
  # provision named is what goes ("omit sub-paragraph (d) and the <quote>
  # preceding it") (SSI 2026/55, SSI 2025/165, NISR 2025/126;
  # Environmental Protection, Decision 2)
  @quote_slot ~r/\b(?:omit|after|before|for)\s*(?:[,;.]|$|(?=(?:insert|substitute)\b))/iu
  @provision_object ~r/\b(?:omit|repeal|revoke|for)\s+(?:the\s+)?(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|heads?)\s*\d*[A-Z]*\(/iu
  # (never "for paragraph 1, substitute “1. …”": an EU paragraph whole,
  # SI 2019/649 reg.6(9)(b))
  @provision_for ~r/\bfor\s+(?:the\s+)?(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|points?)\s*(?:\d|\()/iu
  @bare_substitute ~r/(?:^|[—–:,]\s*)substitute\s*[.;,]?(?:\s+and)?\s*$/iu

  # (the words named in a parent, "in subsection (3), for “local
  # authority”— where they occur in the proviso, substitute “…”", or lost
  # from the text, "In section 89 (…)— substitute “Health Authority”": 1994
  # c.39 Sch.13 para.75(12)(b)(ii), 1995 c.17 Sch.1 para.120(3); Waste,
  # Water and Climate 2026-11-26)
  defp inline_words?(%Text{quoted: q, inserted: [], instruction: i} = text) when q != "",
    do:
      (i =~ @quote_slot or parent_words?(text) or
         (i =~ @bare_substitute and not (i =~ @provision_for))) and
        not (i =~ @provision_object)

  defp inline_words?(_text), do: false

  defp parent_words?(%Text{parents: [p | _]}), do: p =~ ~r/\bfor\s+[“"][^”"]*[”"]\s*[—–:]\s*$/u
  defp parent_words?(_text), do: false

  @doc """
  The instruction's operation, its captions aside; an insertion quoting no
  provision "at the end" / "at the appropriate place" — and naming no kind
  of provision as inserted — puts words into the provision named (2014 c.6
  s.128(2)(e): a definition into s.235(1))
  """
  @spec operation(Text.t()) :: {String.t(), String.t()} | nil
  def operation(text) do
    case Operation.of(captionless(text)) do
      {verb, verb} = op when verb != "inserted" ->
        if words_unnamed?(text.instruction) or words_listed?(text) or inline_words?(text),
          do: {verb, "words #{verb}"},
          else: op

      {"inserted", "inserted"} = op ->
        if words_inserted?(text), do: {"inserted", "words inserted"}, else: op

      op ->
        op
    end
  end

  # an insertion quoting no provision at a place in the provision named
  # ("in the appropriate place insert— <definition>": WSI 2013/755,
  # Environmental Protection, Decision 2) or of inline-quoted words
  defp words_inserted?(%Text{inserted: [], instruction: i} = text),
    do:
      (i =~ ~r/\b(?:at|in) the (?:end|beginning|appropriate places?)\b/i or inline_words?(text)) and
        not (i =~ @provision_named)

  defp words_inserted?(_text), do: false

  @doc """
  An item whose verb is its parent's noun ("Section 5 … shall be amended by
  the insertion— … (b) after subsection (4), of the following
  subsections—": EPA 1990 Sch. 15 para. 14, CV-06 S7) with the verb before
  its words ("insert after subsection (4), …"); any other text as it is.
  """
  @parent_noun ~r/\bby\s+the\s+(insertion|substitution|omission)\b[^—–]*[—–]\s*$/iu
  @noun_verb %{"insertion" => "insert", "substitution" => "substitute", "omission" => "omit"}

  @spec with_parent_verb(Text.t()) :: Text.t()
  def with_parent_verb(%Text{parents: [parent | _], instruction: i} = text) do
    with nil <- Operation.of(captionless(text)),
         [_, noun] <- Regex.run(@parent_noun, parent) do
      %{text | instruction: @noun_verb[String.downcase(noun)] <> " " <> i}
    else
      nil -> listed_verb(text, parent)
      _ -> text
    end
  end

  def with_parent_verb(text), do: text

  # an item with no verb of its own under "The following provisions are
  # repealed—" is repealed (2011 c.20 s.47(b): "sections 71(2) and (3) and
  # 72 to 75 of that Act (which provide for … or repealed)", whose only
  # verb sat in its caption; Fire and OH&S 2026-11-15) — only an item
  # starting with its own numbered provisions ("the remaining provisions
  # of Part 5 of that Act" names none: 2011 c.20 s.109(1)(b))
  @parent_verb ~r/\bthe\s+following\s+(?:provisions?|enactments?|sections?|regulations?)\s+((?:is|are|shall\s+be)\s+(?:hereby\s+)?(?:repealed|revoked|omitted))\s*[—–:]\s*$/iu
  # (every verb-less item, caption or none: "section 10 (schemes initiated
  # by the Scottish Ministers)," had been kept to an item whose caption held
  # a verb — asp 2015/13 s.1(2)(a); Waste, Water and Climate 2026-11-26)
  defp listed_verb(%Text{instruction: i} = text, parent),
    do: %{text | instruction: parent_verb(parent, i) || i}

  @numbered ~r/^\s*(?:sections?|regulations?|articles?|rules?)\s+\d/iu
  defp parent_verb(parent, i) do
    case i =~ @numbered && Regex.run(@parent_verb, parent, capture: :all_but_first) do
      [verb] -> Regex.replace(~r/[\s,;.]*(?:\band\s*)?$/u, i, "", global: false) <> " " <> verb
      _ -> nil
    end
  end

  @doc """
  The instruction without its bracketed captions ("In section 118 (… of
  revoked or suspended licences), after subsection (4) insert—": the verb
  is "insert", not the caption's "revoked" — SI 1998/1420; "(“the 1984
  Act”)" names a term, not words changed); quoted words keep their
  brackets
  """
  @spec captionless(Text.t()) :: Text.t()
  def captionless(%Text{instruction: i} = text),
    do: %{text | instruction: strip_captions(i)}

  @doc """
  A bracketed caption: a parenthetical with a space, quotes inside
  allowed, never starting inside a quote
  """
  @spec strip_captions(String.t()) :: String.t()
  def strip_captions(s) do
    Regex.replace(@quote_or_group, s, fn m, _ ->
      if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: ""
    end)
  end

  @schedule_entry ~r/,?\s*(?:and\s+)?the\s+entr(?:y|ies)\s+in\s+Schedule\s+[0-9A-Z]+\s+relating\s+to\s+.*?(?=\s+(?:are|is|shall|be)\b|[;:]|$)/u

  @doc """
  The text without an entry in the amended law's Schedule repealed beside
  its sections ("sections 7, 8(2) and the entry in Schedule 2 relating to
  section 124(2) of the 1961 Act are hereby repealed": SI 1974/1941
  reg.5(1)): a Schedule's (not parsed, v0.1), and the section it names is
  another law's — neither a target nor words in one
  """
  @spec no_schedule_entries(String.t()) :: String.t()
  def no_schedule_entries(s), do: Regex.replace(@schedule_entry, s, "")

  # ", as it has effect before section 5(8) of the Housing and Planning
  # Act 2016 (c. 22) comes …," — an aside naming another law and its
  # provisions, never the law or the place amended (asc 2023/3 Sch.13 para
  # 72 on TCPA 1990 s.70(3); Amending-law reader: parked bugs, 2026-11-10).
  # Up to the aside's closing comma: its words are the commencement
  # readers' to read. So is a condition on another law's provisions being
  # in force (", if paragraphs 4 and 5 of Schedule 11 to LURA 2023 are in
  # force,": asc 2026/7 Sch.1 on TCPA 1990, 26 in one law; amending
  # Schedules, 2026-11-27)
  # (opening the sentence: "If paragraphs 3 to 6 of Schedule 11 to LURA
  # 2023 are in force, omit sections 94 to 96": asc 2026/7 Sch.1 para.61)
  @opening_condition ~r/^\s*if\s+[^,;—–]*?\b(?:is|are)\s+(?:not\s+)?in\s+force,\s*/iu
  @effect_aside ~r/,\s*(?:as\s+(?:it\s+|they\s+)?(?:has|have|had)\s+effect\s+(?:before|after|until|apart\s+from)\b[^,;]*|if\s+[^,;—–]*?\b(?:is|are)\s+(?:not\s+)?in\s+force),/iu

  @entry_ref "\\d+[A-Z]*(?:\\s*\\([0-9A-Za-z]+\\))*"
  @entry_named Regex.compile!(
                 "\\b(the\\s+entr(?:y|ies)\\s+)(?:relating\\s+to|for)\\s+(?:sections?|regulations?|articles?|rules?|paragraphs?)\\s+" <>
                   @entry_ref <>
                   "(?:\\s*(?:,|and|or|to)\\s*(?:" <> @entry_ref <> "|\\([0-9A-Za-z]+\\)))*",
                 "iu"
               )

  @doc """
  The text with a table's entry named by the provision it lists left as
  "the entry" ("In section 160A, after the entry relating to section
  45AA(10) insert—": s.160A's table, never s.45AA(10), asp 2024/13 s.15(3);
  "in the second column of the entry for section 34CA, in paragraph (e)
  omit": 2023 c.28 Sch.3 para 1(a); Environmental Protection F5, 2026-11-10)
  """
  @spec no_entry_names(String.t()) :: String.t()
  def no_entry_names(s), do: Regex.replace(@entry_named, s, "\\1")

  # a clause saying where a term's meaning is found ("… and in this
  # paragraph the expression “railway company” has the meaning assigned to
  # it in section 108 of that Act": SI 1996/2089 reg.34(1), read as a repeal
  # of s.108; Fire and OH&S 2026-11-15): the provision it names is no place
  @meaning_aside ~r/\b((?:has|have|having|bears?|bearing)\s+the\s+(?:same\s+)?meanings?)\s+(?:as\s+)?(?:(?:assigned|given)\s+(?:to\s+(?:it|them)\s+)?)?(?:in|by)\s+(?:sub-?)?(?:sections?|regulations?|articles?|rules?|paragraphs?)\s+\d+[A-Z]*(?:\s*\([0-9A-Za-z]+\))*(?:\s+of\s+(?:that|the\s+said|the\s+[A-Z][^.;,()]*?\d{4}))?(?:\s+(?:Act|Order|Regulations|Rules)\b)?/u

  # an entry told by what it is about ("after the entry relating to a fire
  # and rescue authority constituted by a scheme under section 2 of the
  # Fire and Rescue Services Act 2004 or a scheme to which section 4 of
  # that Act applies insert—": 2017 c.3 Sch.1 para 85, read as words in
  # ss.2, 4): its description, up to the verb, names neither law nor place.
  # An entry named by a provision's number is `no_entry_names/1`'s
  @entry_described ~r/\b(the\s+entr(?:y|ies))\s+(?:relating\s+to|for)\s+(?!(?:sections?|regulations?|articles?|rules?|paragraphs?)\s+\d)[^,;—–]*?(?=\s*(?:[,;—–]|\b(?:insert|substitute|omit|add|there)\b|\band\s+(?:at|in|after|before|for)\b|$))/iu

  @doc """
  The text without its asides that tell neither the law nor the place
  amended: when a provision has effect (`@effect_aside`), where a term's
  meaning is found (`@meaning_aside`), what an entry is about
  (`@entry_described`).
  """
  @spec no_effect_asides(String.t()) :: String.t()
  def no_effect_asides(s) do
    s = no_made_text(s)
    s = Regex.replace(@effect_aside, s, ",")
    s = Regex.replace(@opening_condition, s, "")
    s = Regex.replace(@meaning_aside, s, "\\1")
    Regex.replace(@entry_described, s, "\\1")
  end

  # text an amendment made, named as such: "in the inserted section 87 of
  # the Water Industry Act 1991 (…)", "in the substituted Article 54",
  # "in the text of section 144(1A)(b) … as inserted by that
  # sub-paragraph" (or "… as applied to LLPs") — an earlier amending provision's words (or a
  # Schedule's), never a place of the law it names nor its operation
  # (2014 c.21 Sch.7 para.134 had made WIA s.87(2)(b) inserted; SI
  # 2022/1173 art.14(4) placed Sch.5's "Article 34a" on art.34; Waste,
  # Water and Climate 2026-11-26)
  # an aside's words: balanced brackets ("regulations 5(2) to 5(4)") but
  # never a lone ")" — the aside then sits in a caption, which the captions
  # rule reads ("(inserted by paragraph 17(6)) add—" had lost its verb:
  # 2010 c.29 Sch.4 para.23(3), 2002 c.40 s.267(2); Waste, Water and
  # Climate 2026-11-26)
  @aside_refs "(?:[^,;—–()]|\\([^()]*\\))*?"
  @made_stop "(?=\\s*[,;—–)]|\\s+(?:for|omit|after|before|insert|substitute|there|is|are)\\b|$)"
  @made_text [
    Regex.compile!(
      "\\b(?:in\\s+)?the\\s+text\\s+of\\s+" <>
        @aside_refs <>
        "\\bas\\s+(?:it\\s+has\\s+effect\\s+as\\s+)?(?:(?:inserted|substituted)\\s+by|applied\\s+to)\\b" <>
        @aside_refs <>
        "" <>
        @made_stop,
      "iu"
    ),
    Regex.compile!(
      "\\b(?:in\\s+)?the\\s+(?:inserted|substituted)\\s+(?:Articles?|sections?|sub-?sections?|regulations?|(?:sub-?)?paragraphs?|rules?)" <>
        "(?:\\s+\\d+[A-Za-z]*)?(?:\\s*\\([0-9A-Za-z]+\\))*(?:\\s*(?:,|and|or|to)\\s*\\d*[A-Za-z]*(?:\\([0-9A-Za-z]+\\))+)*" <>
        "(?:\\s+of\\s+" <> @aside_refs <> @made_stop <> ")?",
      "iu"
    ),
    # "section 479 of the 2006 Act as applied to LLPs": the applied text an
    # instrument holds, never the Act amended (SI 2012/2301 reg.20 on SI
    # 2008/1911; Waste, Water and Climate 2026-11-27)
    Regex.compile!(
      "\\b(?:in\\s+|for\\s+|after\\s+)?sections?\\s+\\d" <>
        @aside_refs <>
        "\\bas\\s+applied\\s+to\\b" <>
        @aside_refs <>
        @made_stop,
      "iu"
    ),
    # "in the words inserted into section 213(1) of the … Act" (2014 c.21
    # Sch.7 para.145); "as substituted by subsection (4)", "inserted by
    # regulation 6(2)": the amending law's own provisions (1997 c.11 Sch.2
    # para.27(a), SI 2008/1482 reg.8); "as respectively inserted and
    # substituted by Part II of Schedule 4 to the 1988 Act" (1994 c.28
    # s.5(2)(a))
    Regex.compile!(
      "\\b(?:in\\s+)?the\\s+words\\s+(?:inserted|substituted)\\s+(?:into|in)\\b" <>
        @aside_refs <>
        "" <>
        @made_stop,
      "iu"
    ),
    Regex.compile!(
      "\\b(?:as\\s+(?:respectively\\s+)?)?(?:(?:substituted|inserted|amended)\\s+(?:and|or)\\s+)?(?:substituted|inserted|amended)\\s+by\\s+(?:sub-?sections?|sections?|(?:sub-?)?paragraphs?|regulations?|articles?|rules?|Parts?\\s+\\w+\\s+of\\s+Schedule|Schedule)\\s+" <>
        @aside_refs <>
        "" <>
        @made_stop,
      "iu"
    ),
    # "Subject to paragraph (2), regulation 3(1) … revoked": the amending
    # law's own paragraph (SSI 2002/276 reg.7(1))
    ~r/^\s*Subject\s+to\s+(?:sub-?sections?|sections?|(?:sub-?)?paragraphs?|regulations?|articles?)\s+[^,]*,\s*/iu
  ]

  @doc """
  The text without the text an amendment made, named as such ("in the
  inserted section 87 of the … Act", "in the substituted Article 54").
  """
  @spec no_made_text(String.t()) :: String.t()
  @quoted_words ~r/“[^”]*”|"[^"]*"/u
  @quoted_words_whole ~r/^(?:“[^”]*”|"[^"]*")$/u

  # (outside quoted words only: "omit “as amended by subsection (1)
  # above”" had lost its words — 1994 c.19 Sch.15 para.40(b))
  def no_made_text(s) do
    @quoted_words
    |> Regex.split(s, include_captures: true)
    |> Enum.map_join(fn piece ->
      if piece =~ @quoted_words_whole,
        do: piece,
        else: Enum.reduce(@made_text, piece, &Regex.replace(&1, &2, ""))
    end)
  end

  @doc """
  The text without its captions, brackets inside them too ("… 1990
  (provisions to which subsections (1) to (4) are subject)—": no place;
  1995/25 Sch. 10 para 32(1)); a bracket with no space is kept ("(5)",
  "(Scotland)").
  """
  @spec no_captions(String.t()) :: String.t()
  def no_captions(s) do
    Regex.replace(~r/(?<g>\((?:[^()]|(?&g))*\))/u, s, fn m, _ ->
      if m =~ ~r/\s/u, do: "", else: m
    end)
  end

  # a provision reference, then its caption: "section 1 (application of …)",
  # "regulation 2(1) (interpretation)", "paragraph 14 of Schedule 7A (…)",
  # "paragraph 15(b) and (f) (in the quoted text modifying section 155 of
  # the Data Protection Act 2018)" (SI 2026/386 Sch. 3 para 6(4)(j)(iv): a
  # sibling's aside had named the law for para 6(5), CV-S05)
  # … the provision's law between them ("section 26 of the Fire Services
  # Act 1947 (firefighters' pension scheme) (as continued in force by order
  # under section 36 of the Fire and Rescue Services Act 2004)", 2017 c.3
  # s.8(5); "section 410(3) of the Communications Act 2003 (c. 21) (which
  # enables Orders in Council under section 11 of the Petroleum Act 1998
  # …)", 2004 c.20 s.87(5)): every caption after it, brackets inside a
  # caption at any depth (Fire and OH&S 2026-11-15)
  @provision_ref ~S"\b(?:sections?|subsections?|regulations?|articles?|rules?|paragraphs?|sub-paragraphs?|Schedules?|Parts?|Chapters?)\s+[0-9]+[A-Z]*(?:\s*\([0-9A-Za-z]+\))*(?:\s*(?:,|and|or|to)\s*\([0-9A-Za-z]+\)(?:\s*\([0-9A-Za-z]+\))*)*"
  @of_law ~S'(?:\s+(?:of|to)\s+the\s+(?:[^()“”";—–]|\([A-Z][^()]*\))*?\s\d{4})?'
  @captioned Regex.compile!(
               "(" <> @provision_ref <> @of_law <> ")(?:\\s*" <> @group <> ")+",
               "u"
             )

  @doc """
  The text without the captions that follow a provision reference ("In
  section 1 (application of Part I of Health and Safety at Work etc. Act
  1974 …)": a caption describes the provision, never names the law amended
  — Petroleum Act 1998 Sch. 4 para 33). Titles keep every bracket of their
  own ("The Environmental Protection (Disposal of …) (England and Wales)
  Regulations 2000"), unlike `asides/1`.
  """
  @spec uncaptioned(String.t()) :: String.t()
  def uncaptioned(s), do: Regex.replace(@captioned, s, "\\1")

  @doc """
  The text without its quoted words — nested quotes too, innermost first
  ("omit ““x” means the Building (Approved Inspectors etc.) Regulations
  2010”": SI 2024/1268, whose definition's title had named a law), and
  words up to a closing quote left with no opener or after an opening
  quote left with no closer.
  """
  @spec unquote_words(String.t()) :: String.t()
  def unquote_words(t),
    do:
      t
      |> unnest()
      |> String.replace(~r/[“"][^”"]*[”"]/u, "")
      # a closing quote left with no opener ends quoted words that run back
      # to the instruction's dash ("insert—“” means Commission Implementing
      # Regulation (EU) 2017/1354 …;”": a term lost in the flattening; SI
      # 2019/696 Sch. 29 para 2, whose inserted words had named EU laws)
      |> String.replace(~r/([—–])[^“”—–]*”/u, "\\1")
      # and an opening quote left with no closer, quoted words to the end
      # ("for substitute “Schedule 2 to the Supply of Machinery (Safety)
      # Regulations 2008/1597; and": SI 2019/696 Sch. 22, which had named
      # the Machinery Regulations for the Lifts Regulations' paragraphs)
      |> String.replace(~r/“[^”]*$/u, "")

  defp unnest(t) do
    case String.replace(t, ~r/“[^“”]*”(?=[^“]*”)/u, "") do
      ^t -> t
      fewer -> unnest(fewer)
    end
  end

  @doc """
  A text set in capitals, each word capitalised ("MODIFICATIONS—THE FACTORIES
  ACT 1961" → "Modifications—The Factories Act 1961"), so a title in it reads
  as one; any other text as it is.
  """
  @spec uncapped(String.t()) :: String.t()
  def uncapped(t) do
    if t =~ ~r/\p{Lu}{2}/u and not (t =~ ~r/\p{Ll}/u),
      do: Regex.replace(~r/\p{L}+/u, t, &String.capitalize/1),
      else: t
  end
end
