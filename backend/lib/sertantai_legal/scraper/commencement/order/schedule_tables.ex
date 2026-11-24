defmodule SertantaiLegal.Scraper.Commencement.Order.ScheduleTables do
  @moduledoc """
  A commencement order's Schedule tables: their rows, provision and purpose
  columns, and each row's territory.

  Pure; part of the order reader (`Commencement.Order`).
  """

  import SweetXml

  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}

  alias SertantaiLegal.Scraper.Commencement.Order.{
    Dates,
    Items,
    OtherLaw,
    Purposes,
    RepealLists,
    ScheduleDate,
    ScheduleLists,
    Territory,
    Words
  }

  alias SertantaiLegal.Scraper.Commencement.Rule

  # the words a provision is amended by, quoted, are never refs ("in section
  # 33(1) of the 1990 Act the words “… section 54 …”": SSI 2015/73); an item
  # ending in another law's name is that law's ("paragraph 17(4) of Schedule
  # 9, and paragraph 3(1) and (2) of Schedule 11, to the Local Government
  # (Wales) Act 1994": SI 1996/186) — CV-S04 round 4
  # a table row naming only a Part by its title in brackets: "Part I (Waste
  # on Land)"; a bare "Part II" is an item (SI 1991/2187 "Part II", "Part III")
  @part_heading ~r/^\s*Part\s+(?:[IVXL]+|\d+)[A-Z]?\s*\([^()]*\s[^()]*\)\s*$/

  # ── Schedule tables ──────────────────────────

  # a Schedule dated by its title (or its article), or each of its Parts by
  # its own ("PART II PROVISIONS COMING INTO FORCE ON 15th DECEMBER 1999":
  # SI 1999/2830, AR-12) — never both
  @doc "The rules of an order's Schedule tables."
  @spec tables(Doc.t(), Order.act()) :: [Rule.t()]
  def tables(order, _act) do
    for id <- order.ids,
        String.match?(id, ~r/^schedule(-\d+[A-Z]*)?(?:-part-[IVXL\d]+[A-Z]?)?$/),
        not dated_parts?(order, id),
        el = Doc.element(order, id),
        date = ScheduleDate.schedule_date(order, el),
        date != nil,
        {place, limit} =
          {ScheduleLists.schedule_territory(order, el), ScheduleLists.schedule_limit(order, el)},
        {row, purpose, sch, shown} <- table_entries(order, el),
        text <-
          if(row =~ Words.schedule_entries(),
            do: [row],
            else:
              row
              |> drop_completing()
              |> OtherLaw.drop_other_laws(["the act"])
              |> provision_segments()
          ),
        item <- elem(Items.items(text, ["the act"], sch), 0),
        {refs, purposes, territory, except} = Items.parts(item),
        refs != [],
        do:
          Rule.new(
            commences: :pending,
            scope: refs,
            except: except,
            when: {:date, date},
            territory: territory || column_territory(purpose) || place,
            purposes: table_purposes(purpose, purposes) || limit,
            source: %{
              law: order.law_name,
              ref: Words.source_ref(id),
              text: Words.squash(shown)
            },
            treatment: :order_schedule
          )
  end

  # a completing qualifier in a row brings its items in fully, so it is no
  # qualifier: dropped, the items after it stay the provision's ("Article
  # 4(1)(a) and (b) and (5) and to the extent that they are not already in
  # force (2) to (4) and (6) to (9)": NISR 2003/489 Sch. had dropped them)
  defp drop_completing(row) do
    row
    |> String.replace(Words.full(), " ")
    |> String.replace(~r/\(\s*\)/, " ")
    |> String.replace(~r/\s+(?=[,;)])|(?<=\()\s+/, "")
    |> String.replace(~r/\s{2,}/, " ")
    |> String.trim()
  end

  # a table cell's provisions, each with its own qualifier: "Section 11(4)
  # and (5) and Section 11(6) (so far as aforesaid)" → "Section 11(4) and
  # (5)" fully, "Section 11(6) (so far as aforesaid)" partly (SI 1974/1439,
  # CV-S04 round 3); split only outside brackets, before a provision noun
  defp provision_segments(text) do
    cuts =
      for [{at, len}] <-
            Regex.scan(
              ~r/,?\s+and\s+(?=(?:sub-?)?(?:[Ss]ections?|[Ss]chedules?|[Pp]aragraphs?|[Pp]arts?)\b)/u,
              text,
              return: :index
            ),
          depth(binary_part(text, 0, at)) == 0,
          do: {at, len}

    {segments, rest} =
      Enum.reduce(Enum.reverse(cuts), {[], text}, fn {at, len}, {acc, t} ->
        {[binary_part(t, at + len, byte_size(t) - at - len) | acc], binary_part(t, 0, at)}
      end)

    [rest | segments] |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
  end

  @doc "The brackets still open at the text's end."
  @spec depth(String.t()) :: integer()
  def depth(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0, fn
      "(", d -> d + 1
      ")", d -> max(d - 1, 0)
      _, d -> d
    end)
  end

  # each row read, with the words it is shown by (the row as the table has it)
  defp table_entries(order, el) do
    column? = provision_column?(el)

    for {text, cell, _} = entry <- with_schedules(table_rows(el), table_schedule(order, el)),
        {row, purpose, sch} <- if(column?, do: schedule_provisions(entry), else: [entry]),
        do: {row, purpose, sch, "#{text} | #{cell}"}
  end

  # a table headed "Schedule | Provision": the second cell lists the
  # paragraphs of the Schedule the first names, and only those come in (SI
  # 2004/641 Sch.2 "Schedule 8 | In paragraph 1, sub-paragraph (4), …
  # Paragraphs 19, 23, 43, 44 and 48 …" had brought all of Schedule 8 in)
  defp provision_column?(el) do
    case el |> xpath(~x".//*[local-name()='th']"l) |> Enum.map(&String.trim(Doc.text(&1))) do
      [first, second | _] -> first =~ ~r/^Schedules?$/i and second =~ ~r/^Provisions?$/i
      _ -> false
    end
  end

  # (each sentence of the cell its own item: a qualifier ends at its full stop)
  defp schedule_provisions({row, cell, sch} = entry) do
    if row =~ ~r/^\s*Schedule\s+\d+[A-Z]*\s*$/i and is_binary(cell) and cell != "",
      do: for(sentence <- in_paragraphs(cell), do: {sentence, "", sch}),
      else: [entry]
  end

  # "In paragraph 27, sub-paragraphs (5)(a)(ii), (iii) and (v), (5)(b)(ii)
  # and (7)(a), and sub-paragraph (1) in so far as …": each item opening on
  # a number is that paragraph's ("Paragraph 27(5)(a)(ii), …, paragraph
  # 27(7)(a)"), a qualifier's words left as they are ("in so far as it
  # relates to sub-paragraphs (3) and (4)(b)")
  @in_paragraph ~r/^In\s+paragraph\s+(\d+[A-Z]*),\s+(.*)$/is

  @sub_item ~r/(^|,\s+|\band\s+)(?:sub-?paragraphs?\s+)?\((\d+[A-Z]*)\)/i

  @qualifier ~r/\b(?=(?:in\s+)?so\s+far\s+as\b|insofar\b)/i

  defp in_paragraphs(cell) do
    cell
    |> String.split(~r/(?<=\.)\s+(?=[A-Z])/)
    |> Enum.map(fn sentence ->
      case Regex.run(@in_paragraph, sentence) do
        [_, n, rest] ->
          rest
          |> String.split(~r/,\s+and\s+/)
          |> Enum.map_join(", and ", &in_clause(&1, n))
          |> capitalize_first()

        nil ->
          sentence
      end
    end)
  end

  defp in_clause(clause, n) do
    [items | qualifier] = String.split(clause, @qualifier, parts: 2)
    Regex.replace(@sub_item, items, "\\1paragraph #{n}(\\2)") <> Enum.join(qualifier)
  end

  @doc "The text with its first letter upper case."
  @spec capitalize_first(String.t()) :: String.t()
  def capitalize_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  def capitalize_first(text), do: text

  # each row with the Schedule an earlier row names: "Schedule 6" then
  # "paragraph 5 | For all purposes" is Schedule 6's paragraph 5 (SI
  # 2000/2974, CV-S04); a section's row ends it
  defp with_schedules(rows, first) do
    rows
    |> Enum.map_reduce(first, fn {text, purpose}, sch ->
      sch = row_schedule(text, sch)
      {{text, purpose, sch}, sch}
    end)
    |> elem(0)
  end

  # the Schedule a row names, else the one before it; a section's row ends it
  defp row_schedule(text, sch) do
    case Regex.run(~r/^\s*Schedule\s+(\d+[A-Z]*)\b/i, text) do
      [_, n] -> n
      nil -> if text =~ ~r/^\s*(?:sections?|in\s+section)\b/i, do: nil, else: sch
    end
  end

  # the Act's Schedule a table lists the paragraphs of: its title's
  # ("EXTENT OF COMMENCEMENT OF SCHEDULE 7": SI 1991/2905), else the
  # article bringing it in ("… Schedule 7 to the Act specified in …")
  defp table_schedule(order, el) do
    title = el |> xpath(~x"./TitleBlock/Title | ./Title"l) |> Enum.map_join(" ", &Doc.text/1)

    words =
      with ref when ref != nil <- xpath(el, ~x"./Reference"),
           [_, n] <- Regex.run(~r/(?:Article|Regulation) (\d+)/i, Doc.text(ref)) do
        Text.words_of(order, "article-#{n}") <> " " <> Text.words_of(order, "regulation-#{n}")
      else
        _ -> ""
      end

    with nil <- capture(~r/\bSchedule\s+(\d+[A-Z]*)\b(?!\s+to\s+th(?:is|ese)\b)/i, title),
         nil <- capture(~r/\bSchedule\s+(\d+[A-Z]*)\s+to\s+the\b/i, words) do
      nil
    end
  end

  defp capture(re, text) do
    case Regex.run(re, text) do
      [_, n] -> n
      nil -> nil
    end
  end

  # Parts dated in their titles, each read alone; an Appendix Part with no
  # table of provisions — a list, or a repeals table of other Acts
  # (Chapter | Short Title | Extent of repeal) — leaves the Schedule's own
  # table to it (SI 1977/1365)
  defp dated_parts?(order, id) do
    not String.contains?(id, "-part-") and
      Enum.any?(order.ids, fn part ->
        String.match?(part, ~r/^#{Regex.escape(id)}-part-[IVXL\d]+[A-Z]?$/) and
          part_date(order, part) != nil and
          order |> Doc.element(part) |> table_rows() |> Enum.any?(&provision_row?/1)
      end)
  end

  defp provision_row?({first, _}),
    do:
      first =~
        ~r/^\W*(?:sub-?)?(?:sections?|schedules?|parts?|paragraphs?|in\s+(?:section|schedule))\b/i

  defp part_date(order, id) do
    order
    |> Doc.element(id)
    |> xpath(~x"./TitleBlock/Title | ./Title"l)
    |> Enum.map_join(" ", &Doc.text/1)
    |> Dates.parse_dates()
    |> case do
      [d] -> d
      _ -> nil
    end
  end

  @purpose_opening ~r/^\W*(?:(?:in\s+)?so\s+far|insofar|to\s+the\s+extent|for\s+(?:the\s+)?(?:purposes?|specified|certain)|except|only|in\s+relation\s+to|as\s+respects)\b/i

  # a table's second column, where it is a purpose ("In relation to Wales"),
  # never where it is the provision's subject
  defp column_territory(purpose) when is_binary(purpose),
    do: if(purpose =~ @purpose_opening, do: Territory.of(purpose))

  defp column_territory(_purpose), do: nil

  defp table_purposes(purpose, from_text) do
    cond do
      purpose in [nil, ""] or purpose =~ ~r/^for all (?:remaining |other )?purposes\.?$/i ->
        from_text

      # a completing purpose ("In so far as not already in force.": SSI
      # 2016/42) brings the row in fully
      Regex.match?(Words.full(), purpose) and
          not Regex.match?(Words.partial(), String.replace(purpose, Words.full(), "")) ->
        from_text

      # the table's second column is mostly its subject ("Minor and
      # consequential amendments"): a purpose only when it opens with one
      # — never a subject naming purposes ("Definition of “county” for the
      # purposes of the … Act 1986": SI 1995/2490)
      Regex.match?(Words.partial(), purpose) and Regex.match?(@purpose_opening, purpose) ->
        from_text || Purposes.purposes(purpose)

      true ->
        from_text
    end
  end

  @doc "A Schedule table's rows as cells, without completing entries and repealed Acts by chapter."
  @spec table_rows(term()) :: [[String.t()]]
  def table_rows(el) do
    column = purpose_column(el)

    el
    |> xpath(~x".//*[local-name()='tbody']/*[local-name()='tr']"l)
    |> Enum.map(fn tr -> tr |> xpath(~x"./*[local-name()='td']"l) |> Enum.map(&Doc.text/1) end)
    |> Enum.map(&with_purpose(&1, column))
    |> RepealLists.drop_table_entries()
    # a repealed Act by its chapter ("1894 c. 60.": an Appendix of repeals,
    # SI 1995/965) is no provision of the Act's
    |> Enum.reject(fn cells ->
      List.first(cells, "") =~ ~r/^[\w&.,\s]{0,40}\bc\.\s*\d+\s*\.?\s*$/
    end)
    |> Enum.reduce({[], nil}, fn
      [first | rest], {acc, parent} ->
        purpose = List.first(rest)

        cond do
          purpose in [nil, ""] ->
            {flush(acc, parent), {first, false}}

          parent && first =~ ~r/^(sub)?(sections?|paragraphs?)\b/ ->
            {text, _} = parent
            {[{"#{text} #{first}", purpose} | acc], {text, true}}

          true ->
            {[{first, purpose} | flush(acc, parent)], nil}
        end

      _, acc ->
        acc
    end)
    |> then(fn {acc, parent} -> flush_last(acc, parent) end)
    |> Enum.reverse()
  end

  # a later column its header names "Purpose" ("Column 1 Provisions of the
  # Act | Column 2 Subject matter | Column 3 Purpose": SSI 2013/163 art.3(2)
  # — "Where a purpose is specified in column 3 …, only for that purpose")
  # — counted within its own header row, under a "Column 1 | Column 2 |
  # Column 3" row (SSI 2005/351 Sch.1)
  defp purpose_column(el) do
    el
    |> xpath(
      ~x".//*[local-name()='thead']/*[local-name()='tr'] | .//*[local-name()='tr'][*[local-name()='th']]"l
    )
    |> Enum.find_value(fn tr ->
      tr
      |> xpath(~x"./*[local-name()='th']"l)
      |> Enum.map(&Doc.text/1)
      |> Enum.find_index(&(&1 =~ ~r/\bpurposes?\b/i))
      |> then(&if(&1 != nil and &1 > 1, do: &1))
    end)
  end

  # the row's purpose in place of its subject, where the purpose column holds one
  defp with_purpose(cells, nil), do: cells

  defp with_purpose([first, _subject | _] = cells, column) do
    case cells |> Enum.at(column, "") |> String.trim() do
      "" -> cells
      purpose -> [first, String.replace(purpose, ~r/^\W*(?=the\s+purposes?\s+of\b)/i, "for ")]
    end
  end

  defp with_purpose(cells, _column), do: cells

  # a row with no subject is a heading for the rows under it ("Section 44" over
  # "paragraph 3 …"); with none under it, it is an item itself (AR-15: SI
  # 1999/2830 "Section 31 and in Schedule 7, …" has no subject cell) — but a
  # Part's name with rows after it groups them, never commences the Part (SI
  # 1988/818 "Part VI (Miscellaneous and General)" over its sections had COPA
  # 1974 s.101 in force)
  defp flush(acc, {text, false}) do
    if text =~ @part_heading, do: acc, else: [{text, ""} | acc]
  end

  defp flush(acc, _parent), do: acc

  defp flush_last(acc, {text, false}), do: [{text, ""} | acc]
  defp flush_last(acc, _parent), do: acc
end
