defmodule SertantaiLegal.Scraper.LawStart.NestedItems do
  @moduledoc """
  The rows nested under a commencement list item that ends on a dash, read
  as that item's own: the rows belong to the item that opens them.

  - A provision opened for its parts ("in regulation 14— (i) paragraph (1)
    in so far as it relates to paragraphs (2) to (5); (ii) paragraphs (2)
    to (5)": SI 2013/1675 reg.1(2)(b)): each row names that provision's
    paragraphs, in full or, with a qualifier of its own, partly; words in
    one ("in subsection (3), the words “or (2)”": asc 2021/1 s.175(2)(d))
    leave that paragraph partly in.
  - A Schedule opened for its parts ("in Schedule 11— (i) Part 2; (ii) in
    paragraph 7(3)(a), the words …; (iii) paragraph 7(3)(c)": asc 2021/1
    s.175(2)(l)): the paragraphs and Parts named are that Schedule's.
  - An exception opened ("section 159, other than— (i) subsection (4)(b)
    and (c); (ii) in table 2 in subsection (5), the entry relating to …":
    asc 2021/1 s.175(1)(g)): the rows are what the item excepts; a
    subsection excepted for an entry or words in it only is partly in.
  - A qualifier opened ("subsection (1) of section 170, so far as relating
    to the following—": 1988 c.33 s.171(5)): the rows are the qualifier's
    matter and name nothing brought into force; the item is partly in.

  Any other dash-ended item keeps its rows as flat items (a relative
  clause's own rows: the Agriculture Act 2020 s.57(1)(b)). Pure text.
  """

  alias SertantaiLegal.Scraper.LawStart.ListItems

  @type row :: %{required(:section_id) => String.t(), optional(any()) => any()}

  @dash ~r/[—–]\s*$/u
  @provision "(regulation|section|article|rule)\\s+(\\d+[A-Z]*)"
  @container Regex.compile!("^\\W*in\\s+#{@provision}\\s*[—–]\\s*$", "iu")
  @schedule ~r/^\W*in\s+(Schedule\s+\d+[A-Z]*)\s*[—–]\s*$/iu
  # a Schedule's paragraphs or Parts a row names first, and the paragraph a
  # row names words in
  @schedule_parts ~r/^\W*((?:paragraphs?|Parts?)\s+\d[^;.]*?)[\s;.,]*$/isu
  @in_paragraph ~r/^\W*in\s+(paragraph\s+\d+[A-Z]*(?:\(\w+\))*)\s*,/iu
  # quoted words are words, never provisions (a quotation may hold one)
  @quoted ~r/“.*”/su
  @exception ~r/^(.+?),?\s*(?:other\s+than|except(?:\s+for)?|apart\s+from|with\s+the\s+exception\s+of)\s*[—–]\s*$/isu
  @qualifier ~r/\b(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\s+(?:(?:it|they)\s+)?(?:relates?|relating|appl(?:y|ies|ying))(?:\s+to)?(?:\s+the\s+following)?\s*[—–]\s*$/iu
  @single Regex.compile!("^\\W*#{@provision}\\s*$", "iu")
  # the provision's paragraphs a row names first: "paragraph (1) …",
  # "paragraphs (2) to (5)", "paragraph 3(b) and (c)" (so written),
  # "subsection (4)(b) and (c)"
  @parts ~r/^\W*(?:sub-?sections?|paragraphs?)\s+((?:\(\w+\)|\d+[A-Z]*(?=\())(?:\(\w+\))*(?:\s*(?:,|and|to)\s*(?:\(\w+\))+)*)(.*)$/isu
  # an entry or words within one: "in table 2 in subsection (5), the entry …"
  @within ~r/\bin\s+(?:sub-?section|paragraph)\s+((?:\(\w+\))+)\s*,/iu
  @limit ~r/\b(?:so\s+far\s+as|insofar\s+as|to\s+the\s+extent|for\s+the\s+purposes?\s+of|in\s+relation\s+to)\b/i

  @doc """
  The rows under a list's statement as `{the flat items' words, the items
  read from a dash-ended item and its nested rows}`.
  """
  @spec fold([row()]) :: {[String.t()], [ListItems.item()]}
  def fold(rows) do
    openers = for row <- rows, read = opened(row, rows), read != nil, do: {row.section_id, read}
    outer = Enum.reject(openers, fn {id, _} -> Enum.any?(openers, &under?(id, elem(&1, 0))) end)
    taken? = fn row -> Enum.any?(outer, &covered?(row.section_id, elem(&1, 0))) end

    {for(row <- rows, not taken?.(row), do: text(row)), Enum.flat_map(outer, &elem(&1, 1))}
  end

  defp opened(row, rows) do
    nested = for r <- rows, under?(r.section_id, row.section_id), do: text(r)
    if nested != [] and text(row) =~ @dash, do: read(text(row), nested)
  end

  defp text(row), do: Map.get(row, :text) || ""
  defp under?(id, opener), do: String.starts_with?(id, opener <> "(")
  defp covered?(id, opener), do: id == opener or under?(id, opener)

  @doc """
  A dash-ended item with the words of its nested rows, as list items; nil
  where the item opens none of the forms read.
  """
  @spec read(String.t(), [String.t()]) :: [ListItems.item()] | nil
  def read(opener, nested) do
    cond do
      found = Regex.run(@container, opener) ->
        Enum.map(nested, &part_of(&1, own(found)))

      found = Regex.run(@schedule, opener) ->
        Enum.map(nested, &schedule_part(&1, Enum.at(found, 1)))

      found = Regex.run(@exception, opener) ->
        [excepting(Enum.at(found, 1), nested)]

      opener =~ @qualifier ->
        [opener |> String.replace(@dash, "") |> ListItems.read()]

      true ->
        nil
    end
  end

  defp own([_, noun, number]), do: "#{String.downcase(noun)} #{number}"

  # a row of an opened provision: its paragraphs, written out in full
  # ("regulation 14(2) to (5)"); partly in with a qualifier of its own, as
  # is the provision where the row names no paragraph of it
  defp part_of(row, own) do
    case Regex.run(@parts, unquoted(row)) do
      [_, parts, rest] -> part_item(in_full(own, parts), rest =~ @limit)
      nil -> item("", "", own <> within(row))
    end
  end

  # the paragraph a row names words in ("in subsection (3), the words …"),
  # written after the provision; none where the row names none
  defp within(row) do
    case Regex.run(@within, unquoted(row)) do
      [_, parts] -> parts
      nil -> ""
    end
  end

  # a row of an opened Schedule: its paragraphs or Parts as the Schedule's
  # ("Part 2 of Schedule 11"); the paragraph it names words in is partly
  # in, as is the Schedule where the row names no paragraph of it
  defp schedule_part(row, schedule) do
    row = unquoted(row)

    case {Regex.run(@schedule_parts, row), Regex.run(@in_paragraph, row)} do
      {[_, parts], _} -> part_item("#{named(parts)} of #{schedule}", parts =~ @limit)
      {nil, [_, paragraph]} -> item("", "", "#{paragraph} of #{schedule}")
      {nil, nil} -> item("", "", schedule)
    end
  end

  # the paragraphs named before a row's own qualifier ("paragraphs 11 and
  # 22(3) to the extent that they relate to …": SI 2007/2709 reg.3(c)(ii))
  defp named(parts), do: @limit |> Regex.split(parts, parts: 2) |> hd() |> String.trim()

  defp unquoted(row), do: Regex.replace(@quoted, row, "“”")

  defp part_item(ref, true), do: item("", "", ref)
  defp part_item(ref, false), do: item(ref, "", "")

  # each paragraph named, written out as the provision's: "(4)(b) and (c)"
  # of section 159 is "section 159(4)(b) and section 159(4)(c)", the later
  # one a sibling of the level it matches; a range stays one ("(2) to (5)")
  defp in_full(own, parts) do
    parts
    |> bracketed()
    |> String.split(~r/\s*(?:,|\band\b)\s*/, trim: true)
    |> Enum.map_reduce([], &sibling/2)
    |> elem(0)
    |> Enum.map_join(" and ", &(own <> &1))
  end

  defp sibling(piece, before) do
    [first | range] = String.split(piece, ~r/\s+to\s+/, parts: 2)
    levels = ~r/\(\w+\)/ |> Regex.scan(first) |> List.flatten()
    full = Enum.take(before, level(before, hd(levels))) ++ levels

    {Enum.join([Enum.join(full) | range], " to "), full}
  end

  # where a paragraph sits under the one named before it: at the level of
  # its own kind (a number, a letter), else on its own
  defp level(before, mark),
    do: Enum.find_index(before, &(number?(&1) == number?(mark))) || 0

  defp number?(mark), do: mark =~ ~r/^\(\d/

  defp bracketed(parts), do: Regex.replace(~r/^(\d+[A-Z]*)(?=\()/, parts, "(\\1)")

  defp excepting(head, nested) do
    own = Regex.run(@single, head)
    read = Enum.map(nested, &excepted(&1, own))
    partly = for {:partly, ref} <- read, do: ref
    out = for {:out, ref} <- read, do: ref

    item(head, Enum.join(out ++ partly, " and "), Enum.join(partly, " and "))
  end

  # what a row of an exception takes out: the item's own subsections
  # wholly, a subsection for an entry in it only partly; words that name
  # no provision ("in that table, …") take nothing more out
  defp excepted(row, nil), do: {:out, row}

  defp excepted(row, own) do
    case {Regex.run(@parts, row), Regex.run(@within, row)} do
      {[_, parts, rest], _} -> {out_or_partly(rest), in_full(own(own), parts)}
      {nil, [_, parts]} -> {:partly, own(own) <> parts}
      {nil, nil} -> {:none, row}
    end
  end

  defp out_or_partly(rest), do: if(rest =~ @limit, do: :partly, else: :out)

  defp item(plain, excepted, qualified),
    do: %{plain: plain, excepted: excepted, qualified: qualified}
end
