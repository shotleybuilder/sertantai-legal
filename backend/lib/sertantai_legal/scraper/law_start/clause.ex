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
  alias SertantaiLegal.Scraper.LawStart.{MadeCondition, OwnDays, PurposeStages}

  # a tail counting from a day of the law's own that is not held
  @unknown [:made_unknown, :laid_unknown]

  @ip_completion_day ~D[2020-12-31]
  @exit_day ~D[2020-01-31]

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

  @months ~w(january february march april may june july august september october november december)

  @numbers %{
    "one" => 1,
    "two" => 2,
    "three" => 3,
    "four" => 4,
    "five" => 5,
    "six" => 6,
    "seven" => 7,
    "eight" => 8,
    "nine" => 9,
    "ten" => 10,
    "eleven" => 11,
    "twelve" => 12,
    "thirteen" => 13,
    "fourteen" => 14,
    "fifteen" => 15,
    "sixteen" => 16,
    "seventeen" => 17,
    "eighteen" => 18,
    "nineteen" => 19,
    "twenty" => 20,
    "thirty" => 30,
    "first" => 1,
    "second" => 2,
    "third" => 3,
    "fourth" => 4,
    "fifth" => 5,
    "sixth" => 6,
    "seventh" => 7,
    "eighth" => 8,
    "ninth" => 9,
    "tenth" => 10,
    "eleventh" => 11,
    "twelfth" => 12,
    "thirteenth" => 13,
    "fourteenth" => 14,
    "fifteenth" => 15,
    "sixteenth" => 16,
    "seventeenth" => 17,
    "eighteenth" => 18,
    "nineteenth" => 19,
    "twentieth" => 20,
    "thirtieth" => 30,
    "forty" => 40,
    "fortieth" => 40,
    "fifty" => 50,
    "fiftieth" => 50,
    "sixty" => 60,
    "sixtieth" => 60,
    "seventy" => 70,
    "eighty" => 80,
    "ninety" => 90
  }

  @made ~S"(?:(?:(?:the\s+)?(?:day|date)\s+(?:(?:on\s+which|of)\s+)?)?(?:it\s+is|they\s+are|they\s+were|(?:(?:this|these)\s+[A-Za-z ]+?|the\s+(?:Order|Regulations|Rules|Act|Scheme|Measure|Instrument))\s+(?:is|are|was|were))\s+(?:made|passed|approved\s+by\s+Her\s+Majesty\s+in\s+Council)|(?:the\s+)?(?:making|passing)\s+(?:of\s+(?:this|these)\s+[A-Za-z ]+|thereof)|its\s+(?:making|passing)|(?:the\s+day\s+(?:on\s+which\s+)?)?(?:(?:this\s+Act|it)\s+receives\s+)?Royal\s+Assent|receiving\s+Royal\s+Assent|the\s+(?:day|date)\s+of\s+Royal\s+Assent|the\s+Bill\s+for\s+this\s+Act\s+receives\s+Royal\s+Assent|that\s+on\s+which\s+(?:it|this\s+Act)\s+is\s+passed|the\s+(?:day|date)\s+of\s+(?:the\s+)?(?:passing|making)\s+(?:thereof|of\s+(?:this|these)\s+[A-Za-z ]+)|the\s+(?:day|date)\s+of\s+(?:this|these)\s+(?:Order|Regulations|Rules|Scheme)\b(?!\s+(?:is|are|was|were)\b))"

  # (the last: "on the date of this Order", the day it is made and sealed:
  # NISR 2007/282 art.2(1))

  # the day the law is laid: "the day on which these Regulations are laid",
  # "… they are laid before Parliament" (the House, the Senedd: whatever
  # follows is where, not when)
  @laid ~S"(?:(?:the\s+)?(?:day|date)\s+(?:on\s+which\s+)?)?(?:it\s+is|they\s+are|they\s+were|it\s+was|(?:(?:this|these)\s+[A-Za-z ]+?|the\s+(?:Order|Regulations|Rules|Scheme|Instrument))\s+(?:is|are|was|were))\s+laid\b"
  @number ~S"(\d+(?:st|nd|rd|th)?|[a-z]+(?:[- ][a-z]+)?)"

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
          staged(
            rows,
            row,
            %LawStart{treatment: :clause_unread, evidence: row.section_id, text: s},
            made
          )
      end
    end)
  end

  # a named provision's day going on to the rest is a part commencing too
  # ("Regulation 9 comes into force on 1st January 2015 and all other
  # regulations come into force on 6th April 2010": SI 2010/740 reg.1(2))
  # (its day a date, or tied to another provision's: "Regulation 15 shall
  # come into force on the date on which section 7(3) of the Water Act 2003
  # comes into force, and all other provisions … on 1st April 2006": SI
  # 2006/641 reg.1(2))
  @named_then_rest ~r/^(?:\(?\d+[A-Z]?\)?\s+)?(?:regulations?|articles?|sections?|rules?)\s+\d[^.;]{0,300}?\binto\s+(?:force|operation)\s+on\s+(?:[^.;]{0,60}?\d{4}|the\s+(?:day|date)\s+on\s+which\b[^.;]{0,200}?\binto\s+(?:force|operation))\s*,?\s+and\s+(?:all\s+|the\s+)?(?:other|remaining)\s+(?:provisions|regulations|articles|sections|rules)\b[^.;]{0,200}?\binto\s+(?:force|operation)\b/i

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

    case tail_date("on " <> item, made) do
      {treatment, %Date{} = d} -> {treatment, d}
      _ -> nil
    end
  end

  defp item_date(_row, _made), do: nil

  defp own_part?(sentence),
    do: Regex.match?(@own_part, sentence) or Regex.match?(@named_then_rest, sentence)

  defp decide(rows, row, sentence, tail, made) do
    found = %LawStart{treatment: :clause_unread, evidence: row.section_id, text: sentence}

    case tail_date(tail, made) do
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

      by_order?(tail) ->
        %{found | treatment: :by_order}

      tied?(tail) ->
        %{found | treatment: :tied_to_other_law}

      staged?(tail) ->
        staged(rows, row, found, made)

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

  # the first "comes into force" in a sentence, and what is before it (its
  # head) — a mention shows there: "before this section …", "the date on
  # which this section …", "the coming into force", "deemed to have …",
  # "If …", "… means …", "…, which came into force on …"; never a later
  # clause of a statement ("They come into force on the day after the day on
  # which they are made, save for regulation 10 which comes into force on 1st
  # October 2009": SI 2009/1581, CV-S04); a period named by it is a mention
  # too ("the quarter period within which these Regulations come into
  # force": SI 2025/910 reg.28(5)(b)(i))
  @first_cif ~r/\b(comes?|came|coming|be\s+brought|brought)\s+(?:fully\s+)?into\s+(?:force|operation)\b/i
  @mention_head ~r/\b(?:before|after|until|unless|when|whenever|once|since|if|by\s+the\s+time|on\s+or\s+after|immediately\s+before|(?:with)?in\s+which|(?:day|date|time)\s+(?:on|upon|at)\s+which|deemed\s+to\s+have|thereby|means)\b|\bthe\s*$|^\W*(?:\[[^\]]*:\s*)?(?:\(\w+\)\s*)?(?:where|when|if|until|unless|once)\b/i

  @doc """
  Whether a sentence only mentions a commencement ("before this section
  comes into force", "the date on which …", "the coming into force of",
  "which came into force on …") rather than stating one — read in its head,
  before its first "comes into force" (CV-S04).
  """
  @spec mention?(String.t()) :: boolean()
  def mention?(sentence) do
    case Regex.run(@first_cif, sentence, return: :index) do
      [{at, _}, {v, vlen}] ->
        head = binary_part(sentence, 0, at)
        verb = binary_part(sentence, v, vlen) |> String.downcase()

        Regex.match?(@mention_head, head) or
          verb == "coming" or
          head =~ ~r/\b(?:day|date|time)\s+(?:this|these|that|the|it|they)\b[^,;]{0,80}$/i or
          (verb == "came" and head =~ ~r/\bwhich\s*$/i) or
          (verb == "brought" and sentence =~ ~r/\bbrought\s+into\s+(?:force|operation)\s+by\b/i)

      _ ->
        false
    end
  end

  @doc """
  Whether a sentence states a commencement ("The following provisions come
  into force …"), not only mentions one (`mention?/1`): for other readers to
  leave it to the commencement ruleset (the extent reader's statements, CV-S05
  round 13).
  """
  @spec commences?(String.t()) :: boolean()
  def commences?(sentence), do: Regex.match?(@first_cif, sentence) and not mention?(sentence)

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
      if Regex.match?(@parent, Map.get(row, :text) || "") do
        Enum.find_value(rows, fn item ->
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
        end)
      end
    end)
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
          do: provision(r.section_id)

    Enum.find_value(rows, fn row ->
      if MapSet.member?(cited, provision(row.section_id)) do
        row
        |> Map.get(:text)
        |> sentences()
        |> Enum.find_value(fn s ->
          case Regex.run(@pronoun, s) do
            [_, tail] -> {row, s, String.trim(tail)}
            nil -> nil
          end
        end)
      end
    end)
  end

  defp stated(rows) do
    Enum.find_value(rows, fn row ->
      row
      |> Map.get(:text)
      |> sentences()
      |> Enum.find_value(fn s ->
        Enum.find_value(@general, fn re ->
          case Regex.run(re, s) do
            [_, tail] -> {row, s, String.trim(tail)}
            nil -> nil
          end
        end)
      end)
    end)
  end

  @doc """
  A provision's text as sentences: a full stop then a capital or "(" — but
  not after an abbreviation ("Metrology etc. (Amendment etc.) (EU Exit)
  Regulations 2019 and come into force …": LR-43, SI 2019/696).
  """
  @spec sentences(String.t() | nil) :: [String.t()]
  def sentences(nil), do: []

  def sentences(text),
    do:
      text
      # (a no-break space is a space: "on 1st\u00A0January 2015", SI 2010/740
      # reg.1(2))
      |> String.replace(~r/\s+/u, " ")
      # a qualification set off by commas after "into force" is no staging:
      # "shall come into force, subject to the transitory provisions in …,
      # at the end of the period of six months …" (Road Traffic Act 1988 s.197(2))
      |> String.replace(~r/\binto (force|operation), subject to [^,]{1,250}, /i, "into \\1 ")
      |> String.split(
        ~r/(?<=\.)(?<!\betc\.)(?<!\bNo\.)(?<!\bNos\.)(?<!\bSch\.)(?<!\bart\.)(?<!\breg\.)(?<!\bs\.)(?<!\bc\.)(?<!\bi\.e\.)(?<!\be\.g\.)\s+(?=[A-Z(])/
      )

  # "X or, if later, Y": the later day, read as its own form reads; a day
  # not read leaves the whole unread, never the other day alone (SI
  # 2018/797 reg.1(2)(b): the 21st day after making or, if later, 1st
  # October 2018)
  @if_later ~r/\s+or,?\s+if\s+later,?\s+(?:on\s+)?(?:the\s+(?=\d))?/i

  @doc """
  A tail's date and its treatment: `{treatment, date}`; `:made_unknown`
  (`:laid_unknown`) when it counts from a made (laid) day we don't have;
  nil when it states none. `days`: the law's made and laid days
  (`OwnDays`), or its made day alone.
  """
  @spec tail_date(String.t(), OwnDays.days()) ::
          {LawStart.treatment(), Date.t()} | :made_unknown | :laid_unknown | nil
  def tail_date(tail, days) do
    case Regex.split(@if_later, tail, parts: 2) do
      [first, second] -> later(one_date(first, days), one_date(second, days))
      [_one] -> one_date(tail, days)
    end
  end

  defp later({_, %Date{} = a} = first, {_, %Date{} = b} = second),
    do: if(Date.compare(b, a) == :gt, do: second, else: first)

  defp later(unknown, _second) when unknown in @unknown, do: unknown
  defp later(_first, unknown) when unknown in @unknown, do: unknown
  defp later(_first, _second), do: nil

  defp one_date(tail, days) do
    made = OwnDays.made(days)

    cond do
      d = named_day(tail, made) ->
        {:clause_named_day, d}

      d = date_at_start(String.replace(tail, ~r/^(?:at [^,]{1,30}? )?(?:on|from|until)\s+/i, "")) ->
        {:clause_date, d}

      d = by_territory(tail) ->
        {:clause_staged, d}

      d = end_of_day(tail) ->
        {:clause_date, d}

      true ->
        made_relative(tail, made) || laid_relative(tail, OwnDays.laid(days))
    end
  end

  # "at the end of 31st December 2024" (SI 2024/1366 art.2(2)(a)): in force
  # from the next day
  defp end_of_day(tail) do
    with [_, rest] <- Regex.run(~r/^at\s+the\s+end\s+of\s+(?:the\s+)?(\d.*)$/is, tail),
         %Date{} = d <- date_at_start(rest) do
      Date.add(d, 1)
    else
      _ -> nil
    end
  end

  # "in England on 1st July 2007 and in Wales on 2nd April 2007": the earliest
  defp by_territory(tail) do
    if tail =~ ~r/^in (?:England|Wales|Scotland|Northern Ireland|Great Britain)\b/i do
      ~r/\bon\s+(\d{1,2}\s*(?:st|nd|rd|th)?\s*[A-Za-z]+,?\s+\d{4})/
      |> Regex.scan(tail, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&date_at_start/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.min(Date, fn -> nil end)
    end
  end

  # "on the day before that on which exit day falls" (SI 2019/544
  # reg.1(2)): the named day less one
  @day_before ~r/^(?:on\s+)?the\s+day\s+before\s+(?:that\s+on\s+which\s+|the\s+day\s+on\s+which\s+)?((?:IP|implementation period) completion day|exit day)(?:\s+falls)?\b/i

  defp named_day(tail, made) do
    case Regex.run(@day_before, tail) do
      [_, day] -> day |> named_day(made) |> Date.add(-1)
      nil -> named_day_on(tail, made)
    end
  end

  defp named_day_on(tail, made) do
    case Regex.run(
           ~r/^(?:on\s+|at\s+|immediately\s+(?:before|after)\s+)?(IP completion day|implementation period completion day|exit day)\b/i,
           tail
         ) do
      [_, day] ->
        if day =~ ~r/^(?:IP|implementation)/i, do: @ip_completion_day, else: exit_day(tail, made)

      nil ->
        principal_appointed_day(tail, made)
    end
  end

  # "on [immediately before] the principal appointed day" in an instrument
  # made under the Scotland Act 1998 before that day: 1st July 1999, the
  # day SI 1998/3178 art.3 names (SI 1999/1750, SI 1999/1756). Another
  # Act's principal appointed day (Wales Act 2017 s.71) is made outside
  # that span and is not read; nor one with no made date.
  @scotland_act_passed ~D[1998-11-19]
  @principal_appointed_day ~D[1999-07-01]

  defp principal_appointed_day(tail, %Date{} = made) do
    named? =
      tail =~
        ~r/^(?:on\s+|immediately\s+(?:before|after)\s+)?the\s+principal\s+appointed\s+day\b/i

    if named? and Date.compare(made, @scotland_act_passed) != :lt and
         Date.compare(made, @principal_appointed_day) != :gt,
       do: @principal_appointed_day
  end

  defp principal_appointed_day(_tail, _made), do: nil

  # EU(WA)A 2020 Sch. 5 para. 1(1) (CR-09, Jason 2026-10-19): subordinate
  # legislation made before exit day that comes into force by reference to
  # exit day is read as coming into force by reference to IP completion day —
  # unless it expressly disapplies that (para. 1(2)); regulations varying it
  # (para. 1(3)) aren't read (a known limit). Made date unknown: as written.
  defp exit_day(tail, %Date{} = made) do
    disapplied? = tail =~ ~r/Schedule 5 to the European Union \(Withdrawal Agreement\) Act 2020/i

    if Date.compare(made, @exit_day) == :lt and not disapplied?,
      do: @ip_completion_day,
      else: @exit_day
  end

  defp exit_day(_tail, _made), do: @exit_day

  @doc """
  A date at the start of text: "17th April 1995", "30 th August 2013",
  "1 October 2020"; in words, as older Acts write it: "the first day of
  April, nineteen hundred and sixty-two" (Factories Act 1961 s.185(2)).
  """
  @spec date_at_start(String.t()) :: Date.t() | nil
  def date_at_start(text) do
    # (the year run on to the month, "6th July2017": SI 2017/720 art.1(2);
    # a date the revised text brackets, "on [1st December 1999]": SI
    # 1999/2463 reg.1)
    re =
      ~r/^(?:the\s+)?\[?\s*(\d{1,2})\s*(?:st|nd|rd|th)?\s*(?:day\s+of\s+)?([A-Za-z]+),?\s*(\d{4})\b/

    with [_, d, m, y] <- Regex.run(re, String.trim(text)),
         month when is_integer(month) <- Enum.find_index(@months, &(&1 == String.downcase(m))),
         {:ok, date} <- Date.new(String.to_integer(y), month + 1, String.to_integer(d)) do
      date
    else
      _ -> date_in_words(String.trim(text))
    end
  end

  @in_words ~r/^(?:the\s+)?([a-z]+(?:[- ][a-z]+)?)\s+day\s+of\s+([A-Za-z]+),?\s+(?:in\s+the\s+year\s+)?([a-z][a-z -]*)/i

  defp date_in_words(text) do
    with [_, d, m, y] <- Regex.run(@in_words, text),
         month when is_integer(month) <- Enum.find_index(@months, &(&1 == String.downcase(m))),
         day when is_integer(day) <- words_number(d),
         year when is_integer(year) and year > 1000 <- year_in_words(y),
         {:ok, date} <- Date.new(year, month + 1, day) do
      date
    else
      _ -> nil
    end
  end

  # "first", "twenty-first", "thirty first"
  defp words_number(words) do
    parts = words |> String.downcase() |> String.split(~r/[- ]/, trim: true)
    values = Enum.map(parts, &Map.get(@numbers, &1))
    if parts != [] and Enum.all?(values, & &1), do: Enum.sum(values)
  end

  # "nineteen hundred and sixty-two", "two thousand and one": the leading
  # number words, then the rest of the sentence ignored
  defp year_in_words(words) do
    words
    |> String.downcase()
    |> String.split(~r/[- ]+/, trim: true)
    |> Enum.take_while(&(Map.has_key?(@numbers, &1) or &1 in ~w(hundred thousand and)))
    |> Enum.reject(&(&1 == "and"))
    |> Enum.reduce({0, 0}, fn
      "thousand", {total, n} -> {total + n * 1000, 0}
      "hundred", {total, n} -> {total + n * 100, 0}
      w, {total, n} -> {total, n + Map.fetch!(@numbers, w)}
    end)
    |> then(fn {total, n} -> total + n end)
  end

  defp made_relative(tail, made) do
    case relative_shift(tail, @made) do
      nil -> nil
      _shift when is_nil(made) -> :made_unknown
      shift -> {:clause_made_relative, shift.(made)}
    end
  end

  # the same counts from the day the law is laid ("on the 22nd day after
  # the day on which these Regulations are laid": SI 2018/1221 reg.2(a))
  defp laid_relative(tail, laid) do
    case relative_shift(tail, @laid) do
      nil -> nil
      _shift when is_nil(laid) -> :laid_unknown
      shift -> {:clause_laid_relative, shift.(laid)}
    end
  end

  # the tail's count from the law's own day `from` words (the made day's,
  # the laid day's), as a function of that day; nil when the tail doesn't
  # count from it
  defp relative_shift(tail, from) do
    t = String.replace(tail, ~r/\s+/, " ")
    near_shift(t, from) || counted_shift(t, from)
  end

  # the day itself, or the day after it
  defp near_shift(t, from) do
    cond do
      Regex.match?(
        ~r/^on (?:the (?:day|date) (?:(?:on which|of) )?|Royal Assent|the (?:passing|making) of)/i,
        t
      ) and
          starts_from?(t, ~r/^on /i, from) ->
        & &1

      # "when they are made" (SI 2022/500, CV-S04)
      Regex.match?(~r/^when\s+(?:they\s+are|it\s+is|this\s+\w+\s+is)\s+(?:made|passed)\b/i, t) ->
        & &1

      Regex.match?(~r/^(?:on )?the day (?:after|following) /i, t) and
          starts_from?(t, ~r/^(?:on )?the day (?:after|following) /i, from) ->
        &Date.add(&1, 1)

      true ->
        nil
    end
  end

  # a count of days, weeks or months from the day
  @nth_day_after ~r/^(?:on )?the #{@number} day (?:after|following) (.*)$/i

  @first_of_month_after ~r/^(?:on )?the first day of the (?:#{@number} )?(?:calendar )?month (?:following|after) (?:that|the month) in which (.*)$/i

  @end_of_period ~r/^(?:on |at |with )?(?:the )?(?:expiration|expiry|end) of (?:a |the )?(?:period of )?#{@number} (days?|weeks?|months?|years?) (from|after|beginning with|beginning on|starting with) (.*)$/i

  # ("six months after …"; "the day which is 21 days after …": SI 2023/1394)
  @n_after ~r/^(?:on )?(?:the (?:day|date) (?:which|that) is )?#{@number} (days?|weeks?|months?) after (.*)$/i

  defp counted_shift(t, from) do
    cond do
      m = Regex.run(@nth_day_after, t) ->
        [_, n, rest] = m
        with_from(rest, from, n, fn day, k -> Date.add(day, k) end)

      m =
          Regex.run(
            @first_of_month_after,
            t
          ) ->
        first_of_month(m, from)

      m =
          Regex.run(
            @end_of_period,
            t
          ) ->
        [_, n, unit, rel, rest] = m
        extra = if String.downcase(rel) in ["from", "after"], do: 1, else: 0
        with_from(rest, from, n, fn day, k -> day |> shift(unit, k) |> Date.add(extra) end)

      m = Regex.run(@n_after, t) ->
        [_, n, unit, rest] = m
        with_from(rest, from, n, fn day, k -> shift(day, unit, k) end)

      true ->
        nil
    end
  end

  defp starts_from?(t, lead, from),
    do:
      Regex.match?(
        ~r/^#{from}/i,
        t
        |> String.replace(lead, "")
        |> String.replace(~r/^the day (?:on which|of) /i, "the day on which ")
      )

  # a period "beginning with the day after the day on which these
  # Regulations are laid" (SI 2025/287 reg.1(2)) counts from the next day
  defp with_from(rest, from, n, fun) do
    {rest, next} =
      case Regex.run(~r/^the day (?:after|following) (.*)$/i, rest) do
        [_, after_] -> {after_, 1}
        nil -> {rest, 0}
      end

    with true <- Regex.match?(~r/^#{from}/i, rest),
         k when is_integer(k) <- number(n) do
      &fun.(Date.add(&1, next), k)
    else
      _ -> nil
    end
  end

  defp first_of_month([_, n, rest], from) do
    k = if n in [nil, ""], do: 1, else: number(n)

    if is_integer(k) and Regex.match?(~r/^#{from}/i, rest),
      do: fn day -> day |> Date.beginning_of_month() |> Date.shift(month: k) end
  end

  defp first_of_month([_, rest], from), do: first_of_month([nil, "", rest], from)

  defp shift(date, unit, k) do
    case String.downcase(unit) do
      "day" <> _ -> Date.add(date, k)
      "week" <> _ -> Date.add(date, 7 * k)
      "month" <> _ -> Date.shift(date, month: k)
      "year" <> _ -> Date.shift(date, year: k)
    end
  end

  defp number(n) do
    n = String.downcase(n)

    case Integer.parse(n) do
      # (a numeric ordinal: "the 22nd day after …", SI 2022/1342)
      {i, suffix} when suffix in ["", "st", "nd", "rd", "th"] ->
        i

      _ ->
        case String.split(n, ~r/[- ]/) do
          [a, b] ->
            with x when is_integer(x) <- @numbers[a],
                 y when is_integer(y) <- @numbers[b],
                 do: x + y

          [a] ->
            @numbers[a]
        end
    end
  end

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
  def by_order?(tail),
    do:
      tail =~
        ~r/\bsuch (?:day|date|time)s?\b|\bday appointed\b|\bappointed (?:day|by)\b|\bmay,? by (?:order|regulations)\b|\bmay appoint\b|\bappoints\b|\bappoint by (?:order|regulations)\b|\bprovision (?:to be )?made by (?:\w+ ){0,6}(?:by )?order\b|\bspecified by order\b|\bprovision so made\b|\bon the (?:transfer|vesting) (?:date|day)\b|\bin accordance with (?:an? )?(?:orders?|regulations) (?:to be )?made\b/i

  @doc "A tail tying the commencement to another provision's (\"at the same time as section 1 comes into force\")."
  @spec tied?(String.t()) :: boolean()
  def tied?(tail),
    do:
      tail =~
        ~r/\bat the same time as\b|^immediately (?:after|before)\b.*\binto (?:force|operation)|^on the (?:same )?(?:day|date) (?:on which|that)\b.*\binto (?:force|operation)/i

  defp staged?(tail),
    do:
      tail == "" or
        tail =~
          ~r/^(?:[—:;,–-]|as follows|on the following dates?|in accordance with|in stages|subject to)/i

  # what follows a sentence's "into force": once — but a named provision's
  # day going on to the rest states two ("Regulation 9 comes into force on
  # 1st January 2015 and all other regulations come into force on 6th April
  # 2010": SI 2010/740 reg.1(2))
  defp tails(s) do
    case String.split(s, ~r/\binto\s+(?:force|operation)\s+/i) do
      [_only] ->
        []

      [_head | tails] ->
        if Regex.match?(@named_then_rest, s), do: tails, else: [Enum.join(tails, "into force ")]
    end
  end

  # the earliest date the clause's own provision states elsewhere
  # ("(2) … on 1st June 2015", "(3) … on IP completion day")
  defp staged(rows, row, found, made) do
    base = provision(row.section_id)

    # (a head whose condition on the making day fails states nothing: SI
    # 2024/1366 art.2(3))
    in_provision =
      rows |> Enum.filter(&(provision(&1.section_id) == base)) |> MadeCondition.holding(made)

    stated =
      for r <- in_provision,
          s <- sentences(Map.get(r, :text)),
          tail <- tails(s),
          {_, %Date{} = d} <- [tail_date(String.trim(tail), made)],
          do: d

    # list items under the clause: "(a) on 1st October 2006, for …", "Parts
    # 1, 2 … on 16th April 2005", "the remainder, on 16th July 2005" (V1-02)
    listed =
      for r <- in_provision,
          r.section_id != row.section_id,
          String.starts_with?(r.section_id, row.section_id),
          {_, _, %Date{} = d} <- [item_split(Map.get(r, :text), made)],
          do: d

    dates = stated ++ listed

    case dates do
      [] -> found
      ds -> %{found | treatment: :clause_staged, date: Enum.min(ds, Date)}
    end
  end

  @tied_ref ~r/\b(?:at the same time as|immediately (?:after|before)|on the (?:same )?(?:day|date) (?:on which|that))\s+(section|regulation|article|rule)\s+(\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)\s+of\s+(?:the\s+)?(.+?)\s+comes?\s+(?:fully\s+)?into\s+(?:force|operation)\b/i
  @prefixes %{"section" => "s", "regulation" => "reg", "article" => "art", "rule" => "rule"}

  @doc """
  The other law's provision a tied clause waits for (V1-02): `{title with
  year, ref}` — "immediately after section 162 of the Health and Care Act
  2022 comes into force" → {"Health and Care Act 2022", "s.162"}; a defined
  term ("the 2022 Act") through its definition in `rows`. nil when unread.
  """
  @spec tied_ref(String.t() | nil, [map()]) :: {String.t(), String.t()} | nil
  def tied_ref(nil, _rows), do: nil

  def tied_ref(sentence, rows) do
    with [_, kind, number, law] <- Regex.run(@tied_ref, sentence),
         title when is_binary(title) <- law_title(law, rows) do
      {title, Map.fetch!(@prefixes, String.downcase(kind)) <> "." <> number}
    else
      _ -> nil
    end
  end

  # "Health and Care Act 2022", or a defined term's meaning ("“the 2022 Act”
  # means the Building Safety Act 2022")
  defp law_title(law, rows) do
    cond do
      law =~ ~r/^[A-Z].*\b(?:Act|Measure)\s+\d{4}$/ and not (law =~ ~r/^\d{4}\s+Act$/) ->
        law

      true ->
        term = Regex.escape("the " <> law)

        Enum.find_value(rows, fn r ->
          case Regex.run(
                 ~r/[“"]#{term}[”"]\s+means\s+the\s+(.+?\b(?:Act|Measure)\s+\d{4})/iu,
                 Map.get(r, :text) || ""
               ) do
            [_, title] -> title
            nil -> nil
          end
        end)
    end
  end

  @doc """
  A staged clause's list item as `{subject, tail, date}` (V1-02): the
  provisions it names and the date it gives them — "Parts 1, 2 … on 16th
  April 2005", "the remainder, on 16th July 2005", "as regards Parts 1 and 4,
  immediately before 31st December 2023", "regulation 4 at 12:01 a.m. on 1
  July 2026", "Part 4, on IP completion day"; the subject is "" when the
  item opens with its date. nil when no date is found.
  """
  @spec item_split(String.t() | nil, OwnDays.days()) :: {String.t(), String.t(), Date.t()} | nil
  def item_split(nil, _made), do: nil

  def item_split(text, made) do
    text = item_text(text)

    text
    |> item_tails()
    |> Enum.find_value(fn {at, tail} ->
      date =
        case tail_date(tail, made) do
          {_, %Date{} = d} ->
            d

          _ ->
            # "immediately before / after 31st December 2023": that date
            tail |> String.replace(~r/^immediately\s+(?:before|after)\s+/i, "") |> date_at_start()
        end

      if date do
        subject = text |> binary_part(0, at) |> String.trim() |> String.trim_trailing(",")
        {String.trim(subject), tail, date}
      end
    end)
  end

  @doc """
  Why a list item `item_split/2` finds no date in is unread:
  `:laid_day_not_held` (`:made_day_not_held`) when its day counts from the
  day the law is laid (made) and that day is not held ("for the purposes of
  regulations 1, 2 and 3 on the 22nd day after the day on which these
  Regulations are laid": SI 2018/1221 reg.2(a)); `:day_unread` otherwise.
  """
  @spec item_unread_reason(String.t() | nil, OwnDays.days()) ::
          :laid_day_not_held | :made_day_not_held | :day_unread
  def item_unread_reason(nil, _days), do: :day_unread

  def item_unread_reason(text, days) do
    text
    |> item_text()
    |> item_tails()
    |> Enum.find_value(:day_unread, fn {_at, tail} ->
      case tail_date(tail, days) do
        :laid_unknown -> :laid_day_not_held
        :made_unknown -> :made_day_not_held
        _ -> nil
      end
    end)
  end

  defp item_text(text), do: text |> String.replace(~r/^\(?[a-z0-9]+\)\s*/i, "") |> String.trim()

  # where an item's day may open, and the words from there: (or at a day
  # counted from the making: "for the purposes of article 18(1), one month
  # after the day on which it is made", SI 2015/776 art.1(c)(i))
  defp item_tails(text) do
    ~r/\b(?=(?:on|from|at|immediately)\b|\w+\s+(?:days?|weeks?|months?)\s+after\b)/i
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{at, _}] ->
      {at, text |> binary_part(at, byte_size(text) - at) |> String.trim()}
    end)
  end

  # "UK_x:reg.1(2)" → "UK_x:reg.1"
  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
