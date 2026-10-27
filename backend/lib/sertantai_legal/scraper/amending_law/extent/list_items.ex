defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ListItems do
  @moduledoc """
  A list's items read (CV-S05; out of `Extent.Lists` in round 11, from the
  CV-S05c census): the provisions each item names, read plainly; what an
  item excepts from itself ("Part 1, apart from sections 17 and 18",
  "Chapter 3 of Part 1 (with the exception of section 59 …)", "Part 2 …
  but excluding sections 60 and 61"), taken out and kept as excepted; and
  what an item qualifies ("section 154 … so far as they relate to …"),
  withheld (`unread`), never read whole and never dropped to the default.
  Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ItemExceptions, Parts, Units}

  @typedoc "An item list read: the provisions named, excepted and withheld."
  @type reading :: %{refs: [String.t()], excepted: [String.t()], unread: [String.t()]}

  # a qualified aside: with the number it qualifies ("370 (so far as
  # relating to section 374)"), or alone where it adds one ("Schedule 2
  # (and article 26 so far as relating to it)")
  @qualified_aside ~r/(?:\b\d+[A-Z]*(?:\(\w+\))*\s*(?=\(\s*(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b))?\([^()]*\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b[^()]*\)/iu

  # an item led by its qualifier ("b in so far as relating to …, section 52")
  @leading_qualifier ~r/^\s*(?:and\s*)?(?:\(?[a-z]{1,2}\)?\s+)?(?:in\s+so\s+far|so\s+far|insofar|to\s+the\s+extent)\b/iu

  @qualifier_object ~r/\b(?:in\s+)?so\s+far\s+as\s+(?:it\s+|they\s+)?(?:relat(?:es?|ing)|appl(?:ies|y|ying)|ha(?:s|ve)\s+effect)\b[^,;—–]*/iu

  # (never "into the Energy Act 2008": a description, 2009/23 s.323(2), round 12)
  @other_law ~r/\b(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4}/u

  @qualifier ~r/\b(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent)\b/iu

  # an item's lettered label, CLML's flattening running it in ("andc Parts
  # I and IV", "za sections 4A", "z1 Part 9"); never a word ("in Part 6")
  @label ~r/^\s*(?:and\s*)?\(?(?!(?:in|of|to|or|as|by|on|at|an|so|no)\s)(?:z?[a-z]{1,2}\d{0,2}|[ivx]{2,4})\)?\s+(?=\S)/u

  # a locator before the provisions it holds: "in Chapter 1 of Part 6,
  # sections 165, 166 and 186", "in Part 10— i sections 311 and 312" name
  # those sections, never the Chapter or Part
  @locator ~r/^\s*in\s+(?:Chapter\s+[\dIVXLC]+[A-Z]*\s+of\s+)?Part\s+[\dIVXLC]+[A-Z]*(?:\s*\((?:[^()]|\([^()]*\))*\))?\s*(?:,|[—–]\s*(?:[ivx]{1,4}\s+)?)\s*(?=(?:sections?|Chapters?|Schedules?)\s)/iu

  # plain provisions with a qualified companion: "Parts 1 and 2 of
  # Schedule 7 and section 73 so far as relating to those Parts"
  @companion ~r/^(?<plain>.+?)\s+and\s+(?<q>(?:sections?|regulations?|articles?|rules?)\s+[\dA-Z()]+(?:\s+(?:above|below))?)\s*,?\s+(?:so\s+far|in\s+so\s+far|insofar)\s+as\b.*$/iu

  # "section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule
  # 1, and those paragraphs": the paragraphs plainly, the section qualified
  @and_those ~r/^(?<q>.+?),?\s+(?:so\s+far|in\s+so\s+far|insofar)\s+as\s+(?:it\s+|they\s+)?relat\w*\s+to\s+(?<obj>.+?),?\s+and\s+(?:those|that)\s+(?:paragraphs?|provisions?|Parts?|Schedules?|sections?)\s*\.?\s*$/iu

  @doc """
  The items of a list body read: the provisions named (`refs`), those an
  item excepts from itself (`excepted`), and those withheld (`unread`: a
  qualified item's, a qualified companion's, and a provision only some of
  which an exception takes out).
  """
  @spec read(String.t(), String.t() | nil, Doc.t()) :: reading()
  def read(body, clause_ref, doc) do
    {plain, qualified} = qualified_items(body, clause_ref, doc)

    readings =
      plain
      |> Parts.qualify_chapters()
      |> Units.no_dots()
      |> String.split(~r/;|,\s*(?=(?:and\s*)?(?:z?[a-z]\d{0,2}|[ivx]{2,4})\s)/u)
      |> own_items()
      |> Enum.map(&item(&1, clause_ref, doc))

    refs = readings |> Enum.flat_map(& &1.refs) |> Enum.uniq()

    %{
      refs: refs,
      excepted: readings |> Enum.flat_map(& &1.excepted) |> Enum.uniq(),
      unread:
        (qualified ++ Enum.flat_map(readings, & &1.unread)) |> Enum.uniq() |> Kernel.--(refs)
    }
  end

  @doc "The provisions a list body's items name, read plainly (`read/3`'s `refs`)."
  @spec refs(String.t(), String.t() | nil, Doc.t()) :: [String.t()]
  def refs(body, clause_ref, doc), do: read(body, clause_ref, doc).refs

  # one item: its exception taken out, then its qualified parts withheld,
  # then what is left read plainly
  # ("section 113 (together with such of the other provisions of Part 7
  # as relate to …)": the section read, the rest of Part 7 withheld;
  # ukpga 2008/4 s.152, round 12)
  defp item(item, clause_ref, doc) do
    {item, some_of} = together_with_such(item, clause_ref, doc)
    r = item_read(item, clause_ref, doc)
    %{r | unread: r.unread ++ (some_of -- r.refs)}
  end

  defp together_with_such(item, clause_ref, doc) do
    case Regex.run(
           ~r/\s*\(\s*together\s+with\s+such\s+of\s+(?<what>[^()]*?)\s+as\s+relates?\b[^()]*\)/iu,
           item,
           capture: :all
         ) do
      [whole, what] -> {String.replace(item, whole, " "), provisions(what, clause_ref, doc)}
      nil -> {item, []}
    end
  end

  defp item_read(item, clause_ref, doc) do
    item =
      item
      # (an item ends at its sentence's end: never the next sentence's
      # words, "… Schedule 17. So far as Schedule 17 contains …")
      |> String.split(~r/\.\s+(?=[A-Z][a-z])/u, parts: 2)
      |> hd()
      |> String.replace(@label, "")
      |> String.replace(@qualified_aside, " ")
      |> String.replace(@locator, "")
      # ("in section 47, subsection (1)": section 47(1), ukpga 1993/9 s.48)
      |> String.replace(
        ~r/\bin\s+(section|regulation|article)\s+(\d+[A-Z]*)\s*,\s*(?:sub-?section|paragraph)s?\s+(\([a-zA-Z\d]+\))(?!\s*(?:and|,|to)\s*\()/iu,
        "\\1 \\2\\3"
      )
      |> String.replace(
        ~r/\b(section|regulation|article|paragraph)\s+(?=\d+[A-Z]*\s+(?:to|and)\s+\d)/iu,
        "\\1s "
      )

    {main, except_text, at, len} = ItemExceptions.split(item)
    excepted = if except_text, do: provisions(except_text, clause_ref, doc), else: []

    if except_text != nil and excepted == [] do
      # an exception not read ("… except as provided by subsection (2)",
      # "(excluding the reference to paragraph 6)"): the piece it excepts
      # from withheld, the item's other pieces read (1973/32 s.58)
      # (the stretch since the last comma before it; the words after it
      # up to the next comma)
      {hit_before, ok_before} =
        item |> binary_part(0, at) |> String.split(",") |> List.pop_at(-1)

      [hit_after | ok_after] =
        item |> binary_part(at + len, byte_size(item) - at - len) |> String.split(",")

      rest =
        case Enum.reject(ok_before ++ ok_after, &(String.trim(&1) == "")) do
          [] -> %{refs: [], excepted: [], unread: []}
          ps -> item(Enum.join(ps, ","), clause_ref, doc)
        end

      %{rest | unread: rest.unread ++ withheld(hit_before <> " " <> hit_after, clause_ref, doc)}
    else
      main
      |> qualified(clause_ref, doc)
      |> split_excepted(excepted)
    end
  end

  # (an unlettered list with a qualifier: each piece on its own, so only
  # the qualified pieces are withheld, "Part I (…), Part III (…), the
  # provisions of Schedule 8 … so far as relating to …": ukpga 1991/22
  # s.169; 1973/32 s.58, round 11)
  defp qualified(main, clause_ref, doc) do
    case Regex.match?(@qualifier, main) and pieces(main) do
      [_, _ | _] = ps ->
        rs = Enum.map(ps, &qualified_piece(&1, clause_ref, doc))
        %{refs: Enum.flat_map(rs, & &1.refs), unread: Enum.flat_map(rs, & &1.unread)}

      _ ->
        qualified_piece(main, clause_ref, doc)
    end
  end

  defp qualified_piece(main, clause_ref, doc) do
    cond do
      m = Regex.named_captures(@and_those, main) ->
        %{
          refs: provisions(m["obj"], clause_ref, doc),
          unread: provisions(m["q"], clause_ref, doc)
        }

      m = Regex.named_captures(@companion, main) ->
        if Regex.match?(@qualifier, m["plain"]),
          do: %{refs: [], unread: withheld(main, clause_ref, doc)},
          else: %{
            refs: plain(m["plain"], clause_ref, doc),
            unread: provisions(m["q"], clause_ref, doc)
          }

      Regex.match?(@qualifier, main) ->
        %{refs: [], unread: withheld(main, clause_ref, doc)}

      true ->
        %{refs: plain(main, clause_ref, doc), unread: []}
    end
  end

  # a qualified item's own provisions, never what the qualifier names
  defp withheld(text, clause_ref, doc) do
    text = String.replace(text, @qualifier_object, " ")

    if other_law?(text), do: [], else: provisions(text, clause_ref, doc)
  end

  # the provisions named, the excepted taken out, one only some of which
  # is excepted withheld
  defp split_excepted(%{refs: refs, unread: unread}, excepted) do
    {held, partly} = ItemExceptions.apart(refs, excepted)
    %{refs: held, excepted: excepted, unread: unread ++ partly}
  end

  # an item read plainly, piece by piece: never a description of some of
  # a Part or Chapter, "so much of", a subsection "of this section", nor
  # another law's provisions (1977/45 s.65(10): CV-S05 N3; CJA 2009
  # s.181(2)(b))
  defp plain(text, clause_ref, doc) do
    for piece <- pieces(text),
        piece = own_part(piece),
        not Regex.match?(
          ~r/^\s*(?:and\s+)?in\s+(?:section|regulation|article)\s+\S+\s*$/iu,
          piece
        ),
        not other_law?(piece),
        not Regex.match?(
          ~r/\bthe\s+(?:[\w-]+\s+){1,3}provisions\s+of\s+(?:Chapter|Part)\b|\bso\s+much\s+of\b|\bof\s+this\s+section\b/u,
          piece
        ),
        ref <- refs_in(piece, clause_ref, doc),
        uniq: true,
        do: ref
  end

  # a piece without the item after it that names another law's ("sections
  # 50, 51 and 57, paragraphs 41, … of Schedule 4, the entries in Schedule
  # 5 relating to the National Health Service (Scotland) Act 1947, …":
  # 1973/32 s.58, round 11); never "… of, and paragraphs 3 and 19 of
  # Schedule 5 to, the Powers of Criminal Courts Act 1973" (all its own)
  defp own_part(piece) do
    with [{at, _} | _] <- Regex.run(@other_law, piece, return: :index),
         [_, kept] <- Regex.run(~r/^(.*),\s*(?:and\s+)?the\s/su, binary_part(piece, 0, at)) do
      kept
    else
      _ -> piece
    end
  end

  defp other_law?(text), do: Regex.match?(@other_law, text)

  defp provisions(text, clause_ref, doc) do
    for piece <- pieces(text), ref <- refs_in(piece, clause_ref, doc), uniq: true, do: ref
  end

  # an item cut at each provision it names after a comma
  defp pieces(text),
    do:
      String.split(
        text,
        ~r/,\s*(?=(?:and\s+)?(?:sections?|subsections?|Schedules?|in\s+Schedule|Parts?|paragraphs?\s+[^,;]*?\bof\s+Schedule|regulations?|articles?)\b)/u
      )

  defp refs_in(piece, clause_ref, doc),
    do: RefList.parse(piece, clause_ref) ++ Parts.parts(piece, doc, clause_ref)

  # the items, without one qualified by a sub-list of what it relates to
  # and that sub-list ("d in Schedule 9, the amendments relating to— i …;
  # ii the Criminal Justice Act 1961; …": 1975/21 s.463(1)(d), (e), round
  # 7 NEW-2; its sub-items named another Act's sections)
  defp own_items(items) do
    items
    |> Enum.map_reduce(false, fn item, skipping ->
      sub? = item =~ ~r/^\s*(?:and\s*)?[ivx]{1,4}\s/u

      cond do
        item =~ ~r/\brelating\s+to\s*[—–]/u -> {nil, true}
        skipping and sub? -> {nil, true}
        true -> {item, false}
      end
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
  end

  # the items led by a qualifier ("b in so far as relating to
  # sections 26 to 27A of the Fire Services Act 1947, section 52"; "c in so
  # far as relating to— i …, iv the Superannuation Act 1972, section 53(1)
  # and Schedule 1": FRSA 2004 s.63(2), CV-S05 round 9): out of the list,
  # their provisions' bound withheld, never read whole
  defp qualified_items(body, clause_ref, doc) do
    {qualified, plain} =
      body
      # (a letter after a comma, never a roman sub-item: "…, v the Superannuation Act 1972")
      |> String.split(~r/;|,\s*(?=(?:and\s*)?[a-hj-uwyz]\s)/u)
      |> Enum.split_with(&String.match?(&1, @leading_qualifier))

    # (the qualifier's object is no item: "subsection (1) in so far as
    # relating to Schedule 5", ukpga 1993/9 s.48)
    refs =
      for item <- qualified,
          piece <-
            item
            |> String.replace(@qualifier_object, " ")
            |> Parts.qualify_chapters()
            |> Units.no_dots()
            |> pieces(),
          piece = String.replace(piece, @qualified_aside, " "),
          not other_law?(piece),
          ref <- refs_in(piece, clause_ref, doc),
          uniq: true,
          do: ref

    {Enum.join(plain, ";"), refs}
  end
end
