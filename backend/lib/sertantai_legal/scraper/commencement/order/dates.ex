defmodule SertantaiLegal.Scraper.Commencement.Order.Dates do
  @moduledoc """
  The date a commencement statement gives: a date stated, the day appointed,
  or a day counted from the order's making.

  Pure; part of the order reader (`Commencement.Order`).
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.Order.Words

  alias SertantaiLegal.Scraper.LawStart.Clause

  # "The appointed day for the coming into force of <provisions> … is
  # <date>" (Welsh orders: WSI 2017/546)
  @date_appointed ~r/^(.*?\d{4})\s+is\s+(?:hereby\s+)?appointed\s+(?:as\s+)?the\s+(?:day|date)\s+on\s+which\s+(.+)$/isu

  # up to the dash or colon that opens a list; a colon inside a bracketed
  # heading opens none ("the Water Industry Act 1991 (temporary bans:
  # supplemental), to make an order under …": SI 2010/2169 art.3(3))
  @to_dash ~S"(?:\([^()]*\)|[^—–:])*"

  # {date, the items stated inline} | nil
  @made_qualifier ~r/(?:(?<!\d)\d{4}|\bmade)\s*,?\s+((?:(?:in\s*)?so\s*far|insofar)\s+as\b#{@to_dash}|to\s+the\s+extent\b#{@to_dash}|for\s+the\s+purposes?\s+of\b#{@to_dash})/iu

  @doc "A statement head's date and the items it states inline; nil when it states no date."
  @spec statement(String.t(), Date.t() | nil) :: {Date.t(), String.t()} | nil
  def statement(head, made) do
    cond do
      match = Regex.run(Words.appointed_is(), head) -> appointed_is(match)
      Regex.match?(Words.appointed(), head) -> appointed(head)
      match = Regex.run(@date_appointed, head) -> date_appointed(match)
      Regex.match?(Words.cif(), head) -> into_force(head, made)
      true -> nil
    end
  end

  # "The appointed day for the coming into force of X … is D—": the date
  # after "is"; the items X, or after the dash ("the following")
  defp appointed_is([_, subject, tail]) do
    [date_part | after_dash] = Regex.split(~r/[—–:]\s*/u, tail, parts: 2)

    with [d] <- parse_dates(date_part),
         do: {d, following(subject, Enum.join(after_dash, " "), subject)},
         else: (_ -> nil)
  end

  @doc "\"D is the day appointed for the coming into force of X\": {D, X}; nil without one date."
  @spec appointed(String.t()) :: {Date.t(), String.t()} | nil
  def appointed(head) do
    [before, after_] = Regex.split(Words.appointed(), head, parts: 2)
    with [d] <- parse_dates(before), do: {d, after_}, else: (_ -> nil)
  end

  # "The 20th of May 2005 is hereby appointed the day on which the following
  # provisions of the … Act 2003 come into force:" (SSI 2005/256): the date
  # before "is appointed"; the items after the dash
  defp date_appointed([_, before, subject]) do
    [subject | after_dash] = Regex.split(~r/(?:[—–]|:(?![^()]*\)))\s*/u, subject, parts: 2)
    subject = String.replace(subject, Words.cif(), "")

    with [d] <- parse_dates(before),
         do: {d, following(subject, Enum.join(after_dash, " "), subject)},
         else: (_ -> nil)
  end

  # "<subject> shall come into force on <date>"
  defp into_force(head, made) do
    [subject, tail] = Regex.split(Words.cif(), head, parts: 2)

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
        {d,
         following(
           subject,
           after_dash,
           subject <> before_date(tail) <> after_date(tail) <> " " <> after_dash
         )}
    end
  end

  # a qualifier between "comes into force" and the date is the subject's
  # too ("Section 132 … comes into force, for the purposes of making
  # regulations, on 28th May 2022": SI 2022/561 reg.2); a "the following"
  # head's reaches its items as `list_qualifier/1` reads it
  @before_date ~r/^\s*,\s*((?:for\s+the\s+purposes?\s+of|(?:in\s*)?so\s*far\s+as|insofar\s+as|to\s+the\s+extent)\b[^,—–]*?)\s*,\s*on\b/iu

  defp before_date(tail) do
    case Regex.run(@before_date, tail) do
      [_, q] -> " " <> q
      nil -> ""
    end
  end

  # a qualifier after the date is the subject's ("Section 120(1) of, and
  # Schedule 22 to, the 1995 Act come into force on 1st April 2015 in so far
  # as they relate to paragraph 81 of Schedule 22": SSI 2015/73, CV-S04
  # round 4; after a made-relative day, "… on the day after this Order is
  # made so far as they relate to …": SI 2009/1261 art.4)
  defp after_date(tail) do
    case Regex.run(@made_qualifier, tail) do
      [_, q] -> " " <> q
      nil -> ""
    end
  end

  # "the following" names its items after the dash; otherwise the subject
  defp following(subject, items, otherwise),
    do: if(subject =~ ~r/\bthe following\b/i, do: items, else: otherwise)

  # a statement's date: one stated, else counted from the order's making
  # ("the day after this Order is made": LR-33's reading)
  @doc "A statement's date: one stated, else counted from the order's making."
  @spec tail_date(String.t(), Date.t() | nil) :: Date.t() | nil
  def tail_date(tail, made) do
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
  @doc "The order's made date (CLML metadata)."
  @spec made(Doc.t()) :: Date.t() | nil
  def made(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      with d when d != "" <- root |> xpath(~x"//*[local-name()='Made']/@Date"s) |> to_string(),
           {:ok, date} <- Date.from_iso8601(d) do
        date
      else
        _ -> nil
      end
    end)
  end

  # one provision's two days in one sentence: "The day appointed for the
  # coming into force of X for the purpose of P is D1 and for all other
  # purposes is D2" (SSI 2007/50 art.2), read as two statements
  @then_all_other ~r/\b(the\s+(?:day|date)\s+appointed\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of)\s+(.+?)\s+(for\s+the\s+purposes?\s+of\s+.+?)\s+is\s+(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4})\s+and\s+(for\s+all\s+other\s+purposes)\s+is\s+(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4})/isu

  @doc "One head giving two days (for some purposes, then all others) as two statements; else the head."
  @spec two_days(String.t()) :: [String.t()]
  def two_days(head) do
    case Regex.run(@then_all_other, head) do
      [_, lead, x, purpose, d1, other, d2] ->
        ["#{lead} #{x} #{purpose} is #{d1}.", "#{lead} #{x} #{other} is #{d2}."]

      nil ->
        [head]
    end
  end

  # ── helpers ─────────────────────────────────────────────────────────

  @months ~w(january february march april may june july august september october november december)

  @date ~r/(\d{1,2})(?:st|nd|rd|th)? (January|February|March|April|May|June|July|August|September|October|November|December),? (\d{4})/i

  # "1st October 2001", "2 April 1994" → dates, in order
  @doc "Every date in the words, in order."
  @spec parse_dates(String.t()) :: [Date.t()]
  def parse_dates(w) do
    for [_, day, month, year] <- Regex.scan(@date, w) do
      m = Enum.find_index(@months, &(&1 == String.downcase(month))) + 1
      Date.new!(String.to_integer(year), m, String.to_integer(day))
    end
  end
end
