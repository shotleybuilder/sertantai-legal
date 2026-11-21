defmodule SertantaiLegal.Scraper.Commencement.OrderLeftovers do
  @moduledoc """
  A commencement order's leftovers: each statement (`OrderPatterns.units/1`)
  as the order catalogue classes it, with the words bearing on a date no
  rule of the order uses (`Leftovers.of/3`). Its own module, apart from the
  own clause's (`Leftovers`), so the commencement catalogue reaches no
  order reading and an order fix keeps its cache. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OrderPatterns, Rule, TextRefs}

  @doc """
  Each statement of a commencement order (`OrderPatterns.units/1`) as the
  order catalogue classes it, with its leftovers given the order's `rules`.
  """
  @spec order_units(Doc.t(), [Rule.t()]) :: [map()]
  def order_units(doc, rules) do
    units = OrderPatterns.units(doc)

    for unit <- units, not repeats_paragraph?(unit, units) do
      f = OrderPatterns.form(unit)
      o = OrderPatterns.outcome(unit, rules)

      %{
        unit: unit,
        form: f,
        outcome: o,
        pattern: OrderPatterns.key(f, o.class),
        leftovers: if(own_lead?(doc, unit), do: [], else: order_leftovers(unit, rules))
      }
    end
  end

  # an article whose first line is its first paragraph's ("… 1st March
  # 2005. 2"): one statement, the paragraph's (SI 2005/442 art.2)
  defp repeats_paragraph?(%{id: id, text: text}, units) do
    Enum.any?(units, fn %{id: other, text: t} ->
      String.starts_with?(other, id <> "-") and t != "" and String.starts_with?(text, t)
    end)
  end

  # the tail of the order's own "This Order— (a) may be cited as …, and (b)
  # comes into force on …" (SI 2009/3345 art.1)
  defp own_lead?(doc, %{text: text, id: id}) do
    text =~ ~r/^\W*(?:shall\s+)?comes?\s+into\b/i and
      doc
      |> Doc.element(id)
      |> Doc.lines()
      |> Enum.any?(&(&1 =~ ~r/^\W*(?:\d+\s+)*(?:This|These)\s+(?:Order|Regulations)\s*[—–-]/))
  end

  # the order's own commencement and a table's header commence none of the
  # Act; a table row's provisions are its first cell (the next is a subject)
  defp order_leftovers(%{kind: kind}, _rules) when kind in ["own", "table_header"], do: []

  defp order_leftovers(unit, rules) do
    text = if unit.kind == "table", do: unit.text |> String.split(" | ") |> hd(), else: unit.text
    own = OrderPatterns.own_rules(unit, rules)

    cond do
      own_articles?(text) ->
        []

      # a statement bringing in its Schedule's table: the rows' rules use its words
      own == [] and text =~ ~r/\bSchedule\b|\bcolumn\b/ ->
        Leftovers.of(text, rules, &TextRefs.refs_in/1)

      true ->
        Leftovers.of(text, own, &TextRefs.refs_in/1)
    end
  end

  # the order's own articles ("This article and article 2 come into force …",
  # "The following provisions of this Order …", "Article 3 comes into force …")
  defp own_articles?(text),
    # its own paragraphs, its title ("Paragraphs (1) and (2) shall come
    # into force …": SI 2005/2714; "This paragraph, paragraph (3) …": SI
    # 2025/1370; "The title of these Regulations is …": WSI 2024/447)
    do:
      text =~ ~r/^\W*(?:This|These)\s+(?:articles?|Order|regulations?|Regulations)\b/ or
        text =~
          ~r/^\W*The\s+(?:remaining\s+|other\s+|following\s+)?provisions\s+of\s+this\s+(?:Order|instrument)\b/ or
        text =~ ~r/^\W*Articles?\s+\d[^.]*?\b(?:comes?|shall\s+come)\s+into\b/ or
        text =~
          ~r/^\W*(?:Paragraphs?\s+\(\d+[A-Z]?\)|This\s+paragraph\b|The\s+title\s+of\s+th(?:is|ese)\b)/
end
