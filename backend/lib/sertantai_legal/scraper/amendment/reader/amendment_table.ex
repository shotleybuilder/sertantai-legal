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
      nil ->
        []

      el ->
        # a table with no title of its own is in the law its container's
        # titles name ("Amendments to the Climate Change Levy (General)
        # Regulations 2001": SI 2007/2903 Sch.1; yield, 2026-11-27)
        heading = doc |> Doc.headings(id) |> Enum.join(" ")

        el
        |> tables()
        |> Enum.map(&untitled(&1, heading))
        |> Enum.flat_map(&table_rules(&1, doc, id, terms, laws))
    end
  end

  defp untitled({"", columns, rows, kind, item?}, heading),
    do: {heading, columns, rows, kind, item?}

  defp untitled(table, _heading), do: table

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

  @item_column ~r/^\s*(?:Item|No\.?|Number)\s*$/i

  defp table({tabular, table}, previous) do
    # the header's last row ("Column 1 | Column 2" may come first: SI 2008/960)
    case table
         |> xpath(~x".//*[local-name()='thead']/*[local-name()='tr']"l)
         |> List.last()
         |> header() do
      [] when previous != nil ->
        t = put_elem(previous, 2, rows(table, elem(previous, 4)))
        {[t], previous}

      header ->
        # an item number column first is no place ("Item | Regulation, etc |
        # Extent of amendment": SI 2007/2903 Sch.1; yield, 2026-11-27)
        item? = header != [] and header |> hd() |> Doc.text() =~ @item_column
        header = if item?, do: tl(header), else: header
        rows = rows(table, item?)

        case kind(header, rows) do
          nil ->
            {[], nil}

          kind ->
            t = {title(tabular), length(header), rows, kind, item?}
            {[t], t}
        end
    end
  end

  defp header(nil), do: []
  defp header(tr), do: xpath(tr, ~x"./*[local-name()='th']"l)

  # :provisions, the last column each provision's amendment ("Provision |
  # Amendment"; "Regulation, etc | Extent of amendment", the provision's word
  # from the header: SI 2007/2903 Sch.1); :laws, two columns, each law's
  # ("Title | Extent of amendment": SI 2008/960 Sch.3; "Column 1 | Column 2"
  # whose first column names laws: SI 2026/260 Sch.1)
  @provision_head ~r/^\s*(?:Provisions?|(sections?|regulations?|articles?|rules?))\b/i

  defp kind([_, _ | _] = header, rows) do
    first = header |> hd() |> Doc.text()
    last = header |> List.last() |> Doc.text()

    cond do
      first =~ @provision_head and last =~ ~r/\b(?:Extent|Amendments?)\b/i ->
        {:provisions, provision_word(first)}

      last =~ ~r/\bExtent\s+of\s+amendment/i and length(header) == 2 ->
        :laws

      true ->
        last_kind(last, header, rows)
    end
  end

  defp kind(_header, _rows), do: nil

  defp last_kind(last, header, rows) do
    cond do
      last =~ ~r/\bExtent\b/i -> nil
      last =~ ~r/\bAmendments?\b/i -> {:provisions, nil}
      columns_of_laws?(header, rows) -> :laws
      true -> nil
    end
  end

  defp columns_of_laws?(header, rows),
    do:
      length(header) == 2 and Enum.all?(header, &(Doc.text(&1) =~ ~r/^\s*Column\s+\d+\s*$/i)) and
        laws_column?(rows)

  defp provision_word(first) do
    case Regex.run(@provision_head, first, capture: :all_but_first) do
      [word] -> word |> String.downcase() |> String.trim_trailing("s")
      _ -> nil
    end
  end

  @law_title ~r/\b(?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4}\s*$/u
  defp laws_column?([_ | _] = rows),
    do:
      Enum.all?(rows, fn
        [law | _] -> law |> Doc.text() |> String.trim() |> then(&(&1 == "" or &1 =~ @law_title))
        _ -> false
      end)

  defp laws_column?(_rows), do: false

  defp title(tabular),
    do: tabular |> xpath(~x"./*[local-name()='Title']"l) |> Enum.map_join(" ", &Doc.text/1)

  defp rows(table, item?) do
    for tr <- xpath(table, ~x".//*[local-name()='tbody']/*[local-name()='tr']"l),
        cells = xpath(tr, ~x"./*[local-name()='td']"l),
        do: if(item? and length(cells) > 1, do: tl(cells), else: cells)
  end

  defp table_rules({_title, _columns, rows, :laws, _item?}, doc, id, terms, laws) do
    for [law, amendment] <- rows,
        name = law |> Doc.text() |> String.trim(),
        name != "",
        {el, context} <- instructions(amendment, "In the #{name}—"),
        rule <- read_text(el, context, name, {doc, id, terms, laws}),
        do: rule
  end

  defp table_rules({title, columns, rows, {:provisions, word}, _item?}, doc, id, terms, laws) do
    {rules, _above} =
      Enum.flat_map_reduce(rows, List.duplicate("", columns - 1), fn cells, above ->
        row = row(cells, above)
        {read(with_word(row, word), title, {doc, id, terms, laws}), Enum.drop(row, -1)}
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

  # a bare number in the provision cell takes the header's word ("2(1)"
  # under "Regulation, etc": regulation 2(1))
  defp with_word(row, nil), do: row

  defp with_word(row, word) do
    case Enum.split(row, -2) do
      {law, [place, amendment]} ->
        place = if place =~ ~r/^\s*\d/, do: "#{word} #{place}", else: place
        law ++ [place, amendment]

      _ ->
        row
    end
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
