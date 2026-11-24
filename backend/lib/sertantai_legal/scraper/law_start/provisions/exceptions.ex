defmodule SertantaiLegal.Scraper.LawStart.Provisions.Exceptions do
  @moduledoc """
  What a statement takes out of what it commences: "except …", "other than …", "not until …", "that is to say", and another law's list. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{Clause, OwnDays, Statements}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Mentioned, Refs, Treatment, Words}
  alias SertantaiLegal.Scraper.LawStart.Provisions

  @list_subject Words.list_subject()
  @other_law_list Words.other_law_list()
  @qualified Words.qualified()

  # a pointer to provisions named elsewhere, never what a general clause's
  # inline exception excepts ("except as provided in paragraph (2) below":
  # SI 2000/3251); a statement's "except the provisions mentioned in
  # subsection (1)" is followed there (2022 c.30 s.170(2))
  @pointer ~r/\b(?:in\s+accordance\s+with|(?:provided|specified|listed|mentioned|set\s+out|referred\s+to)\s+(?:for\s+)?(?:in|by|under))\b/i

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
    base = Words.provision(evidence)
    row = Enum.find(rows, &(&1.section_id == evidence))

    source =
      if text =~ ~r/(?:except|apart\s+from|other\s+than)\s*[—–]/u and row != nil,
        do: row |> Refs.children(rows) |> Enum.map_join("; ", &(&1.text || "")),
        else: inline_except(text)

    source
    |> String.split(~r/;\s*/, trim: true)
    |> Enum.reject(&Regex.match?(@qualified, &1))
    |> Enum.flat_map(&Refs.weighted_refs(&1, rows, base))
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
    {_named, _excepted, partly} = Mentioned.mentioned_items(text, rows, Words.provision(evidence))

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
        Enum.find_value(@inline_excepts, "", &Provisions.first_group(&1, text))
    end
  end

  @doc "A sentence split into its statements (`LawStart.Statements`)."
  @spec statements(String.t()) :: [String.t()]
  def statements(s), do: Statements.split(s)

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
  @doc "A statement whose \"except …\" or \"that is to say\" names its own groups; [] when none."
  @spec except_which(String.t(), map(), [map()], OwnDays.days(), String.t()) :: [map()]
  def except_which(s, row, rows, made, base) do
    case Enum.find_value(@except_which, &Regex.run(&1, s)) do
      [_, subject, tail] ->
        for {subject, tail} <- chained(following(subject, row, rows), tail),
            [_ | _] = refs <- [Refs.weighted_refs(subject, rows, base)],
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
      do: row |> Refs.children(rows) |> Enum.map_join(", ", &(&1.text || "")),
      else: subject
  end

  defp chained(subject, tail) do
    case Regex.run(@and_dated, tail) do
      [_, first, next, rest] -> [{subject, first} | chained(next, rest)]
      nil -> [{subject, tail}]
    end
  end

  defp except_date(tail, subject, made) do
    case Treatment.tail_treatment(tail, made) do
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
      Refs.split_except(list)
    else
      _ -> {subject, ""}
    end
  end

  @doc "A \"not until …\" statement: in partly from the start, fully from its day; nil when not so."
  @spec not_until(String.t(), map(), [map()], OwnDays.days(), String.t(), Date.t() | nil) ::
          [map()] | nil
  def not_until(s, row, rows, made, base, start) do
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
      refs = Refs.weighted_refs(subject, rows, base)

      kind =
        cond do
          refs != [] -> :named
          Regex.match?(@the_law, subject) -> :remaining
          true -> nil
        end

      g = %{
        kind: kind,
        refs: refs,
        excluded: Refs.refs(excepted, rows, Treatment.relative_base(refs, base)),
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
end
