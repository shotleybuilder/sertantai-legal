defmodule SertantaiLegal.Scraper.LatParser.Text do
  @moduledoc """
  A provision's text as segments (`LatSegments`) for the LAT parser (LR-04):

  - text blocks in document order (`text_blocks/2`): :leaf (all the text)
    or :structural (stopping at child rows, a :gap where they sit)
  - lists (numbered from Type / Decoration / NumberOverride), XHTML tables,
    signatures, «…» quoted blocks (amending text, extracts) with AppendText
  - a row's leaf or structural text, and the sibling content an open
    provision takes (#174)

  Inline markup and change markup come from `Inline`. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.{Ids, Inline, Items, Xml}
  alias SertantaiLegal.Scraper.LatSegments

  @doc """
  A provision's lead-in — its first text block — ends in a dash or colon:
  what follows continues it (its own list may sit in between, as in
  PUWER 1998 reg.2(1) "…otherwise requires— [definitions]").
  """
  @spec open_lead_in?(tuple()) :: boolean()
  def open_lead_in?(node), do: node |> text_blocks(:structural) |> open_block?()

  @doc """
  The lead-in before a node's first child row (its text up to the first
  provision) ends in a dash or colon: the children are the node's list
  ("Any person who— (a) … (b) …").
  """
  @spec lead_in_before_children_open?(tuple()) :: boolean()
  def lead_in_before_children_open?(node) do
    node |> text_blocks(:structural) |> Enum.take_while(&(&1 != :gap)) |> open_block?()
  end

  @doc """
  A provision takes the sibling content after it (#174): its lead-in is
  open — unless its parent's lead-in is open too and it has sub-provisions
  of its own, which complete it; the content then finishes the parent's
  sentence (1993/11 s.23(1): "Any person who— (a) … (c) … to— (i) (ii)
  shall be guilty …"; LR-05).
  """
  @spec takes_trailing?(tuple(), boolean()) :: boolean()
  def takes_trailing?(child, parent_open?) do
    Xml.element_name(child) in Xml.provision_rows() and open_lead_in?(child) and
      not (parent_open? and own_provisions?(child))
  end

  # child provisions of its own (not those quoted in amending text)
  defp own_provisions?(node) do
    xpath(
      node,
      ~x".//*[self::P1 or self::P2 or self::P3 or self::P4][not(ancestor::BlockAmendment) and not(ancestor::BlockExtract)][1]"o
    ) != nil
  end

  defp open_block?(blocks) do
    case Enum.find(blocks, &(is_list(&1) and not LatSegments.blank?(&1))) do
      nil -> false
      lead -> lead |> LatSegments.plain() |> String.match?(~r/[—–:-]\s*$/u)
    end
  end

  @doc """
  Leaf text: every Text in document order, each once, separated by a space
  (inline fragments within one Text are joined without extra spaces —
  they're split by markup like <Term>, <Addition>). Lists, nested lists and
  text after a list keep their order (2026-10-07: the old Para-then-Text
  build moved chapeaux to the end and repeated nested list items).
  """
  @spec leaf(tuple()) :: LatSegments.t()
  def leaf(node) do
    node |> text_blocks(:leaf) |> join_blocks()
  end

  defp quoted_text(element) do
    case element |> quoted_parts() |> LatSegments.join(" ") do
      [] -> []
      segments -> LatSegments.mark("«") ++ LatSegments.trim(segments) ++ LatSegments.mark("»")
    end
  end

  defp quoted_parts(element) do
    parent = elem(element, 1)

    element
    |> elem(8)
    |> Enum.flat_map(fn child ->
      case elem(child, 0) do
        :xmlElement -> quoted_child(child, parent)
        _ -> []
      end
    end)
  end

  defp quoted_child(child, parent) do
    case to_string(elem(child, 1)) do
      "Pnumber" ->
        # numbers and titles show but never count as the row's own words
        [
          child
          |> Inline.plain()
          |> quoted_number(parent)
          |> LatSegments.text()
          |> LatSegments.aside()
        ]

      "Title" ->
        [child |> Inline.text() |> LatSegments.aside()]

      "Text" ->
        [Inline.text(child)]

      # "Schedule 4A", "Part 1", "Section 25"
      name when name in ~w(Number Reference) ->
        [child |> Inline.text() |> LatSegments.aside()]

      name when name in ~w(OrderedList UnorderedList) ->
        child |> list_blocks(:leaf) |> Enum.filter(&is_list/1)

      "Tabular" ->
        child |> elements_named("table") |> Enum.map(&table_text/1)

      name when name in ~w(CommentaryRef FootnoteRef Commentaries Footnotes) ->
        []

      _ ->
        quoted_parts(child)
    end
  end

  # An (XHTML) table's cells: " | " between cells, "; " between rows.
  # Elements may be prefixed (xhtml:tr): matched by local name. A cell's
  # block content (paragraphs, lists) reads as text blocks.
  defp table_text(table) do
    table
    |> elements_named("tr")
    |> Enum.map(fn tr ->
      tr
      |> elem(8)
      |> Enum.filter(&(elem(&1, 0) == :xmlElement and Xml.local_name(elem(&1, 1)) in ~w(td th)))
      |> Enum.map(&cell_text/1)
      # empty cells keep their place
      |> Enum.intersperse(LatSegments.mark(" | "))
      |> Enum.concat()
    end)
    |> Enum.reject(&(&1 |> LatSegments.plain() |> String.replace(~r/[\s|]/u, "") == ""))
    |> LatSegments.join("; ")
  end

  # a cell reads as leaf text, its provisions numbered (`numbered/1`)
  defp cell_text(cell) do
    segments = cell |> text_blocks(:cell) |> join_blocks()
    if LatSegments.blank?(segments), do: Inline.text(cell), else: segments
  end

  # Descendant elements with a local name, in document order.
  defp elements_named(element, local) do
    element
    |> elem(8)
    |> Enum.flat_map(fn
      child when elem(child, 0) == :xmlElement ->
        if Xml.local_name(elem(child, 1)) == local,
          do: [child],
          else: elements_named(child, local)

      _ ->
        []
    end)
  end

  # A list's items as text blocks, each led by its number: NumberOverride,
  # else counted from an OrderedList's Type and Decoration ("(a)", "(i)").
  # An item that is a row of its own (`Items`, #184) is a :gap here.
  defp list_blocks(list, mode, items \\ %{}) do
    list
    |> elem(8)
    |> Enum.filter(&(elem(&1, 0) == :xmlElement and Xml.local_name(elem(&1, 1)) == "ListItem"))
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {item, i} ->
      if mode == :structural and Map.has_key?(items, Items.key(item)),
        do: [:gap],
        else: item_blocks(item, list, i, mode, items)
    end)
  end

  defp item_blocks(item, list, i, mode, items) do
    case {item_label(item, list, i), text_blocks(item, mode, items)} do
      {nil, blocks} ->
        blocks

      {label, [first | rest]} when is_list(first) ->
        [LatSegments.mark(label <> " ") ++ first | rest]

      {label, blocks} ->
        [LatSegments.mark(label) | blocks]
    end
  end

  defp item_label(item, list, i) do
    decoration = Xml.attr(list, :Decoration)

    case Xml.attr(item, :NumberOverride) do
      "" ->
        # number only what the source numbers: an OrderedList with a Type
        type = Xml.attr(list, :Type)

        if elem(list, 1) == :OrderedList and type != "",
          do: decorate(Items.list_number(i, type), decoration)

      override ->
        decorate(override, decoration)
    end
  end

  defp decorate(n, "none"), do: n
  defp decorate(n, "period"), do: n <> "."
  defp decorate(n, "parenRight"), do: n <> ")"
  defp decorate(n, "brackets"), do: "[" <> n <> "]"
  defp decorate(n, _parens), do: "(" <> n <> ")"

  # A signature: name, job title, address lines, date (its text, else @Date),
  # as segments, so a change around them (a retained repeal) keeps its
  # territory.
  defp signee_text(signee) do
    parts =
      for path <- [
            ~x"./PersonName"l,
            ~x"./JobTitle"l,
            ~x"./Department"l,
            ~x"./Address/AddressLine"l
          ],
          el <- xpath(signee, path),
          do: Inline.text(el)

    date =
      case xpath(signee, ~x"./DateSigned"o) do
        nil ->
          []

        d ->
          case Inline.text(d) do
            # from the attribute: added by the parser, not the row's own words
            [] -> d |> xpath(~x"./@Date"s) |> LatSegments.mark()
            segments -> segments
          end
      end

    (parts ++ [date])
    |> Enum.map(fn part ->
      part
      |> LatSegments.trim()
      |> LatSegments.update_last_text(&String.trim_trailing(&1, ","))
      |> LatSegments.trim()
    end)
    |> Enum.reject(&LatSegments.blank?/1)
    |> join_signee()
  end

  # ", " between parts — except after "… of the" (a job title running into
  # its department: "A senior officer of the Department of …")
  defp join_signee([]), do: []

  defp join_signee([first | rest]) do
    Enum.reduce(rest, first, fn part, acc ->
      sep =
        if Regex.match?(~r/\b(of|the|for|and)\z/i, LatSegments.plain(acc)), do: " ", else: ", "

      acc ++ LatSegments.mark(sep) ++ part
    end)
  end

  # A provision's blocks led by its number, as a list item's ("(a) England;";
  # 2020/1265 table.111; LR-05)
  defp numbered(provision) do
    case {quoted_number(Ids.pnumber(provision) || "", elem(provision, 1)),
          text_blocks(provision, :cell)} do
      {"", blocks} ->
        blocks

      {label, [first | rest] = blocks} when is_list(first) ->
        # the text may already lead with its number ("1. Part A
        # installations."; 2000/17 sch.6 table.940)
        if String.starts_with?(String.trim_leading(LatSegments.plain(first)), label),
          do: blocks,
          else: [LatSegments.mark(label <> " ") ++ first | rest]

      {label, blocks} ->
        [LatSegments.mark(label) | blocks]
    end
  end

  defp quoted_number("", _parent), do: ""
  defp quoted_number(n, :P1), do: n <> "."
  defp quoted_number(n, _parent), do: "(" <> n <> ")"

  @doc """
  A node's text blocks in document order: each Text's inline text, and in
  :structural mode a :gap where a child provision (its own row) sits.
  :cell is :leaf inside a table cell, where provisions keep their numbers.
  :structural skips other laws' text (amendment blocks); :leaf keeps it,
  as leaf rows always have.
  """
  @spec text_blocks(tuple(), :leaf | :structural | :cell, %{Items.key() => Items.item()}) :: [
          LatSegments.t() | :gap | {:append, LatSegments.t()}
        ]
  def text_blocks(node, mode, items \\ %{}) do
    # the state: after an open child (its content is the child's), and the
    # node's own lead-in so far (`lead_in_before_children_open?/1`: the
    # blocks before its first child row)
    {blocks, _} =
      node
      |> Xml.children()
      |> Enum.flat_map_reduce({false, []}, fn child, {after_open_child?, lead} ->
        {out, after?} = block(child, mode, after_open_child?, lead, items)
        {out, {after?, freeze(lead, out)}}
      end)

    blocks
  end

  # the lead-in blocks until the first child row, then whether they were open
  defp freeze(open?, _out) when is_boolean(open?), do: open?
  defp freeze(blocks, out), do: if(:gap in out, do: open_block?(blocks), else: blocks ++ out)

  defp parent_open?(open?) when is_boolean(open?), do: open?
  defp parent_open?(blocks), do: open_block?(blocks)

  defp block(child, mode, after_open_child?, lead, items) do
    name = Xml.element_name(child)

    cond do
      name in Xml.no_text_elements() ->
        {[], after_open_child?}

      # tables and figures are rows of their own, in either mode
      name in ~w(Tabular Figure) and mode in [:leaf, :cell] ->
        {[], after_open_child?}

      mode == :structural and name in Xml.quoted_elements() and after_open_child? ->
        {[], true}

      # text appended to the amended provision (the quote's closing ".")
      name == "AppendText" ->
        {[{:append, Inline.text(child)}], after_open_child?}

      name in Xml.quoted_elements() ->
        {[quoted_text(child)], after_open_child?}

      Xml.local_name(name) == "table" ->
        {[table_text(child)], after_open_child?}

      name == "Signee" ->
        {[signee_text(child)], after_open_child?}

      mode == :structural and name in Xml.row_elements() ->
        # content after an open child provision is the child's (#174)
        {[:gap], takes_trailing?(child, parent_open?(lead))}

      mode == :structural and name in Xml.skip_elements() ->
        {[], after_open_child?}

      mode == :structural and after_open_child? ->
        {[], true}

      # a table cell's provisions are no rows: they keep their numbers
      mode == :cell and name in ~w(P1 P2 P3 P4) ->
        {numbered(child), after_open_child?}

      name == "Text" ->
        {[Inline.text(child)], after_open_child?}

      # after the open-child skip above: a list following an open child is its (#174)
      name in ~w(OrderedList UnorderedList) ->
        {list_blocks(child, mode, items), after_open_child?}

      # a change wrapping whole blocks (<Repeal RetainText><Text>…</Text></Repeal>):
      # each of its blocks is the changed words
      Inline.block_change(child) != nil ->
        change = Inline.block_change(child)

        {child |> text_blocks(mode, items) |> Enum.map(&Inline.changed_block(&1, change)),
         after_open_child?}

      true ->
        {text_blocks(child, mode, items), after_open_child?}
    end
  end

  @doc """
  Append the sibling content an open provision took (#174): after " … "
  when the provision has its own child provisions in between.
  """
  @spec with_trailing(LatSegments.t(), [tuple()], tuple()) :: LatSegments.t()
  def with_trailing(segments, [], _node), do: segments

  def with_trailing(segments, trailing, node) do
    trailing_segments =
      trailing
      |> Enum.flat_map(fn el ->
        cond do
          Xml.element_name(el) == "Text" -> [Inline.text(el)]
          Xml.element_name(el) == "AppendText" -> [{:append, Inline.text(el)}]
          Xml.element_name(el) in Xml.quoted_elements() -> [quoted_text(el)]
          true -> text_blocks(el, :leaf)
        end
      end)
      |> join_blocks()

    separator = if child_provisions?(node), do: " … ", else: " "
    LatSegments.join([segments, trailing_segments], separator)
  end

  @doc """
  Join blocks with spaces; a gap between text becomes " … " (the child
  provisions sit there); leading/trailing gaps are dropped.
  """
  @spec join_blocks([LatSegments.t() | :gap | {:append, LatSegments.t()}]) :: LatSegments.t()
  def join_blocks(blocks) do
    blocks
    |> attach_appends()
    |> Enum.reject(&(is_list(&1) and LatSegments.blank?(&1)))
    |> Enum.chunk_by(&(&1 == :gap))
    |> Enum.map(fn
      [:gap | _] -> :gap
      parts -> LatSegments.join(parts, " ")
    end)
    |> Enum.drop_while(&(&1 == :gap))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == :gap))
    |> Enum.reverse()
    |> Enum.map(fn
      :gap -> LatSegments.mark("…")
      segments -> segments
    end)
    |> LatSegments.join(" ")
    |> LatSegments.trim()
  end

  # AppendText joins the block before it, after its closing "»".
  defp attach_appends(blocks) do
    blocks
    |> Enum.reduce([], fn
      {:append, appended}, [prev | rest] when is_list(prev) ->
        [LatSegments.append_after_quote(prev, appended) | rest]

      {:append, appended}, acc ->
        [appended | acc]

      block, acc ->
        [block | acc]
    end)
    |> Enum.reverse()
  end

  defp child_provisions?(node) do
    Xml.descendant?(node, [:P1, :P2, :P3, :P4, :Pblock])
  end

  @doc """
  A row's text without descending into child provision elements (Part,
  Chapter, Schedule, P1, P2, P3 holding rows of their own): its Title and
  its own text. Falls back to the leaf text when it has no child provisions.
  """
  @spec structural(tuple(), %{Items.key() => Items.item()}) :: LatSegments.t()
  def structural(node, items \\ %{}) do
    if child_provisions?(node) or item_rows?(node, items) do
      # Title/Number text for the structural header (if any)
      title = Ids.title(node)

      # The node's own text in document order, stopping at child provisions
      # (their own rows): a chapeau, then " … " and any continuation text
      # after them.
      direct = node |> text_blocks(:structural, items) |> join_blocks()
      LatSegments.join([LatSegments.text(title), direct], " ")
    else
      # No child provisions — keep full text (leaf node)
      leaf(node)
    end
  end

  # list items inside the node that are rows of their own (#184)
  defp item_rows?(_node, items) when map_size(items) == 0, do: false

  defp item_rows?(node, items),
    do: node |> Xml.descendants_xmerl(:ListItem) |> Enum.any?(&Map.has_key?(items, Items.key(&1)))
end
