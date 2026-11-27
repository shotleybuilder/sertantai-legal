defmodule SertantaiLegal.Scraper.Amendment.Reader.AmendmentTable do
  @moduledoc """
  An amendments table read into rules (Amending-law reader: amending
  Schedules, 2026-11-27): a Schedule's table whose last column is the
  amendment ("Provision | Amendment", SI 2013/1644 Sch.1; "Regulations to be
  amended | Regulation … to be amended | Amendments to be made", SI
  2011/2131 Sch.4), or each law's ("Title | Extent of amendment", SI
  2008/960 Sch.3). Each row's amendment is read as an instruction under
  "In <provision> of <law>—": the law is the row's law cell (an empty one
  is the law above), else the table's title. Pure; the instruction is read
  by `Amendment.Reader.of_text/5`.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}

  @doc "The rules the amendments tables in `id` (in `doc`) state for `laws`; [] when it holds none."
  @spec rules(Doc.t(), String.t(), map(), [Reader.law_ref()]) :: [Rule.t()]
  def rules(doc, id, terms, laws) do
    case Doc.element(doc, id) do
      nil -> []
      el -> el |> tables() |> Enum.flat_map(&table_rules(&1, doc, id, terms, laws))
    end
  end

  @doc "True when the element holds an amendments table."
  @spec table?(Doc.t(), String.t()) :: boolean()
  def table?(doc, id) do
    case Doc.element(doc, id) do
      nil -> false
      el -> tables(el) != []
    end
  end

  # each amendments table: {its title, its columns, its body rows' cells,
  # its kind};
  # a table with no header runs on from the one before it (SI 2013/1644
  # Sch.3: the Transport Act 2000's rows over two tables)
  defp tables(el) do
    {found, _} =
      el
      |> xpath(~x".//*[local-name()='Tabular']"l)
      |> Enum.flat_map(fn tabular ->
        Enum.map(xpath(tabular, ~x".//*[local-name()='table']"l), &{tabular, &1})
      end)
      |> Enum.flat_map_reduce(nil, &table/2)

    found
  end

  defp table({tabular, table}, previous) do
    # the header's last row ("Column 1 | Column 2" may come first: SI 2008/960)
    case table
         |> xpath(~x".//*[local-name()='thead']/*[local-name()='tr']"l)
         |> List.last()
         |> header() do
      [] when previous != nil ->
        t = put_elem(previous, 2, rows(table))
        {[t], previous}

      header ->
        case kind(header) do
          nil ->
            {[], nil}

          kind ->
            t = {title(tabular), length(header), rows(table), kind}
            {[t], t}
        end
    end
  end

  defp header(nil), do: []
  defp header(tr), do: xpath(tr, ~x"./*[local-name()='th']"l)

  # :provisions, the last column each provision's amendment ("Provision |
  # Amendment"); :laws, two columns, each law's ("Title | Extent of
  # amendment": SI 2008/960 Sch.3)
  defp kind([_, _ | _] = header) do
    last = header |> List.last() |> Doc.text()

    cond do
      last =~ ~r/\bExtent\s+of\s+amendment/i and length(header) == 2 -> :laws
      last =~ ~r/\bExtent\b/i -> nil
      last =~ ~r/\bAmendments?\b/i -> :provisions
      true -> nil
    end
  end

  defp kind(_header), do: nil

  defp title(tabular),
    do: tabular |> xpath(~x"./*[local-name()='Title']"l) |> Enum.map_join(" ", &Doc.text/1)

  defp rows(table) do
    for tr <- xpath(table, ~x".//*[local-name()='tbody']/*[local-name()='tr']"l),
        do: xpath(tr, ~x"./*[local-name()='td']"l)
  end

  defp table_rules({_title, _columns, rows, :laws}, doc, id, terms, laws) do
    for [law, amendment] <- rows,
        name = law |> Doc.text() |> String.trim(),
        name != "",
        {el, context} <- instructions(amendment, "In the #{name}—"),
        rule <- read_text(el, context, name, {doc, id, terms, laws}),
        do: rule
  end

  defp table_rules({title, columns, rows, :provisions}, doc, id, terms, laws) do
    {rules, _above} =
      Enum.flat_map_reduce(rows, List.duplicate("", columns - 1), fn cells, above ->
        row = row(cells, above)
        {read(row, title, {doc, id, terms, laws}), Enum.drop(row, -1)}
      end)

    rules
  end

  # a row's cells as texts, one per column: a cell left empty, or spanned
  # from a row above (so missing on the left), is the one above it (SI
  # 2013/1644 Sch.1: "section 12 …" over two rows; SI 2011/2131 Sch.4: the
  # law cell empty under its first row)
  defp row(cells, above) do
    texts = Enum.map(cells, &(&1 |> Doc.text() |> String.trim()))
    own = Enum.take(texts, -1 - length(above))
    lead = Enum.take(above, length(above) + 1 - length(own))

    (lead ++ Enum.drop(own, -1))
    |> Enum.zip(above)
    |> Enum.map(fn {cell, up} -> if cell == "", do: up, else: cell end)
    |> Kernel.++([List.last(cells)])
  end

  # [law, provision, amendment cell], else [provision, amendment cell] in
  # the law the table's title names
  defp read([law, place, amendment], title, reading),
    do: read(place, amendment, if(law == "", do: title, else: law), reading)

  defp read([place, amendment], title, reading), do: read(place, amendment, title, reading)

  defp read(_row, _title, _reading), do: []

  defp read(place, amendment, law, {doc, id, terms, laws}) do
    place = String.trim_trailing(place, ",")

    if place == "" or amendment == nil do
      []
    else
      lead = "In #{place} of #{law}—"

      for {el, context} <- instructions(amendment, lead),
          rule <- read_text(el, context, law, {doc, id, terms, laws}),
          do: rule
    end
  end

  defp read_text(el, context, law, {doc, id, terms, laws}) do
    text = Text.of_element(el, id, context)
    Reader.of_text(text, law, terms, laws, %{law: doc.law_name, ref: id, text: text.instruction})
  end

  # the cell's instructions, each with its context: one per paragraph where
  # each names its own place ("In section 15 …", "In section 22A …": SI
  # 2006/1177 Sch.); else each item of a list under the words before it ("In
  # subsection (6)—" over "(a) for …; and (b) …": SI 2013/1644 Sch.1); else
  # the cell
  defp instructions(cell, lead) do
    paras = xpath(cell, ~x"./*[local-name()='Para']"l)

    if length(paras) > 1 and Enum.all?(paras, &(own_words(&1) =~ ~r/^In\b/)),
      do: Enum.flat_map(paras, &items(&1, lead)),
      else: items(cell, lead)
  end

  # (never a list inside a quote)
  defp items(el, lead) do
    case xpath(
           el,
           ~x".//*[local-name()='ListItem'][not(ancestor::*[local-name()='BlockAmendment' or local-name()='InlineAmendment'])]"l
         ) do
      [] -> [{el, [lead]}]
      items -> Enum.map(items, &{&1, [lead, own_words(el)]})
    end
  end

  # the words of an element's own paragraphs or text, never its list's
  defp own_words(el) do
    el
    |> xpath(~x"./*[local-name()='Para' or local-name()='Text']"l)
    |> Enum.map_join(" ", &Doc.text/1)
    |> String.trim()
  end
end
