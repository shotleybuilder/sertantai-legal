defmodule SertantaiLegal.Scraper.LawStart.Clause do
  @moduledoc """
  Reads a law's own commencement clause (lat-refactor LR-33 P1, P2, P4,
  P5; `LawStart`'s clause treatments): the first sentence in document order
  where the whole instrument ("this Order", "these Regulations", "This Act")
  comes into force or operation, including "… may be cited as … and come
  into force …" and asides ("shall, except as provided by paragraphs (3)
  and (4) below, come into force …").

  The clause's tail decides the treatment:

  | Tail | Treatment |
  |---|---|
  | "on 17th April 1995" | `:clause_date` |
  | "on the day after the day on which it is made"; "on the twenty-first day after …"; "six months after the date on which they are made"; "on the expiration of two months from the day …" (+1 day); "at the end of the period of three months beginning with the day on which it is passed"; "on the first day of the month following that in which it is made" | `:clause_made_relative` |
  | "on IP completion day" (also "immediately before / after"): 2020-12-31; "on exit day": 2020-01-31, or IP completion day for an instrument made before exit day (EU(WA)A 2020 Sch. 5 para. 1(1), CR-09) | `:clause_named_day` |
  | "on the principal appointed day" (also "immediately before") in an instrument made between the Scotland Act 1998's passing and that day: 1999-07-01 (SI 1998/3178 art.3) | `:clause_named_day` |
  | "in accordance with paragraphs (2) and (3)", "as follows", a list: the earliest date its provision's other sentences state | `:clause_staged` |
  | no clause for the whole law, only for its parts ("This Article and Article 2 …", "The remaining provisions of this Order …"): the earliest date that provision states | `:clause_staged` |
  | "on such day as … may by order appoint" | `:by_order` |
  | "at the same time as section 83 of the 2022 Act comes into force" | `:tied_to_other_law` |
  | the same counts from the day the law is laid: "on the 22nd day after the day on which these Regulations are laid"; "at the end of a period of 21 days beginning with the day after the day on which these Regulations are laid" (the day after is the period's first) | `:clause_laid_relative` |
  | anything else, or a made- (laid-) relative tail without a made (laid) day | `:clause_unread` |

  Counting periods (Interpretation Act conventions): a period "from" or
  "after" a day excludes that day, so "the expiration of N months from the
  day on which it is made" is the day after made + N months; a period
  "beginning with" the day includes it, so its end is made + N. Pure.
  """
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{OwnDays, PurposeStages, Sentences}
  alias SertantaiLegal.Scraper.LawStart.Clause.{Staged, Tail, WrittenDates}

  @named_then_rest Staged.named_then_rest()
  @unknown Tail.unknown()

  @instrument ~S"(?:Order(?: in Council)?|Regulations?|Rules|Act|Measure|Scheme|Instrument|Byelaws?|Directions)"

  # an aside between commas: ", subject to paragraphs (2) and (3),"
  # … or a list between commas: ", except section 120 above, this section and
  # section 122 below," (PACE 1984 s.121(1), CV-S04)
  # … or an except list below: "This Act, except— (a) …, shall come into
  # force on the appointed day …" (Gas Act 1995 s.18(2), CV-S04 round 3)
  @aside ~S"(?:\s*,(?:[^,]{0,160},){1,4}|\s*,\s*(?:except|apart\s+from|other\s+than)\s*(?:—|–)(?:\s*…)?)?\s*"

  # "shall come", "comes", "is to come" (LGRA 1997 s.34(1)); "shall not /
  # does not come into force until …" (Electronic Communications Act 2000
  # s.17(3): until such date as … by order) — CV-S04
  @cif ~S"(?:shall" <>
         @aside <>
         ~S"|(?:is|are)\s+to\s+)?(?:(?:shall|does|do)\s+not\s+)?(?:comes?|came)\s+into\s+(?:force|operation)"

  # "Subject to paragraphs (3), (4) and (5) these Regulations …" (commas in
  # a list of paragraphs: V1-02)
  # … or a long one naming its exceptions with their own dates ("Except as
  # provided in subsection (2) above and except for this section, section 74
  # above and paragraphs … (which come into force on the passing of this
  # Act) and the repeal of …, this Act shall come into force …": EA 1995
  # s.125(3), CV-S04)
  @prefix ~S"^(?:\(?\d+[A-Z]?\)?\s+)?(?:(?:Subject to|Subject as follows|Except as (?:otherwise )?(?:expressly )?(?:provided(?: for)?|specified|stated|mentioned)|Except in so far as|Except for|Save as (?:otherwise )?provided|Apart from|Other than)(?:[^,]|,(?=\s*(?:\(|and\b|or\b))){0,200}?(?:,\s*|\s+(?=(?:this|these|the)\s))|(?:Except as (?:otherwise )?(?:provided(?: for)?|specified|mentioned)|Except in so far as|Apart from|Other than).{0,700}?(?:,|\))\s*(?=(?:this|these|the)\s))?"

  @general [
    Regex.compile!(
      # "the provisions of this Act" (Health and Social Care Act 2008
      # s.170(3)), never with an except list after it (the rest, so read
      # by `Provisions`: asp 2003/8 s.60)
      @prefix <>
        ~S"(?:this|these|the)\s+(?:provisions\s+of\s+(?:this|these)\s+(?=\w+\b(?!\s*,?\s*(?:except|other\s+than)\b|\s*\(\s*(?:apart\s+from|except|other\s+than)\b)))?" <>
        @instrument <> ~S"\b(?:\s*\((?:[^()]|\([^()]*\))*\))?" <> @aside <> @cif <> ~S"\s*(.*)$",
      "is"
    ),
    Regex.compile!(
      # ("… Regulations 2010 and they come into force on 10th January 2011":
      # SI 2010/2984)
      # "… and subject to paragraphs (2) and (3) shall come into force on
      # 1st January 2000" (Quarries Regulations 1999 reg.1(1), CV-S04)
      # (", which extend to Great Britain," between: SI 1996/1513)
      # (a comma for the "and": "… Regulations 1996, shall come into force on
      # 2nd May 1996 and shall extend to Scotland only": SI 1996/1076)
      # ("may cited as": SI 1991/259; "may he cited as": SI 1991/346; "These Regulations which may be cited
      # as … 2007 shall come into force on …": SI 2007/765; "… and except
      # as provided in paragraphs (2), (3) and (4) shall come into operation
      # on …": NISR 2011/127 — Fire and OH&S)
      ~S"\b(?:this|these)\s+" <>
        @instrument <>
        ~S"(?:\s*,[^,]{0,80},)?\s+(?:which\s+may\s+be\s+cited\s+as\b.{0,300}?\d{4}(?=\s+shall\b)|may\s+(?:[bh]e\s+)?cited\s+as\b.{0,300}?(?:\band(?:\s+(?:they|it))?|,))(?:\s+(?:subject\s+to|except\s+as\s+(?:otherwise\s+)?provided\s+(?:in|by))\s+(?:[^,]|,(?=\s*(?:\(|and\b|or\b))){1,160}?(?=\s+shall\b))?" <>
        @aside <> @cif <> ~S"\s*(.*)$",
      "is"
    ),
    # "These Regulations apply in relation to Wales and come into force on
    # 1 October 2011" (WSI 2010/2880); "These Regulations may be cited as …
    # which shall come into force on 1st April 1988" (SI 1988/370): CV-S04
    Regex.compile!(
      ~S"\b(?:this|these)\s+" <>
        @instrument <>
        ~S"\s+(?:apply|applies|extend|extends)\b.{0,200}?\band" <> @aside <> @cif <> ~S"\s*(.*)$",
      "is"
    ),
    Regex.compile!(
      ~S"\b(?:this|these)\s+" <>
        @instrument <> ~S"\s+may be cited as\b.{0,300}?\bwhich\s+" <> @cif <> ~S"\s*(.*)$",
      "is"
    ),
    # "The title of this Order is … and it comes into force on 30 April
    # 2012" (Welsh instruments: SI 2012/801, WSI 2026/18; CV-S04); "…
    # Regulations 2017; they apply in relation to Wales and come into force
    # on 20 November 2017" (WSI 2017/1041, WSI 2011/1014)
    Regex.compile!(
      ~S"\bThe\s+title\s+of\s+(?:this|these)\s+" <>
        @instrument <>
        ~S"\s+is\b.{0,300}?(?:\band|;)\s+(?:it|they)\s+(?:(?:apply|applies|extend|extends)\b.{0,200}?\band\s+)?" <>
        @cif <> ~S"\s*(.*)$",
      "is"
    )
  ]

  # a part of this law commencing ("This Article and Article 2 shall come
  # into operation …", "The remaining provisions of this Order …", "The
  # remainder comes into force …", "The following come into force …—",
  # "Otherwise, these Regulations come into force …": the rest, V1-02)
  @own_part Regex.compile!(
              ~S"^(?:\(?\d+[A-Z]?\)?\s+)?(?:this\s+(?:article|regulation|section|rule|paragraph|Part|Schedule)\b|(?:the\s+)?(?:remaining provisions|remainder)(?:\s+of\s+(?:this|these)\b)?|the\s+following\b(?!\s+(?:provisions\s+)?of\s+(?:the|that)\b)|otherwise\b|.{0,200}\bof\s+(?:this|these)\s+" <>
                @instrument <> ~S"\b).{0,300}?\binto\s+(?:force|operation)\b",
              "is"
            )

  # a section commencing itself alone; "This section and sections 62, 63
  # and 65 come into force on the day after Royal Assent" is an Act's first
  # stage (asp 2024/14); so is one going on to the rest ("… but otherwise
  # this Act comes into force on such date as may be appointed by order":
  # ukpga 1992/34 s.8)
  @this_section ~r/^(?:\(?\d+[A-Z]?\)?\s+)?this\s+section\s+(?:shall\s+|is\s+to\s+)?(?:comes?|come)\s+into\s+(?:force|operation)\b(?![^.;]*\b(?:otherwise|remaining|remainder|rest|other\s+provisions)\b)/i

  @doc """
  The law's start from its commencement clause; nil when it has none. `act?`:
  the law is an Act, where a section commencing itself ("This section shall
  come into force on 1st April 1982") is that section's own words, leaving
  the rest to Royal Assent — never the Act's start (Finance Act 1981
  s.137(4), CV-S05).
  """
  @spec read([map()], OwnDays.days(), boolean()) :: LawStart.t() | nil
  def read(rows, made, act? \\ false) do
    case general(rows) do
      nil -> own_parts(rows, made, act?)
      {row, sentence, tail} -> decide(rows, row, sentence, tail, made)
    end
  end

  # no clause for the whole law, but its parts commence: the earliest date
  # the first such provision states (`:clause_staged`); unread when it
  # states none. A mention isn't one ("… taken before this section comes
  # into force": SOCPA 2005 s.101(2) hid its s.178, CV-S05)
  defp own_parts(rows, made, act?) do
    Enum.find_value(rows, fn row ->
      case row
           |> Map.get(:text)
           |> sentences()
           |> Enum.find(
             &(own_part?(&1) and not mention?(&1) and
                 not (act? and Regex.match?(@this_section, &1)))
           ) do
        nil ->
          nil

        s ->
          Staged.staged(
            rows,
            row,
            %LawStart{treatment: :clause_unread, evidence: row.section_id, text: s},
            made
          )
      end
    end)
  end

  # "comes into force on the later of— (a) 1st January 2024; or (b) the day
  # which is 21 days after the day on which this Order is made" (SI
  # 2023/1394 reg.1): each lettered item read as a tail, the later (or the
  # earlier) taken, with its item's treatment; nil unless every item dates
  @either_of ~r/^on the (later|earlier) of\b/i

  defp either_of(rows, row, tail, made) do
    with [_, which] <- Regex.run(@either_of, tail),
         [_ | _] = items <- items_of(rows, row),
         [_ | _] = dated <- Enum.map(items, &item_date(&1, made)),
         true <- Enum.all?(dated, &match?({_, %Date{}}, &1)) do
      pick = if String.downcase(which) == "later", do: &Enum.max_by/3, else: &Enum.min_by/3
      pick.(dated, &elem(&1, 1), Date)
    else
      _ -> nil
    end
  end

  # the provision's lettered items: "reg.1(a)", "reg.1(b)"
  defp items_of(rows, row) do
    item = ~r/^#{Regex.escape(row.section_id)}\([a-z]+\)$/
    Enum.filter(rows, &Regex.match?(item, &1.section_id))
  end

  defp item_date(%{text: text}, made) when is_binary(text) do
    item = text |> String.trim() |> String.replace(~r/\s*(?:;\s*(?:or|and)?|\.)\s*$/i, "")

    case Tail.tail_date("on " <> item, made) do
      {treatment, %Date{} = d} -> {treatment, d}
      _ -> nil
    end
  end

  defp item_date(_row, _made), do: nil

  defp own_part?(sentence),
    do: Regex.match?(@own_part, sentence) or Regex.match?(@named_then_rest, sentence)

  defp decide(rows, row, sentence, tail, made) do
    found = %LawStart{treatment: :clause_unread, evidence: row.section_id, text: sentence}

    case Tail.tail_date(tail, made) do
      {treatment, %Date{} = d} ->
        %{found | treatment: treatment, date: d}

      unknown when unknown in @unknown ->
        found

      nil ->
        no_tail_date(rows, row, tail, made, found)
    end
  end

  # a tail stating no date of its own: a choice between its items, its
  # first stage, an order, another provision's day, its stages, or unread
  defp no_tail_date(rows, row, tail, made, found) do
    cond do
      pick = either_of(rows, row, tail, made) ->
        %{found | treatment: elem(pick, 0), date: elem(pick, 1)}

      d = first_stage(tail, made) ->
        %{found | treatment: :clause_staged, date: d}

      Staged.by_order?(tail) ->
        %{found | treatment: :by_order}

      Staged.tied?(tail) ->
        %{found | treatment: :tied_to_other_law}

      Staged.staged?(tail) ->
        Staged.staged(rows, row, found, made)

      true ->
        found
    end
  end

  # the first day of a law staged by purpose in one statement: "…, for the
  # purpose of regulation 10(2), on 20th March 1991 and for all other
  # purposes on 1st September 1991" (SI 1991/346 reg.1(1))
  defp first_stage(tail, made) do
    case PurposeStages.read(tail, made) do
      [{:partial, _purpose, d}, {:full, nil, full}] -> Enum.min([d, full], Date)
      nil -> nil
    end
  end

  @doc "Whether a sentence only mentions a commencement (`Sentences.mention?/1`)."
  @spec mention?(String.t()) :: boolean()
  defdelegate mention?(sentence), to: Sentences

  @doc "Whether a sentence states a commencement (`Sentences.commences?/1`)."
  @spec commences?(String.t()) :: boolean()
  defdelegate commences?(sentence), to: Sentences

  @doc "Whether a sentence is a clause commencing the whole instrument."
  @spec general?(String.t()) :: boolean()
  def general?(sentence), do: Enum.any?(@general, &Regex.match?(&1, sentence))

  # the first sentence in document order where the whole instrument comes
  # into force: {row, sentence, tail}; else a list whose parent names the
  # instrument ("These Regulations— … (b) come into force on …"); else "they"
  # or "it" in the citation provision ("Subject to paragraph (3), they come
  # into force on …": V1-02)
  defp general(rows), do: stated(rows) || listed(rows) || pronoun(rows)

  @parent ~r/^(?:\(?\d+[A-Z]?\)?\s+)?(?:this|these)\s+#{@instrument}\s*[—–:-]\s*$/iu

  @item_cif ~r/^(?:\(?[a-z0-9]+\)\s*)?(?:may\s+be\s+cited\s+as\b.{0,300}?\band\s+)?(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\s*(.*?)\s*(?:;\s*(?:and|or)?)?\s*$/i

  @pronoun Regex.compile!(@prefix <> ~S"(?:they|it)" <> @aside <> @cif <> ~S"\s*(.*)$", "is")

  defp listed(rows) do
    Enum.find_value(rows, fn row ->
      if Regex.match?(@parent, Map.get(row, :text) || ""),
        do: Enum.find_value(rows, &listed_item(&1, row))
    end)
  end

  # an item of the list the parent opens, commencing the instrument
  defp listed_item(item, row) do
    with true <- item.section_id != row.section_id,
         true <- String.starts_with?(item.section_id, row.section_id <> "("),
         # (a no-break space is a space: "(b) come into force on
         # 24th\u00A0December 2010", SSI 2010/426 reg.1)
         text = String.replace(Map.get(item, :text) || "", ~r/\s+/u, " "),
         [_, tail] <- Regex.run(@item_cif, text) do
      {item, String.trim(text), String.trim(tail)}
    else
      _ -> nil
    end
  end

  @citation_line ~r/\bmay be cited as\b|\bThe\s+title\s+of\s+(?:this|these)\s+#{@instrument}\s+is\b/i

  defp pronoun(rows) do
    # (or titled: "The title of these Regulations is …. They come into force
    # on 6 May 2009": WSI 2009/995)
    cited =
      for r <- rows,
          (Map.get(r, :text) || "") =~
            @citation_line,
          into: MapSet.new(),
          do: Staged.provision(r.section_id)

    Enum.find_value(rows, fn row ->
      if MapSet.member?(cited, Staged.provision(row.section_id)),
        do: first_match(row, [@pronoun])
    end)
  end

  defp stated(rows), do: Enum.find_value(rows, &first_match(&1, @general))

  # the row's first sentence one of `patterns` matches: {row, sentence, tail}
  defp first_match(row, patterns) do
    row
    |> Map.get(:text)
    |> sentences()
    |> Enum.find_value(fn s -> Enum.find_value(patterns, &tail_of(&1, row, s)) end)
  end

  defp tail_of(re, row, s) do
    case Regex.run(re, s) do
      [_, tail] -> {row, s, String.trim(tail)}
      nil -> nil
    end
  end

  @doc "A provision's text as sentences (`Sentences.sentences/1`)."
  @spec sentences(String.t() | nil) :: [String.t()]
  defdelegate sentences(text), to: Sentences

  @doc """
  A tail's date and its treatment: `{treatment, date}`; `:made_unknown`
  (`:laid_unknown`) when it counts from a made (laid) day we don't have;
  nil when it states none. `days`: the law's made and laid days
  (`OwnDays`), or its made day alone.
  """
  @spec tail_date(String.t(), OwnDays.days()) ::
          {LawStart.treatment(), Date.t()} | :made_unknown | :laid_unknown | nil
  defdelegate tail_date(tail, days), to: Tail

  @doc """
  A date at the start of text: "17th April 1995", "30 th August 2013",
  "1 October 2020"; in words, as older Acts write it: "the first day of
  April, nineteen hundred and sixty-two" (Factories Act 1961 s.185(2)).
  """
  @spec date_at_start(String.t()) :: Date.t() | nil
  defdelegate date_at_start(text), to: WrittenDates

  @doc """
  A tail leaving the commencement to an order ("on such day as … may by
  order appoint"; "in accordance with provision so made by the National
  Assembly for Wales": CNEA 2005 s.108(1)(b); "in accordance with orders
  made by the Treasury": Tax Credits Act 2002 s.61), or to a day the Act
  names that an order fixes ("on the transfer date": 1986 c.44 s.68(3));
  "on whatever day the Scottish Ministers appoint by order" (2014 c.12
  s.185(6)); "in accordance with regulations made by the Secretary of
  State" (Employment Rights Act 2025 s.159(3)).
  """
  @spec by_order?(String.t()) :: boolean()
  defdelegate by_order?(tail), to: Staged

  @doc "A tail tying the commencement to another provision's (\"at the same time as section 1 comes into force\")."
  @spec tied?(String.t()) :: boolean()
  defdelegate tied?(tail), to: Staged

  @doc """
  The other law's provision a tied clause waits for (V1-02): `{title with
  year, ref}` — "immediately after section 162 of the Health and Care Act
  2022 comes into force" → {"Health and Care Act 2022", "s.162"}; a defined
  term ("the 2022 Act") through its definition in `rows`. nil when unread.
  """
  @spec tied_ref(String.t() | nil, [map()]) :: {String.t(), String.t()} | nil
  defdelegate tied_ref(sentence, rows), to: Staged

  @doc """
  A staged clause's list item as `{subject, tail, date}` (V1-02): the
  provisions it names and the date it gives them — "Parts 1, 2 … on 16th
  April 2005", "the remainder, on 16th July 2005", "as regards Parts 1 and 4,
  immediately before 31st December 2023", "regulation 4 at 12:01 a.m. on 1
  July 2026", "Part 4, on IP completion day"; the subject is "" when the
  item opens with its date. nil when no date is found.
  """
  @spec item_split(String.t() | nil, OwnDays.days()) :: {String.t(), String.t(), Date.t()} | nil
  defdelegate item_split(text, made), to: Staged

  @doc """
  Why a list item `item_split/2` finds no date in is unread:
  `:laid_day_not_held` (`:made_day_not_held`) when its day counts from the
  day the law is laid (made) and that day is not held ("for the purposes of
  regulations 1, 2 and 3 on the 22nd day after the day on which these
  Regulations are laid": SI 2018/1221 reg.2(a)); `:day_unread` otherwise.
  """
  @spec item_unread_reason(String.t() | nil, OwnDays.days()) ::
          :laid_day_not_held | :made_day_not_held | :day_unread
  defdelegate item_unread_reason(text, days), to: Staged
end
