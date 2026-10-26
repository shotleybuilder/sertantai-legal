defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Unread do
  @moduledoc """
  A law's extent statements left unread, as bounds withheld (CV-S05 round
  6, Jason 2026-10-26: "never drop a statement silently"): a sentence
  saying where some of the law's provisions extend that the reader didn't
  turn into rules (`Patterns.classes/2`: an `unread:` class) makes those
  provisions' extent unknown — `{:unread, nil, refs}`, which `Lookup.of/2`
  answers nil — never the default.

  Only the law's own words state its extent: a sentence in words it inserts
  elsewhere ("… for subsection (5) there shall be substituted— (5) Section
  6B and this section extend to …") or a mention ("Acts … which extend to
  Northern Ireland", "to the same extent as the document itself") states
  nothing. The provisions are the statement's subject, before its verb:

  - named provisions of the law ("Subsections (5) to (7) above", "Section
    79 above", "Chapter 1 of Part 3", "this section"; the items of "The
    following provisions …— (a) …") → their refs, else the container
    named ("In Schedule 11— (a) paragraph 2 extends …" → sch.11);
  - a Schedule paragraph's own statement ("The repeal of section 4(8)
    extends also to Scotland", "This paragraph extends only to England and
    Wales") → that paragraph; "This Part of this Schedule" → the Schedule;
  - the law's amendments ("any provision of this Act which amends …") or
    the law itself ("To the extent that these Regulations concern …,
    they") → `"*"`: every provision no list names.

  Wider is safe (a bound withheld), never narrower. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Parts, Places, Units}
  alias SertantaiLegal.Scraper.Commencement.Order

  # the classes of a statement the reader leaves unread (`Patterns`); an
  # application clause not resolved bounds nothing here (where a law
  # applies is `Extent.application`)
  @classes ~w(unread:in_clause unread:not_read unread:another_default unread:list unread:part_not unread:other_provision unread:provision_extent)

  @places Places.place_names()

  # where provisions extend: "extend(s) (also|only) to <place>", "does not
  # extend to", "has the same extent", "shall also so extend"
  @verb Regex.compile!(
          "\\bextends?\\s+(?:also\\s+|only\\s+)?(?:to\\s+(?:the\\s+whole\\s+of\\s+|any\\s+part\\s+of\\s+)?|throughout\\s+)(?:#{@places})|\\bnot\\s+(?:\\w+\\s+)?extend\\s+to\\s+(?:#{@places})|\\bha(?:s|ve)\\s+(?:\\([^()]*\\)\\s+)?the\\s+same\\s+extent\\b|\\bso\\s+extends?\\b|\\bextends?\\s+as\\s+follows\\b",
          "iu"
        )

  # the words just before a verb that make it a mention: "an enactment
  # which extends to", "so much of this Act as extends to", "provide for
  # the provisions … to extend also to" (", which extends": a statement)
  @mention ~r/(?:(?<!,)\s(?:which|that|who)\s+(?:[\w()]+\s+){0,3}|\b(?:if|whether|to\s+the\s+extent\s+that),?\s+(?:[\w()]+,?\s+){0,3}|\b(?:so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as)\s+(?:[\w()]+\s+){0,3}|\bas\s+(?:[\w()]+\s+)?|\bto\s+|\bmay\s+)(?:do\s+not\s+|does\s+not\s+|shall\s+(?:not\s+)?|is\s+to\s+|are\s+to\s+)?$/iu

  # another law's provisions ("sections 77 to 80 of the Environment (Wales)
  # Act 2016", "Schedule 12 to the Courts Act 2007"), taken out of a subject
  @other_law ~r/(?:\b(?:sections?|regulations?|articles?|rules?|paragraphs?|Schedules?|Parts?|Chapters?)\s+[\w().,\s]*?\s+)?\b(?:of|to|in)\s+(?:that\s+Act|the\s+\d{4}\s+(?:Act|Regulations|Order)|the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations|Rules)(?:\s+\(Northern\s+Ireland\))?(?:\s+\d{4})?)(?:\s*\([^()]*\))?/u

  @amendments ~r/\b(?:amendments?|repeals?|revocations?|modifications?|amends?|repealed|revoked|amending|repealing)\b/iu
  @whole ~r/\b(?:this|these)\s+(?:Act|Regulations|Order|Rules|Scheme|Measure)\b|^\s*(?:it|they)\b|,\s*(?:it|they)\s+$/iu

  @doc "The unread classes that withhold a bound."
  @spec classes() :: [String.t()]
  def classes, do: @classes

  @doc "The extent read with the bounds its unread statements (`classes`) withhold."
  @spec withheld(Extent.t(), [{String.t(), String.t(), String.t()}], Doc.t()) :: Extent.t()
  def withheld(%Extent{} = e, classes, %Doc{} = doc),
    do: %{e | lists: e.lists ++ lists(classes, doc)}

  @doc """
  The bounds withheld by a law's unread statements (`classes`:
  `Patterns.classes/2`'s `{ref, sentence, class}`), one `{:unread, nil,
  refs}` list per statement naming the law's provisions.
  """
  @spec lists([{String.t(), String.t(), String.t()}], Doc.t()) :: [
          {:unread, nil, [String.t()]}
        ]
  def lists(classes, %Doc{} = doc) do
    known = known_refs(doc)

    for {ref, s, class} <- classes,
        class in @classes,
        items = subject(s, ref, doc, known),
        items != [],
        uniq: true,
        do: {:unread, nil, items}
  end

  @doc """
  The law's provisions a statement (`s`, in the provision `ref`) speaks of:
  refs, `["*"]` (the law or its amendments), or [] (none of its own).
  """
  @spec subject(String.t(), String.t(), Doc.t(), MapSet.t() | nil) :: [String.t()]
  def subject(s, ref, %Doc{} = doc, known \\ nil) do
    known = known || known_refs(doc)
    # (as every reader reads a provision's words: `Units.unlettered/1`)
    s = Units.unlettered(s)

    if own?(s, ref, doc) do
      [whole | items] = Units.statements(s)

      # every lettered item too, whatever it begins with ("…; and (b) the
      # amendments made by paragraph 2 extend to …")
      items =
        Enum.uniq(
          items ++
            (s
             |> String.split(~r/[—–;]\s*(?:and\s*|or\s*)?\(?[a-z]{1,2}\)?\s+/u)
             |> tl()
             |> Enum.map(&String.trim/1)
             |> Enum.reject(&(&1 == "")))
        )

      [{whole, false} | Enum.map(items, &{&1, true})]
      |> Enum.flat_map(fn {part, item?} -> part_subject(part, item?, s, ref, doc) end)
      |> Enum.filter(&(&1 == "*" or known?(&1, known)))
      |> Enum.uniq()
      |> then(fn items -> if "*" in items, do: ["*"], else: items end)
    else
      []
    end
  end

  # the sentence is in the provision's own words (not words it inserts)
  defp own?(s, ref, doc) do
    own =
      doc.ids
      |> Enum.filter(&(Order.ref(&1) == ref))
      |> Enum.flat_map(&Units.units(doc, &1))
      |> Enum.map_join(" ", &squash/1)

    String.contains?(own, squash(s))
  end

  defp squash(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  # a statement's subject (the words before its verb); a list item with
  # no verb of its own is the subject itself where the lead-in states
  # ("The following provisions extend …— (a) section 6, …"; "Those
  # provisions are— (a) …"), never a table's or an aside's words
  defp part_subject(part, item?, sentence, ref, doc) do
    case statement_at(part) do
      nil ->
        if item? and stating_lead?(sentence), do: refs(part, sentence, ref, doc), else: []

      at ->
        part |> binary_part(0, at) |> lead_dropped() |> item_subject(item?, sentence, ref, doc)
    end
  end

  # an item's pronoun is its lead-in's subject, read with the lead-in ("…
  # has the same extent as the enactment amended, except that— (a) it does
  # not extend to Scotland": ukpga 2007/27 s.93)
  defp item_subject(subj, item?, sentence, ref, doc) do
    if item? and subj =~ ~r/^\s*(?:it|they)\s+(?:(?:shall|do|does|is|are)\s+)?(?:not\s+)?$/iu,
      do: [],
      else: refs(subj, sentence, ref, doc)
  end

  # (the list follows the statement: no sentence ends between them — a
  # repeals table's rows after "… do not extend to Northern Ireland.")
  defp stating_lead?(sentence) do
    lead = sentence |> String.split(~r/[—–]/u, parts: 2) |> hd()

    case statement_at(lead) do
      # (never an application's list: "The following provisions … do not
      # apply in England and Wales or Scotland— …", SI 2020/818 reg.1A)
      nil ->
        lead =~ ~r/\b(?:following|namely|Those\s+provisions)\b/iu and
          not (lead =~ ~r/\b(?:appl(?:y|ies)|ha(?:ve|s)\s+effect)\b/iu)

      at ->
        not (binary_part(lead, at, byte_size(lead) - at) =~ ~r/[.;]\s*\S/u)
    end
  end

  defp statement_at(part) do
    @verb
    |> Regex.scan(part, return: :index)
    |> Enum.find_value(fn [{at, _} | _] ->
      if not Regex.match?(@mention, binary_part(part, 0, at)), do: at
    end)
  end

  # "Subject to subsection (4), …", "Apart from the amendments made by
  # sections 1 and 46, …": the lead-in names no subject
  defp lead_dropped(subj),
    do:
      String.replace(
        subj,
        ~r/^\s*(?:Subject\s+to|Apart\s+from|Except(?:\s+for)?|Save\s+for|Other\s+than)\s+[^,]+,\s*/iu,
        ""
      )

  defp refs(subj, sentence, ref, doc) do
    # descriptions in brackets out ("(c. 27)", "(traffic wardens)"), never
    # a number ("(5) to (7)", "1(2)(b)"); another law's provisions out
    bare =
      subj
      |> String.replace(~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, " ")
      |> String.replace(@other_law, " ")

    # "The following provisions …— (a) …": the list is the subject
    list =
      if bare =~ ~r/\bfollowing\b/iu,
        do: (sentence |> String.split(~r/[—–]/u, parts: 2) |> Enum.at(1, "")) <> " " <> bare,
        else: bare

    named = list |> in_schedule(sentence) |> named(ref, doc)
    named = if sch?(ref), do: schedule_own(named, list), else: named

    cond do
      named != [] -> named
      # "(c) extend to Northern Ireland only" under "These Regulations—"
      list =~ ~r/^\s*[a-z]{1,2}\s*$/u -> ["*"]
      sch?(ref) -> if(list =~ ~r/\bthis\s+Schedule\b/iu, do: [schedule_of(ref)], else: [ref])
      (c = lead_container(sentence)) != [] -> c
      Regex.match?(@whole, list) -> ["*"]
      Regex.match?(@amendments, list) and Regex.match?(@whole, subj) -> ["*"]
      true -> []
    end
  end

  # "In Schedule 13— (a) the amendments made by paragraphs 16, 20 and
  # 30 …": that Schedule's paragraphs (the lead-in itself names none:
  # never "Schedule 11— (a) paragraph 2" as Schedules 11 and 2)
  defp in_schedule(list, sentence) do
    case Regex.run(~r/^\s*In\s+Schedule\s+(\d+[A-Z]*)\b[^—–]*[—–]/u, sentence) do
      [lead, n] ->
        list
        |> String.replace(lead, " ")
        |> String.replace(~r/^\s*In\s+Schedule\s+\d+[A-Z]*\b[^—–]*[—–]/u, " ")
        |> then(
          &Regex.replace(
            ~r/\bparagraphs?\s+((?:\d+[A-Z]*(?:\(\w+\))*(?:\s*(?:,|and|to)\s*)?)+)/u,
            &1,
            "paragraphs \\1 of Schedule #{n} "
          )
        )

      nil ->
        list
    end
  end

  # the provisions named; else the containers named (a Chapter as its
  # Part, "Schedule 2 to these Regulations" whole)
  defp named(list, ref, doc) do
    case Enum.uniq(
           RefList.parse(list, ref) ++
             Parts.parts(list, doc, ref) ++ this(list, ref) ++ subsections(list, ref)
         ) do
      [] ->
        Enum.uniq(
          schedules(list) ++
            Parts.parts(
              String.replace(list, ~r/\bChapters?\s+\S+\s+of\s+(?=Part)/u, ""),
              doc,
              ref
            )
        )

      named ->
        named
    end
  end

  # "this paragraph", "this regulation", "this article": the provision itself
  defp this(subj, ref) do
    if subj =~ ~r/\bthis\s+(?:section|paragraph|regulation|article|rule)\b/iu, do: [ref], else: []
  end

  # "Subsections (5) to (7) above", "Subsection (2)": the provision's own
  # (a Schedule's are sub-paragraphs: its paragraph, `this/2`)
  defp subsections(_subj, "sch." <> _), do: []

  defp subsections(subj, ref) do
    base = String.replace(ref, ~r/\(.*$/, "")

    for [_, list] <-
          Regex.scan(
            ~r/\b[Ss]ub-?(?:sections?|paragraphs?)\s+((?:\(\w+\)(?:\s*(?:,|and|to|or)\s*)?)+)(?!\s*of\b)/u,
            subj
          ),
        n <- numbers(list),
        do: "#{base}(#{n})"
  end

  defp numbers(list) do
    case Regex.run(~r/^\((\d+)\)\s*to\s*\((\d+)\)\s*$/u, String.trim(list)) do
      [_, a, b] -> Enum.map(String.to_integer(a)..String.to_integer(b), &to_string/1)
      nil -> for [_, n] <- Regex.scan(~r/\((\w+)\)/u, list), do: n
    end
  end

  # "of Schedule 2 to these Regulations", "The provisions of Schedule 9":
  # the Schedules RefList doesn't take after "of"
  defp schedules(subj) do
    for [_, n] <-
          Regex.scan(~r/\bSchedules?\s+(\d+[A-Z]*)\b(?!\s+(?:to|of)\s+the\s+[A-Z])/u, subj),
        uniq: true,
        do: "sch.#{n}"
  end

  # a Schedule paragraph's sections are the law it amends, unless "of this Act"
  defp schedule_own(named, subj) do
    if subj =~ ~r/\bof\s+th(?:is|ese)\s+(?:Act|Regulations|Order)\b/iu,
      do: named,
      else: Enum.filter(named, &String.starts_with?(&1, "sch."))
  end

  defp sch?(ref), do: String.starts_with?(ref, "sch.")
  defp schedule_of(ref), do: ref |> String.split(".") |> Enum.take(2) |> Enum.join(".")

  # "In Schedule 13— (a) the amendments made by paragraphs 16, 20 and 30":
  # paragraphs not told apart, so the Schedule
  defp lead_container(sentence) do
    for [_, n] <- Regex.scan(~r/^\s*In\s+Schedule\s+(\d+[A-Z]*)\b/u, sentence), do: "sch.#{n}"
  end

  # the law's provisions, by ref and container ("s.14", "sch.7")
  defp known_refs(doc) do
    for id <- doc.ids,
        r = Order.ref(id),
        r != nil,
        p <- prefixes(r),
        into: MapSet.new(),
        do: p
  end

  defp prefixes(ref) do
    base = String.replace(ref, ~r/\(.*$/, "")
    parts = String.split(base, ".")
    for n <- 2..length(parts)//2, n <= length(parts), do: parts |> Enum.take(n) |> Enum.join(".")
  end

  defp known?(item, known) do
    case String.split(item, "..") do
      [a, _b] -> known?(a, known)
      [one] -> MapSet.member?(known, String.replace(one, ~r/\(.*$/, ""))
    end
  end
end
