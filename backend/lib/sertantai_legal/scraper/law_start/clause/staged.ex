defmodule SertantaiLegal.Scraper.LawStart.Clause.Staged do
  @moduledoc """
  A clause whose law comes in by stages, by order, or tied to another law's provision, and its items' dates. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{MadeCondition, OwnDays, Sentences}
  alias SertantaiLegal.Scraper.LawStart.Clause.{Tail, WrittenDates}

  # a named provision's day going on to the rest is a part commencing too
  # ("Regulation 9 comes into force on 1st January 2015 and all other
  # regulations come into force on 6th April 2010": SI 2010/740 reg.1(2))
  # (its day a date, or tied to another provision's: "Regulation 15 shall
  # come into force on the date on which section 7(3) of the Water Act 2003
  # comes into force, and all other provisions … on 1st April 2006": SI
  # 2006/641 reg.1(2))
  @named_then_rest ~r/^(?:\(?\d+[A-Z]?\)?\s+)?(?:regulations?|articles?|sections?|rules?)\s+\d[^.;]{0,300}?\binto\s+(?:force|operation)\s+on\s+(?:[^.;]{0,60}?\d{4}|the\s+(?:day|date)\s+on\s+which\b[^.;]{0,200}?\binto\s+(?:force|operation))\s*,?\s+and\s+(?:all\s+|the\s+)?(?:other|remaining)\s+(?:provisions|regulations|articles|sections|rules)\b[^.;]{0,200}?\binto\s+(?:force|operation)\b/i

  @doc "A named provision's day going on to the rest (\"Regulation 9 comes into force on … and all other regulations …\")."
  @spec named_then_rest() :: Regex.t()
  def named_then_rest, do: @named_then_rest

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

  @doc "Whether a tail opens a staged clause (\"as follows\", \"in accordance with\", a dash, or nothing)."
  @spec staged?(String.t()) :: boolean()
  def staged?(tail),
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
  @doc "A staged clause's start: the earliest date the clause's own provision states elsewhere."
  @spec staged([map()], map(), LawStart.t(), OwnDays.days()) :: LawStart.t()
  def staged(rows, row, found, made) do
    base = provision(row.section_id)

    # (a head whose condition on the making day fails states nothing: SI
    # 2024/1366 art.2(3))
    in_provision =
      rows |> Enum.filter(&(provision(&1.section_id) == base)) |> MadeCondition.holding(made)

    stated =
      for r <- in_provision,
          s <- Sentences.sentences(Map.get(r, :text)),
          tail <- tails(s),
          {_, %Date{} = d} <- [Tail.tail_date(String.trim(tail), made)],
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
        defined =
          ~r/[“"]#{Regex.escape("the " <> law)}[”"]\s+means\s+the\s+(.+?\b(?:Act|Measure)\s+\d{4})/iu

        Enum.find_value(rows, &defined_title(&1, defined))
    end
  end

  defp defined_title(row, defined) do
    case Regex.run(defined, Map.get(row, :text) || "") do
      [_, title] -> title
      nil -> nil
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
        case Tail.tail_date(tail, made) do
          {_, %Date{} = d} ->
            d

          _ ->
            # "immediately before / after 31st December 2023": that date
            tail
            |> String.replace(~r/^immediately\s+(?:before|after)\s+/i, "")
            |> WrittenDates.date_at_start()
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
      case Tail.tail_date(tail, days) do
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
  @doc "A row's provision: its section id without paragraphs."
  @spec provision(String.t()) :: String.t()
  def provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
