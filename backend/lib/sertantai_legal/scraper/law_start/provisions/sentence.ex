defmodule SertantaiLegal.Scraper.LawStart.Provisions.Sentence do
  @moduledoc """
  One sentence read as groups: its subject, its tail and the list it opens, or tied to another provision's day. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, ListItems, OwnDays, ThatProvision}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Subjects, Treatment, Words}

  @cif Words.cif()
  @list_subject Words.list_subject()
  @other_law_list Words.other_law_list()

  # one sentence → its groups: kind (:named | :remaining | :unread), refs,
  # excluded refs, treatment and date. A list ("The following provisions
  # come into force on …— (a) section 1; (b) section 105 in so far as …")
  # is read item by item: qualified items are their own (D2) group.
  # the power to appoint different days is no qualifier of the statement
  # ("…; and different days may be so appointed for different purposes of
  # this Act or for the same purposes in relation to different courts":
  # 1968 c.64 s.20(4))
  @different_days ~r/\s*[;,]\s*and\s+different\s+(?:days|dates)\s+may\s+be\s+(?:so\s+)?appointed\b.*$/is

  # (read without it; the groups keep the sentence as written)
  # … and with "subsection (2) of that section" as the section it means
  # (`ThatProvision`), a qualifier before its item put after it
  @doc "One sentence read as groups."
  @spec of_sentence(String.t(), map(), [map()], OwnDays.days(), String.t()) :: [map()]
  def of_sentence(sentence, row, rows, made, base) do
    case @different_days
         |> Regex.replace(sentence, "")
         |> ThatProvision.name()
         |> ListItems.qualifier_after() do
      ^sentence -> read_groups(sentence, row, rows, made, base)
      plain -> for g <- read_groups(plain, row, rows, made, base), do: %{g | text: sentence}
    end
  end

  defp read_groups(sentence, row, rows, made, base) do
    [subject, tail] = Regex.split(@cif, sentence, parts: 2)
    {tail, inline} = tail_and_list(tail)
    {treatment, date} = Treatment.tail_treatment(tail, made)

    days =
      tail
      |> Kernel.<>(" " <> inline)
      |> whichever()
      |> alternative_days(subject, row, rows, made, base)

    cond do
      days != nil ->
        days

      list_head?(subject, tail, inline, row, rows) ->
        list_head(subject, row, rows, made, base)

      treatment == :provision_unread and tied?(subject, tail) ->
        tied(sentence, subject, inline, row, rows, made, base)

      true ->
        sentence_groups(sentence, {subject, tail, inline}, {treatment, date}, row, rows, base)
    end
  end

  # an inline list follows "namely—" or a dash; else the rows under this one
  defp tail_and_list(tail) do
    case Regex.split(~r/(?:,?\s*namely\s*)?(?:[—–]|:(?=\s))\s*/u, String.trim(tail), parts: 2) do
      [t, list] -> {t, list}
      [t] -> {t, ""}
    end
  end

  defp list_head?(subject, tail, inline, row, rows),
    do:
      tail == "" and inline == "" and not (subject =~ @list_subject) and
        Refs.children(row, rows) != []

  # "Section 3 comes into force at the same time as section 1 comes fully
  # into force in relation to premises in England" (2021 c.24 s.4(5)): the
  # subject's provisions wait for the other's day (an event day, undated);
  # what qualifies the other's commencement qualifies nothing here. Never a
  # deeming ("are to be regarded as having come into force at the same time
  # as …": 2011 c.19 s.29(5))
  # … nor one after the law's own other provisions, which its general
  # clause dates ("Regulation 18(2) comes into force immediately after the
  # coming into force of the other regulations": SI 2013/1471 reg.1(3))
  @own_rest ~r/\bthe\s+(?:other|remaining|rest\s+of\s+the)\s+(?:regulations|provisions|articles|sections|rules)\b|\bth(?:ese|is)\s+(?:Regulations|Order|Rules|Act)\b/i

  defp tied?(subject, tail) do
    Clause.tied?(tail) and not (subject =~ ~r/\b(?:regarded|treated|deemed|taken)\s+as\b/i) and
      not (tail =~ @own_rest)
  end

  @tied_words "with another provision"

  defp tied(sentence, subject, inline, row, rows, _made, base) do
    read = "#{subject} come into force #{@tied_words}"

    for g <-
          sentence_groups(
            read,
            {subject, @tied_words, inline},
            {:provision_by_order, nil},
            row,
            rows,
            base
          ),
        do: g |> Map.put(:tied, true) |> Map.put(:text, sentence)
  end

  # "Section 1 comes into force— (a) on 1 January 2022 for the purpose of
  # making regulations; (b) on 1 April 2022 for all other purposes": each
  # item dates the head's provisions (UK_ukpga_2021_24 s.4(2), CV-S04)
  defp list_head(subject, row, rows, made, base) do
    subject |> item_groups(row, rows, made, base) |> List.flatten() |> last_purpose_completes()
  end

  # each item below the head read as the head's provisions coming into
  # force on it: its groups, an item's to a list
  defp item_groups(subject, row, rows, made, base) do
    for item <- Refs.children(row, rows),
        text = String.replace(item.text || "", ~r/^\(?[a-z0-9]+\)\s*/i, ""),
        text != "",
        not Regex.match?(@cif, text),
        do: of_sentence("#{subject} come into force #{text}", item, rows, made, base)
  end

  # "Article 25, Schedule 5 and paragraph 4 of Schedule 8 come into force—
  # (a) on the day after the day on which this Order is made; or (b)
  # immediately after IP completion day, whichever is later" (SI 2020/1265
  # art.2(2)): the items are alternative days, and the provisions come in on
  # one of them, the later (or earlier); nil, the sentence read as before,
  # where an item's day is not known ("the day before the day appointed by
  # an Order in Council …": NISI 1999/662 reg.1(3); RULES
  # `feed-differences-are-patterns-by-feed-coverage`, Decision 2)
  @whichever ~r/\bwhichever\s+(?:is|occurs|comes|falls)\s+(?:the\s+)?(later|earlier|last|first|latest|earliest)\b/i

  defp whichever(text) do
    case Regex.run(@whichever, text) do
      [_, which] ->
        if String.downcase(which) in ["later", "last", "latest"], do: :later, else: :earlier

      nil ->
        nil
    end
  end

  defp alternative_days(nil, _subject, _row, _rows, _made, _base), do: nil

  defp alternative_days(which, subject, row, rows, made, base) do
    items = item_groups(subject, row, rows, made, base)
    dates = items |> List.flatten() |> Enum.map(& &1.date)

    if length(items) >= 2 and Enum.all?(items, &(&1 != [])) and
         Enum.all?(dates, &match?(%Date{}, &1)) do
      day = if which == :later, do: Enum.max(dates, Date), else: Enum.min(dates, Date)

      for g <- hd(items),
          do: %{
            g
            | date: day,
              treatment: :provision_dated,
              evidence: row.section_id,
              text: row.text
          }
    end
  end

  # items each bringing the head's provisions in for a purpose of their own,
  # none "for all other purposes": partly in force from the first, fully
  # from the last ("Part 3 comes into force— (a) on 1st April 2017 in
  # relation to non-domestic PR property, (b) on 1st October 2017 in
  # relation to domestic PR property": SI 2015/962 reg.1(3); Decision 14
  # (b), Jason 2026-11-22 — what each purpose means is fractalaw's to tag)
  defp last_purpose_completes([_, _ | _] = groups) do
    if Enum.all?(groups, &match?(%{treatment: :provision_qualified, qualified_date: %Date{}}, &1)) do
      last = Enum.max_by(groups, & &1.qualified_date, Date)

      Enum.map(groups, fn
        ^last ->
          %{last | treatment: :provision_dated, date: last.qualified_date, qualified_date: nil}

        g ->
          g
      end)
    else
      groups
    end
  end

  defp last_purpose_completes(groups), do: groups

  # `words`: the sentence's {subject, tail, inline list}; `dated`: its tail's
  # {treatment, date}
  defp sentence_groups(sentence, words, dated, row, rows, base) do
    {subject, tail, inline} = words
    {treatment, date} = dated

    g = %{
      kind: :named,
      refs: [],
      excluded: [],
      treatment: treatment,
      date: date,
      qualified_date: nil,
      # (a day an order fixes, kept for the items its qualifier leaves
      # partly in: "on the transfer date", 1986 c.44 s.68(3))
      appointed: treatment == :provision_by_order,
      evidence: row.section_id,
      text: sentence
    }

    cond do
      subject =~ @other_law_list -> []
      subject =~ @list_subject -> Subjects.list_groups(g, subject, tail, inline, row, rows, base)
      true -> Subjects.subject_groups(g, sentence, subject, tail, rows, base)
    end
  end
end
