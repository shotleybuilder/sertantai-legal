defmodule SertantaiLegal.Scraper.LawStart.Provisions.OpenItems do
  @moduledoc """
  An open list's items ("come into force as follows— (a) …; (b) …"), each read as a sentence of its own: undated, named, or a purpose. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, OwnDays}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Sentence}

  @purpose_item ~r/^(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that|for\s+(?:the\s+)?purposes?\s+of|for\s+all\s+(?:other\s+|remaining\s+)?purposes)\b/i

  # an item whose day is not read is kept, unread, with the reason where
  # the day counts from one not held ("for the purposes of regulations 1, 2
  # and 3 on the 22nd day after the day on which these Regulations are
  # laid": SI 2018/1221 reg.2(a), no laid day held) — never dropped, which
  # left its provisions to the other items' days
  @doc "An open list's item read as its own sentence: its groups."
  @spec open_item(map(), [map()], OwnDays.days(), String.t()) :: [map()]
  def open_item(item, rows, made, base) do
    case Clause.item_split(item.text, made) do
      {subject, tail, date} -> open_item(subject, tail, date, item, rows, made, base)
      nil -> [undated_item(item, rows, made, base)]
    end
  end

  # an item of a general clause's list: its subject's provisions; "except
  # for regulations 4 and 14, on …" the rest less those (SI 1993/1213
  # reg.1(a)); an item opening with its date, the whole law — fully "for all
  # other purposes", else partly, for the purpose or place it names ("from
  # 1st July 2004 for international shipping": SI 2004/1495 reg.1(a))
  defp open_item("", tail, date, item, _rows, _made, _base) do
    whole? = tail =~ ~r/\bfor\s+all\s+(?:other\s+)?purposes\b/i

    rest =
      String.replace(tail, ~r/^(?:on|from)\s+\S+\s+\S+,?\s+\d{4}[\s;,.]*(?:and|or)?\s*$/i, "")

    partial? = not whole? and rest != ""

    [
      %{
        kind: :remaining,
        refs: [],
        excluded: [],
        treatment: if(partial?, do: :provision_qualified, else: :provision_dated),
        date: if(partial?, do: nil, else: date),
        qualified_date: if(partial?, do: date),
        evidence: item.section_id,
        text: item.text
      }
    ]
  end

  # an item opening with its purpose is the whole law's too: partly for it,
  # fully "for all other purposes" ("(a) insofar as Part 2A of the 1990 Act
  # empowers …, on 16 November 2006; (b) for all other purposes, on 10
  # December 2006": SI 2006/2988 reg.1(2))
  defp open_item(subject, tail, date, item, rows, made, base) do
    # (one naming a provision too: the law is the subject, the provision
    # names the purpose — "for the purposes of article 18(1), one month
    # after …": SI 2015/776 art.1(c)(i); Jason 2026-11-20)
    if Regex.match?(@purpose_item, subject),
      do: open_item("", "#{tail} #{subject}", date, item, rows, made, base),
      else: named_item(subject, tail, item, rows, made, base)
  end

  defp undated_item(item, rows, made, base) do
    %{
      kind: :unread,
      refs: Refs.weighted_refs(item.text, rows, base),
      excluded: [],
      treatment: :provision_unread,
      date: nil,
      qualified_date: nil,
      reason: Clause.item_unread_reason(item.text, made),
      evidence: item.section_id,
      text: item.text
    }
  end

  # a purpose in an item's middle limits only what follows it: "Parts 1, 2,
  # paragraph 1 of Part 1 of Schedule 12 and, for the purposes of that
  # paragraph only, in Part 5, regulation 59(3) and Schedule 9 and
  # regulation 74 on 6 July 2005" (WSI 2005/1806 reg.1(2)(i)): Parts 1 and 2
  # fully, regulation 59(3) and the rest partly
  @mid_purpose ~r/^(.+?)\s+and,\s+(for\s+(?:the\s+)?purposes?\s+of\s+[^,]+?)\s*,\s*(.+)$/is

  defp named_item(subject, tail, item, rows, made, base) do
    subject =
      String.replace(
        subject,
        ~r/^(?:except|other\s+than|apart\s+from)\b/i,
        "the remaining provisions \\0"
      )

    case Regex.run(@mid_purpose, subject) do
      [_, plain, purpose, limited] ->
        Sentence.of_sentence("#{plain} come into force #{tail}", item, rows, made, base) ++
          Sentence.of_sentence(
            "#{limited} come into force #{tail} #{purpose}",
            item,
            rows,
            made,
            base
          )

      nil ->
        Sentence.of_sentence("#{subject} come into force #{tail}", item, rows, made, base)
    end
  end
end
