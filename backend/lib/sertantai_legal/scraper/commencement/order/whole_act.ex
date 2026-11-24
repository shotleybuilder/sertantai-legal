defmodule SertantaiLegal.Scraper.Commencement.Order.WholeAct do
  @moduledoc """
  A commencement order's statement of the whole Act, or all of it apart from
  the provisions it names.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Dates,
    Words
  }

  alias SertantaiLegal.Scraper.Commencement.Text.Asides
  alias SertantaiLegal.Scraper.Commencement.{Rule, TextRefs}

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
  @doc "The rules of the order's statements of the whole Act, less what other paragraphs list."
  @spec whole_act(Doc.t(), [String.t()]) :: [Rule.t()]
  def whole_act(order, aliases) do
    made = Dates.made(order)
    names = Enum.map(aliases, &String.replace_prefix(&1, "the ", ""))

    rules =
      for id <- order.ids,
          String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
          head =
            order
            |> Doc.element(id)
            |> Doc.lines()
            |> Enum.map(&Words.clean_line/1)
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
          |> Words.norm()
          |> String.replace_prefix("the ", "")
          |> then(&(&1 in names)) do
        Rule.new(
          commences: :pending,
          scope: :all,
          except: listed(order, id, apart) ++ excepted,
          when: {:date, d},
          source: %{law: order.law_name, ref: Words.source_ref(id), text: Words.squash(head)},
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
      Regex.match?(Words.cif(), line) or Regex.match?(Words.appointed(), line) or
        Regex.match?(Words.appointed_is(), line)

  # "Any provision of the Act to the extent that it has not been commenced
  # before 1 April 2018, comes into force on that date" (WSI 2018/35 art.3):
  # the Act's every provision not yet in force, on the date its subject names
  @any_not_commenced ~r/^\W*any\s+provisions?\s+of\s+(.+?)\s*,?\s+(?:to\s+the\s+extent\s+that|in\s*so\s+far\s+as|so\s+far\s+as)\s+(?:it|they)\s+(?:has|have)\s+not\s+(?:already\s+)?been\s+(?:commenced|brought\s+into\s+force)\s+before\s+(.+?)\s*,?\s+comes?\s+into\s+force\s+on\s+that\s+(?:date|day)\s*\.?\s*$/i

  # {the statement's subject, its date}: "<subject> shall come into force on
  # <date>"; "The day appointed for the coming into operation of <subject>
  # is <date>" (NISR 2010/328); "<date> is the day appointed for the coming
  # into force of <subject>" (SSI 2013/51)
  defp whole_statement(head, made) do
    cond do
      match = Regex.run(@any_not_commenced, head) ->
        [_, subject, date] = match
        {subject, one_date(date)}

      match = Regex.run(Words.appointed_is(), head) ->
        [_, subject, tail] = match
        {subject, one_date(tail)}

      Regex.match?(Words.appointed(), head) ->
        [before, subject] = Regex.split(Words.appointed(), head, parts: 2)
        {String.replace(subject, ~r/\s*\.\s*$/, ""), one_date(before)}

      true ->
        [subject, tail] = Regex.split(Words.cif(), head, parts: 2)
        {subject, Dates.tail_date(tail, made)}
    end
  end

  defp one_date(text) do
    case Dates.parse_dates(text) do
      [d] -> d
      _ -> nil
    end
  end

  # "The rest of the Act, except sections 85 to 87, …" (SI 1996/3146
  # art.3): the Act, less the provisions excepted — {"the Act", their refs}
  @rest_of ~r/^\s*(?:the\s+)?(?:rest|remainder)\s+of\s+(.+?)(?:\s*,?\s+except\s+((?:sections?|regulations?|articles?|paragraphs?|Schedules?)\s+[^,]+?))?\s*,?\s*$/i

  @doc "\"The rest of the Act, except …\": the Act and the refs excepted."
  @spec rest_of(String.t()) :: {String.t(), [String.t()]}
  def rest_of(subject) do
    case Regex.run(@rest_of, subject) do
      [_, act] -> {act, []}
      [_, act, except] -> {act, TextRefs.refs(Asides.strip(except), nil)}
      nil -> {subject, []}
    end
  end

  @doc "\"Apart from the provisions mentioned in paragraph (2), the Act\": {{kind, number}, the rest}; {nil, the words} when not so worded."
  @spec apart(String.t()) :: {{String.t(), String.t()} | nil, String.t()}
  def apart(subject) do
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
        el |> Doc.lines() |> Enum.flat_map(&TextRefs.refs(Asides.strip(&1), nil)) |> Enum.uniq()
    end
  end
end
