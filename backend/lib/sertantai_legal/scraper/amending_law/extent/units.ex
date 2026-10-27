defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Units do
  @moduledoc """
  The words an extent clause is read from (CV-S05; decomposed from
  `AmendingLaw.Extent`, run time 2026-10-25): the law's own words (never
  the words it inserts elsewhere), a top-level provision's units (its
  subsections, each whole), and the statements inside a sentence (lettered
  items under a lead-in, a compound's clauses). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Parts, Places, ScheduleWords}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @not_own_extent ~w(BlockAmendment)

  # the words that aren't the law's own: for its application, words it
  # inserts elsewhere and words inserted into it later (as made); for its
  # extent, only words it inserts elsewhere — an amended extent clause is
  # still the law's own extent ("This Part extends only to Scotland" in a
  # Part inserted later: CV-S05 H)

  @doc """
  The element with the words that aren't the law's own taken out: child
  elements named in `not_own` (by default, only words it inserts
  elsewhere: a `BlockAmendment`).
  """
  @spec own_words(tuple(), [String.t()]) :: tuple()
  def own_words(el, not_own \\ @not_own_extent)

  def own_words({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el, not_own) do
    kept =
      for child <- children,
          not match?({:xmlElement, _, _, _, _, _, _, _, _, _, _, _}, child) or
            local(elem(child, 1)) not in not_own,
          do: own_words(child, not_own)

    put_elem(el, 8, kept)
  end

  def own_words(node, _not_own), do: node

  defp local(name), do: name |> Atom.to_string() |> String.split(":") |> List.last()

  @doc """
  A top-level provision's units: its subsections (direct children:
  "section-84-1"), each whole with its lists, else the provision itself,
  the leading number CLML runs into the words dropped ("841 This Act" →
  "This Act"). The units a statement is read from (CV-S05).
  """
  @spec units(Doc.t(), String.t()) :: [String.t()]
  def units(%Doc{} = doc, id) do
    children = numbered_children(doc, id)

    for el_id <- if(children == [], do: [id], else: children),
        text = doc |> Doc.element(el_id) |> own_words() |> Doc.lines() |> Enum.join(" "),
        do: text |> String.replace(~r/^\s*\d+[A-Z]*\s*(?=[A-Z(])/u, "") |> unlettered()
  end

  @doc """
  A provision's numbered children (subsections "section-84-1"), the units it
  is read in; none where its children are lettered items ("section-17-a":
  "This Part shall extend to— (a) England and Wales, …", RTSA 2003 s.17;
  "These Regulations— … (c) extend to Northern Ireland only", SI 2020/1112
  reg.1), which are read whole with their lead-in (CV-S05 round 6).
  """
  @spec numbered_children(Doc.t(), String.t()) :: [String.t()]
  def numbered_children(%Doc{} = doc, id) do
    children = Doc.children(doc, id)

    if children != [] and Enum.all?(children, &(&1 =~ ~r/-[a-z]{1,2}$/)),
      do: [],
      else: children
  end

  @doc "Each top-level provision's unit sentences and the statements in them, with its ref."
  @spec unit_sentences(Doc.t()) :: [{String.t(), String.t()}]
  def unit_sentences(doc) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        not String.starts_with?(ref, "sch."),
        unit <- units(doc, id),
        s <- Clause.sentences(unit),
        part <- statements(s),
        uniq: true,
        do: {ref, part}
  end

  # (a Chapter, and "the amendments made by …": items of "In Part 3— (i)
  # Chapter 1 extends to …", "— (a) the amendments made by paragraph 9(3)
  # of Schedule 12 extend to …", CV-S05 round 6)
  # (also "(b) an amendment or repeal made by Chapters 2 to 6 …", "(a) any
  # amendment made by virtue of …": ukpga 2023/55 s.254(3), 2004/33
  # s.262(6), round 8)
  @provision_word "(?:(?:sections?|paragraphs?|Schedules?|Parts?|Chapters?|regulations?|articles?|rules?)\\s+[\\dIVXL]|(?:the|an?|any)\\s+(?:amendments?|repeals?|revocations?)(?:\\s*(?:,|or|and)\\s*(?:amendments?|repeals?|revocations?))*\\s+(?:made\\s+by|in)\\s)"

  @doc """
  A sentence and the statements inside it (CV-S05 round 4): each lettered
  item under a lead-in ("In Part 5— (a) sections 220 to 224 extend to
  England and Wales only; (b) …", "Part 5 extends as follows— (a) …"), and
  each clause of a compound ("Paragraphs 34 and 35 … extend to England and
  Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland
  only", "that Schedule" named). The sentence itself first.
  """
  @spec statements(String.t()) :: [String.t()]
  def statements(s) do
    items =
      if s =~ ~r/[—–]/u do
        s
        |> String.split(
          Regex.compile!(
            "[—–;]\\s*(?:and\\s+)?\\(?(?:[a-z]{1,2}|[ivx]{3,4})\\)?\\s+(?=#{@provision_word})",
            "u"
          )
        )
        |> tl()
      else
        []
      end

    clauses =
      case String.split(
             s,
             Regex.compile!(",\\s+and\\s+(?=#{@provision_word}[^,;]*?\\bextends?\\b)", "iu"),
             parts: 2
           ) do
        [first, second] ->
          sch = Regex.run(~r/\bSchedule\s+(\d+[A-Z]*)\b/u, first, capture: :all_but_first)

          second =
            case sch do
              [n] -> String.replace(second, ~r/\bof\s+that\s+Schedule\b/u, "of Schedule #{n}")
              nil -> second
            end

          [first, second]

        _ ->
          []
      end

    for part <- [s | items ++ clauses],
        part = part |> String.trim() |> String.trim_trailing(";") |> String.trim(),
        part != "",
        uniq: true,
        do: part
  end

  @places Places.place_names()

  @doc """
  Lettered extent wordings as plain ones (CV-S05 round 6), so every reader
  of a provision's words reads them:

  - places lettered: "This Part shall extend … to— (a) England and Wales,
    and (b) Scotland, and (c) Northern Ireland" (RTSA 2003 s.17) → "…
    extend to England and Wales, Scotland and Northern Ireland";
  - a verb lettered under its subject: "These Regulations— … ; and (c)
    extend to Northern Ireland only" (SI 2020/1112 reg.1) → "…; and.
    These Regulations extend to Northern Ireland only";
  - "there" after a place: "… shall extend to Northern Ireland, but except
    as aforesaid this Act shall not extend there" (ukpga 1975/71 s.129(6))
    → "… shall not extend to Northern Ireland";
  - paragraphs under "In Schedule N—": "In Schedule 1— (a) paragraph 3
    extends to …" → "(a) paragraph 3 of Schedule 1 extends to …".
  """
  @spec unlettered(String.t()) :: String.t()
  def unlettered(text) do
    text
    |> lettered_places()
    |> lettered_verbs()
    |> there()
    |> other_provisions()
    |> in_schedule()
    |> in_section()
    |> chapters()
    |> ScheduleWords.resolve()
  end

  # "In Part 3— (i) Chapter 1 extends to …" → "Chapter 1 of Part 3 …"
  # (extent words only: `Parts.qualify_chapters/1`)
  defp chapters(text),
    do: if(text =~ ~r/\bextends?\b/u, do: Parts.qualify_chapters(text), else: text)

  # "In Schedule 1— (a) paragraph 3 extends to …; (b) paragraph 8(2)(b) to
  # (d) extends to …" (SI 2014/469 art.3(2), SI 2019/758 reg.1): each
  # paragraph that Schedule's, the lead-in dropped (extent words only);
  # also before an aside ("(b) paragraphs 12 and 19 (and article 27 …)
  # extend to Scotland only": SI 2013/602 art.1(8), round 7 NEW-5)
  defp in_schedule(text) do
    with true <- text =~ ~r/\bextends?\b/u,
         [lead, n] <-
           Regex.run(
             ~r/^\s*(?:\d+[A-Z]*\s*)?In\s+Schedule\s+(\d+[A-Z]*)\b(?:\s*\([^()]*\))?\s*[—–]\s*/u,
             text
           ) do
      text
      |> String.replace_prefix(lead, "— ")
      |> then(
        &Regex.replace(
          ~r/\b(paragraphs?\s+(?:(?:\d+[A-Z]*|\([0-9A-Za-z]+\))(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*)?)+?)(?=\s*(?:\((?=[^()]*\s)[^()]*\)\s*)?(?:extends?|extend|ha(?:s|ve)|do|does|shall|[,;]|$))(?!\s*of\b)/u,
          &1,
          "\\1 of Schedule #{n} "
        )
      )
    else
      _ -> text
    end
  end

  # "In section 31— (a) subsections (1) and (2) extend to England and Wales
  # only; (b) subsection (3) extends to Northern Ireland only" (LRRA 2006
  # s.34(2), CV-S05 round 10) → "— (a) section 31(1) and (2) extend …; (b)
  # section 31(3) extends …" (extent words only)
  defp in_section(text) do
    with true <- text =~ ~r/\bextends?\b/u,
         [lead, kind, n] <-
           Regex.run(
             ~r/^\s*(?:\d+[A-Z]*\s*)?In\s+(section|regulation|article)\s+(\d+[A-Z]*)\s*[—–]\s*/u,
             text
           ) do
      text
      |> String.replace_prefix(lead, "— ")
      |> then(
        &Regex.replace(
          ~r/\b(?:sub-?section|paragraph)s?\s+(\(\w+\)(?:\s*(?:,|and|to|or)\s*\(\w+\))*)(?!\s*of\b)/u,
          &1,
          "#{kind} #{n}\\1"
        )
      )
    else
      _ -> text
    end
  end

  defp lettered_places(text) do
    Regex.replace(
      ~r/\b(extends?|extend)(?:\s*\.)*((?:\s+only)?)\s+to\s*[—–]\s*\(?a\)?\s+(#{@places})((?:\s*,?\s*(?:and|or)?\s*\(?[b-e]\)?\s+(?:#{@places}))+)/u,
      text,
      fn _, verb, only, first, rest ->
        places =
          [first | for([p] <- Regex.scan(~r/#{@places}/u, rest), do: p)]

        "#{verb}#{only} to " <>
          case Enum.split(places, -1) do
            {[], [one]} -> one
            {init, [last]} -> Enum.join(init, ", ") <> " and " <> last
          end
      end
    )
  end

  defp lettered_verbs(text) do
    case Regex.run(
           ~r/^\s*(?:\d+[A-Z]*\s*)?(Th(?:is|ese)\s+(?:Act|Regulations|Order|Rules|Scheme|Part))\s*[—–]/u,
           text
         ) do
      [_, subject] ->
        Regex.replace(
          ~r/([;,.]\s*(?:and\s*)?)\(?[a-z]\)?\s+(?=(?:shall\s+)?(?:not\s+)?extends?\b)/u,
          text,
          "\\1. #{subject} "
        )

      nil ->
        text
    end
  end

  defp there(text) do
    Regex.replace(
      ~r/(\bextends?\s+to\s+(#{@places})\b[^.]*?\bnot\s+extend\s+)there\b/u,
      text,
      "\\1to \\2"
    )
  end

  # "Section 7 extends to Northern Ireland, but the other provisions of
  # this Act do not extend to Northern Ireland" → "This Act, except—
  # Section 7, does not extend to Northern Ireland" (ukpga 1997/42 s.9(3),
  # CV-S05 round 7 NEW-4)
  defp other_provisions(text) do
    Regex.replace(
      ~r/((?:^|[.;:])\s*(?:\(?\d+[A-Z]*\)?\s*)?)((?:Sections?|Regulations?|Articles?|Parts?|Schedules?)\s[^,;.]+?)\s+extends?\s+(?:also\s+)?to\s+(#{@places}),?\s+but\s+the\s+other\s+provisions\s+of\s+this\s+(Act|Order|Regulations)\s+do\s+not\s+extend\s+to\s+\3\b/u,
      text,
      "\\1This \\4, except— \\2, does not extend to \\3"
    )
  end

  @doc "Repealed words' dots (\". . .\") taken out: they are no sentence's end."
  @spec no_dots(String.t()) :: String.t()
  def no_dots(text), do: String.replace(text, ~r/(?:\.\s*){2,}/u, " ")
end
