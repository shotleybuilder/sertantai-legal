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
  | "in accordance with paragraphs (2) and (3)", "as follows", a list: the earliest date its provision's other sentences state | `:clause_staged` |
  | no clause for the whole law, only for its parts ("This Article and Article 2 …", "The remaining provisions of this Order …"): the earliest date that provision states | `:clause_staged` |
  | "on such day as … may by order appoint" | `:by_order` |
  | "at the same time as section 83 of the 2022 Act comes into force" | `:tied_to_other_law` |
  | anything else, or a made-relative tail without a made date | `:clause_unread` |

  Counting periods (Interpretation Act conventions): a period "from" or
  "after" a day excludes that day, so "the expiration of N months from the
  day on which it is made" is the day after made + N months; a period
  "beginning with" the day includes it, so its end is made + N. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart

  @ip_completion_day ~D[2020-12-31]
  @exit_day ~D[2020-01-31]

  @instrument ~S"(?:Order(?: in Council)?|Regulations?|Rules|Act|Measure|Scheme|Instrument|Byelaws?|Directions)"
  # an aside between commas: ", subject to paragraphs (2) and (3),"
  @aside ~S"(?:\s*,[^,]{0,160},)?\s*"
  @cif ~S"(?:shall" <> @aside <> ~S")?(?:comes?|came)\s+into\s+(?:force|operation)"
  # "Subject to paragraphs (3), (4) and (5) these Regulations …" (commas in
  # a list of paragraphs: V1-02)
  @prefix ~S"^(?:\(?\d+[A-Z]?\)?\s+)?(?:(?:Subject to|Except as (?:otherwise )?(?:provided|specified)|Save as (?:otherwise )?provided|Apart from)(?:[^,]|,(?=\s*(?:\(|and\b|or\b))){0,200}?(?:,\s*|\s+(?=(?:this|these|the)\s)))?"

  @general [
    Regex.compile!(
      @prefix <>
        ~S"(?:this|these|the)\s+" <>
        @instrument <> ~S"\b(?:\s*\([^)]*\))?" <> @aside <> @cif <> ~S"\s*(.*)$",
      "is"
    ),
    Regex.compile!(
      ~S"\b(?:this|these)\s+" <>
        @instrument <> ~S"\s+may be cited as\b.{0,300}?\band" <> @aside <> @cif <> ~S"\s*(.*)$",
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
    "sixtieth" => 60
  }

  @made ~S"(?:(?:the\s+(?:day|date)\s+(?:(?:on\s+which|of)\s+)?)?(?:it\s+is|they\s+are|they\s+were|(?:(?:this|these)\s+[A-Za-z ]+?|the\s+(?:Order|Regulations|Rules|Act|Scheme|Measure|Instrument))\s+(?:is|are|was|were))\s+(?:made|passed)|(?:the\s+)?(?:making|passing)\s+(?:of\s+(?:this|these)\s+[A-Za-z ]+|thereof)|its\s+(?:making|passing)|(?:the\s+day\s+(?:on\s+which\s+)?)?(?:this\s+Act\s+receives\s+)?Royal\s+Assent)"
  @number ~S"(\d+|[a-z]+(?:[- ][a-z]+)?)"

  @doc "The law's start from its commencement clause; nil when it has none."
  @spec read([map()], Date.t() | nil) :: LawStart.t() | nil
  def read(rows, made) do
    case general(rows) do
      nil -> own_parts(rows, made)
      {row, sentence, tail} -> decide(rows, row, sentence, tail, made)
    end
  end

  # no clause for the whole law, but its parts commence: the earliest date
  # the first such provision states (`:clause_staged`); unread when it
  # states none
  defp own_parts(rows, made) do
    Enum.find_value(rows, fn row ->
      case row |> Map.get(:text) |> sentences() |> Enum.find(&Regex.match?(@own_part, &1)) do
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

  defp decide(rows, row, sentence, tail, made) do
    found = %LawStart{treatment: :clause_unread, evidence: row.section_id, text: sentence}

    case tail_date(tail, made) do
      {treatment, %Date{} = d} ->
        %{found | treatment: treatment, date: d}

      :made_unknown ->
        found

      nil ->
        cond do
          by_order?(tail) -> %{found | treatment: :by_order}
          tied?(tail) -> %{found | treatment: :tied_to_other_law}
          staged?(tail) -> staged(rows, row, found, made)
          true -> found
        end
    end
  end

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
  @item_cif ~r/^(?:\(?[a-z0-9]+\)\s*)?(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\s*(.*?)\s*(?:;\s*(?:and|or)?)?\s*$/i
  @pronoun Regex.compile!(@prefix <> ~S"(?:they|it)" <> @aside <> @cif <> ~S"\s*(.*)$", "is")

  defp listed(rows) do
    Enum.find_value(rows, fn row ->
      if Regex.match?(@parent, Map.get(row, :text) || "") do
        Enum.find_value(rows, fn item ->
          with true <- item.section_id != row.section_id,
               true <- String.starts_with?(item.section_id, row.section_id <> "("),
               [_, tail] <- Regex.run(@item_cif, Map.get(item, :text) || "") do
            {item, String.trim(item.text), String.trim(tail)}
          else
            _ -> nil
          end
        end)
      end
    end)
  end

  defp pronoun(rows) do
    cited =
      for r <- rows,
          (Map.get(r, :text) || "") =~ ~r/\bmay be cited as\b/i,
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
      |> String.replace(~r/\s+/, " ")
      |> String.split(
        ~r/(?<=\.)(?<!\betc\.)(?<!\bNo\.)(?<!\bNos\.)(?<!\bSch\.)(?<!\bart\.)(?<!\breg\.)(?<!\bs\.)(?<!\bc\.)(?<!\bi\.e\.)(?<!\be\.g\.)\s+(?=[A-Z(])/
      )

  @doc """
  A tail's date and its treatment: `{treatment, date}`; `:made_unknown`
  when it counts from a made date we don't have; nil when it states none.
  """
  @spec tail_date(String.t(), Date.t() | nil) ::
          {LawStart.treatment(), Date.t()} | :made_unknown | nil
  def tail_date(tail, made) do
    cond do
      d = named_day(tail, made) ->
        {:clause_named_day, d}

      d = date_at_start(String.replace(tail, ~r/^(?:at [^,]{1,30}? )?(?:on|from)\s+/i, "")) ->
        {:clause_date, d}

      d = by_territory(tail) ->
        {:clause_staged, d}

      true ->
        made_relative(tail, made)
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

  defp named_day(tail, made) do
    case Regex.run(
           ~r/^(?:on\s+|at\s+|immediately\s+(?:before|after)\s+)?(IP completion day|implementation period completion day|exit day)\b/i,
           tail
         ) do
      [_, day] ->
        if day =~ ~r/^(?:IP|implementation)/i, do: @ip_completion_day, else: exit_day(tail, made)

      nil ->
        nil
    end
  end

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

  @doc "A date at the start of text: \"17th April 1995\", \"30 th August 2013\", \"1 October 2020\"."
  @spec date_at_start(String.t()) :: Date.t() | nil
  def date_at_start(text) do
    re = ~r/^(?:the\s+)?(\d{1,2})\s*(?:st|nd|rd|th)?\s*(?:day\s+of\s+)?([A-Za-z]+),?\s+(\d{4})\b/

    with [_, d, m, y] <- Regex.run(re, String.trim(text)),
         month when is_integer(month) <- Enum.find_index(@months, &(&1 == String.downcase(m))),
         {:ok, date} <- Date.new(String.to_integer(y), month + 1, String.to_integer(d)) do
      date
    else
      _ -> nil
    end
  end

  defp made_relative(tail, made) do
    case made_shift(tail) do
      nil -> nil
      _shift when is_nil(made) -> :made_unknown
      shift -> {:clause_made_relative, shift.(made)}
    end
  end

  # the tail's count from the made date, as a function of it; nil when the
  # tail doesn't count from it
  defp made_shift(tail) do
    t = String.replace(tail, ~r/\s+/, " ")

    cond do
      Regex.match?(
        ~r/^on (?:the (?:day|date) (?:(?:on which|of) )?|Royal Assent|the (?:passing|making) of)/i,
        t
      ) and
          starts_made?(t, ~r/^on /i) ->
        & &1

      Regex.match?(~r/^(?:on )?the day (?:after|following) /i, t) and
          starts_made?(t, ~r/^(?:on )?the day (?:after|following) /i) ->
        &Date.add(&1, 1)

      m = Regex.run(~r/^(?:on )?the #{@number} day (?:after|following) (.*)$/i, t) ->
        [_, n, rest] = m
        with_made(rest, n, fn made, k -> Date.add(made, k) end)

      m =
          Regex.run(
            ~r/^(?:on )?the first day of the (?:#{@number} )?(?:calendar )?month (?:following|after) (?:that|the month) in which (.*)$/i,
            t
          ) ->
        first_of_month(m)

      m =
          Regex.run(
            ~r/^(?:on |at |with )?(?:the )?(?:expiration|expiry|end) of (?:a |the )?(?:period of )?#{@number} (days?|weeks?|months?|years?) (from|after|beginning with|beginning on|starting with) (.*)$/i,
            t
          ) ->
        [_, n, unit, rel, rest] = m
        extra = if String.downcase(rel) in ["from", "after"], do: 1, else: 0
        with_made(rest, n, fn made, k -> made |> shift(unit, k) |> Date.add(extra) end)

      m = Regex.run(~r/^(?:on )?#{@number} (days?|weeks?|months?) after (.*)$/i, t) ->
        [_, n, unit, rest] = m
        with_made(rest, n, fn made, k -> shift(made, unit, k) end)

      true ->
        nil
    end
  end

  defp starts_made?(t, lead),
    do:
      Regex.match?(
        ~r/^#{@made}/i,
        t
        |> String.replace(lead, "")
        |> String.replace(~r/^the day (?:on which|of) /i, "the day on which ")
      )

  defp with_made(rest, n, fun) do
    with true <- Regex.match?(~r/^#{@made}/i, rest),
         k when is_integer(k) <- number(n) do
      &fun.(&1, k)
    else
      _ -> nil
    end
  end

  defp first_of_month([_, n, rest]) do
    k = if n in [nil, ""], do: 1, else: number(n)

    if is_integer(k) and Regex.match?(~r/^#{@made}/i, rest),
      do: fn made -> made |> Date.beginning_of_month() |> Date.shift(month: k) end
  end

  defp first_of_month([_, rest]), do: first_of_month([nil, "", rest])

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
      {i, ""} ->
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

  @doc "A tail leaving the commencement to an order (\"on such day as … may by order appoint\")."
  @spec by_order?(String.t()) :: boolean()
  def by_order?(tail),
    do:
      tail =~
        ~r/\bsuch (?:day|date|time)s?\b|\bday appointed\b|\bappointed (?:day|by)\b|\bmay,? by (?:order|regulations)\b|\bmay appoint\b|\bappoints\b|\bprovision made by (?:\w+ ){0,6}(?:by )?order\b|\bspecified by order\b/i

  defp tied?(tail),
    do:
      tail =~
        ~r/\bat the same time as\b|^immediately (?:after|before)\b.*\binto (?:force|operation)|^on the (?:same )?(?:day|date) (?:on which|that)\b.*\binto (?:force|operation)/i

  defp staged?(tail),
    do:
      tail == "" or
        tail =~
          ~r/^(?:[—:;,–-]|as follows|on the following dates?|in accordance with|in stages|subject to)/i

  # the earliest date the clause's own provision states elsewhere
  # ("(2) … on 1st June 2015", "(3) … on IP completion day")
  defp staged(rows, row, found, made) do
    base = provision(row.section_id)

    in_provision = Enum.filter(rows, &(provision(&1.section_id) == base))

    stated =
      for r <- in_provision,
          s <- sentences(Map.get(r, :text)),
          [_, tail] <- [Regex.run(~r/\binto\s+(?:force|operation)\s+(.*)$/i, s)],
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
  @spec item_split(String.t() | nil, Date.t() | nil) :: {String.t(), String.t(), Date.t()} | nil
  def item_split(nil, _made), do: nil

  def item_split(text, made) do
    text = text |> String.replace(~r/^\(?[a-z0-9]+\)\s*/i, "") |> String.trim()

    ~r/\b(?=(?:on|from|at|immediately)\b)/i
    |> Regex.scan(text, return: :index)
    |> Enum.find_value(fn [{at, _}] ->
      tail = text |> binary_part(at, byte_size(text) - at) |> String.trim()

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

  # "UK_x:reg.1(2)" → "UK_x:reg.1"
  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
