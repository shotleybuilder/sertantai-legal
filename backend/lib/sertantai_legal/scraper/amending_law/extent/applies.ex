defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Applies do
  @moduledoc """
  A provision's own application to a place (CV-S05 round 7; Jason
  2026-10-26: "read them as provision-level application"), from the
  forms the recall sweep counted (CV-S05a, `SweepForm` `read:application`):

  - "Regulation 44 applies to Scotland only", "Articles 3, 4, 5 and 6
    apply in England only" → `{:applies, "S", ["reg.44"]}`;
  - "This paragraph applies in relation to England only" (a Schedule
    paragraph's own), "Sub-paragraph (3) applies in relation to England
    only", "Subsections (4) to (8A) above shall not apply to Scotland"
    → the provision, or its subsections;
  - "Regulations 60, 61 and 62 apply in relation to Scotland, Wales and
    Northern Ireland respectively" → each its own;
  - "The following regulations do not apply in relation to Wales— (a)
    regulation 19; …" → `{:applies_not, "W", […]}`;
  - "In Schedule 13— (a) the amendments made by paragraph 14(2) and (4)
    apply in relation to England only" (`Units.unlettered/1`); "The
    omission of … by sub-paragraph (1) applies in relation to England
    only" → the provisions making them;
  - "Paragraph 20 of the Schedule extends and applies to England and
    Wales only" → also its extent (`{:only, …}`).

  Read only when stated whole: a condition after the place ("applies in
  Northern Ireland where— …", "… as if …") leaves it unread. Every
  top-level provision is read, Schedule paragraphs too (a paragraph's own
  application). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Parts, Places, Units}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @place_list Places.place_list()
  @provisions "(?:Sections?|Subsections?|Regulations?|Articles?|Paragraphs?|Sub-paragraphs?|Parts?|Chapters?|Schedules?|Rules?)"

  # a subject's words: never a verb or a condition of its own ("Subsection
  # (2) applies if, …, the regulator considers— … as it applies in relation
  # to England": 1984/55 s.120G)
  @subject_words "(?:(?!\\bappl(?:y|ies)\\b|\\b(?:if|where|as|unless)\\b)[^.;])*?"

  @statement Regex.compile!(
               "^\\s*(?<subj>(?:This|That)\\s+(?:paragraph|sub-paragraph|section|subsection|regulation|article|rule)|(?:the\\s+)?(?:amendments?|omission|revocations?|repeals?)\\b#{@subject_words}|#{@provisions}\\s+[\\d(]#{@subject_words})\\s+(?:(?:shall|will)\\s+)?(?<not>(?:does|do|shall)\\s+not\\s+)?(?<ext>extends?\\s+and\\s+)?(?:only\\s+)?appl(?:y|ies)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|to|in)\\s+(?<places>#{@place_list})(?<only>\\s+only)?(?<resp>\\s+respectively)?\\s*\\.?\\s*$",
               "iu"
             )

  @list Regex.compile!(
          "^\\s*The\\s+following\\s+(?:provisions|regulations|articles|sections)(?:\\s+of\\s+th(?:is|ese)\\s+\\w+)?\\s+(?<not>(?:do|does|shall)\\s+not\\s+)?appl(?:y|ies)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|to|in)\\s+(?<places>#{@place_list})(?:\\s+only)?\\s*[—–:]\\s*(?<items>.+)$",
          "iu"
        )

  @type entry :: {:applies | :applies_not | :only | :named, String.t(), [String.t()]}

  @doc "The provisions' own application (and an \"extends and applies\" extent) read from the law."
  @spec applies(Doc.t()) :: [entry()]
  def applies(%Doc{} = doc) do
    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        not container?(doc, id),
        unit <- Units.units(doc, id),
        s <- Clause.sentences(unit),
        part <- Units.statements(s),
        entry <- read(part, ref, doc),
        uniq: true,
        do: entry
  end

  @doc """
  What a sentence states, without its provisions: `{:applies, place}` or
  `{:applies_not, place}`, or nil (for the catalogue's class).
  """
  @spec statement(String.t()) :: {:applies | :applies_not, String.t()} | nil
  def statement(s) do
    case Regex.named_captures(@statement, s) || Regex.named_captures(@list, s) do
      nil -> nil
      m -> {if(m["not"] != "", do: :applies_not, else: :applies), Places.places(m["places"])}
    end
  end

  @doc "The entries one sentence of the provision `ref` states."
  @spec read(String.t(), String.t(), Doc.t()) :: [entry()]
  def read(s, ref, doc) do
    cond do
      m = Regex.named_captures(@statement, s) -> statement_entries(m, ref, doc)
      m = Regex.named_captures(@list, s) -> list_entries(m, ref, doc)
      true -> []
    end
  end

  defp statement_entries(m, ref, doc) do
    kind = if m["not"] != "", do: :applies_not, else: :applies
    refs = subject(m["subj"], ref, doc)

    cond do
      refs == [] ->
        []

      m["resp"] != "" ->
        respectively(kind, refs, m["places"])

      true ->
        place = Places.places(m["places"])

        extent =
          if m["ext"] != "" and kind == :applies, do: [{extent_kind(m), place, refs}], else: []

        [{kind, place, refs} | extent]
    end
  end

  defp extent_kind(m), do: if(m["only"] != "", do: :only, else: :named)

  # "Regulations 60, 61 and 62 apply in relation to Scotland, Wales and
  # Northern Ireland respectively": each its own (counts must agree)
  defp respectively(kind, refs, places) do
    codes = for [p] <- Regex.scan(~r/#{Places.place_names()}/iu, places), do: Places.places(p)

    if length(codes) == length(refs),
      do: for({r, p} <- Enum.zip(refs, codes), do: {kind, p, [r]}),
      else: []
  end

  defp list_entries(m, ref, doc) do
    kind = if m["not"] != "", do: :applies_not, else: :applies

    refs =
      for item <- String.split(m["items"], ~r/;|[—–,]\s*(?:and\s*|or\s*)?\(?[a-z]\)?\s+/u),
          not (item =~ ~r/\b(?:so\s+far|in\s*so\s*far|to\s+the\s+extent)\b/iu),
          r <- RefList.parse(item, ref) ++ Parts.parts(item, doc, ref),
          uniq: true,
          do: r

    if refs == [], do: [], else: [{kind, Places.places(m["places"]), refs}]
  end

  # the subject's provisions: this one; its subsections ("Subsection (7)",
  # "Sub-paragraph (3)", "Paragraph (1)"); the provisions making the
  # amendments ("the amendments made by paragraph 14(2) of Schedule 13", "…
  # by sub-paragraph (1)"); or those named
  defp subject(subj, ref, doc) do
    bare = String.replace(subj, ~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, " ")

    cond do
      bare =~ ~r/^\s*(?:This|That)\s+/iu ->
        [ref]

      bare =~ ~r/^\s*(?:the\s+)?(?:amendments?|omission|revocations?|repeals?)\b/iu ->
        case Regex.run(~r/\bby\s+(.+)$/iu, bare) do
          [_, by] -> named(by, ref, doc)
          nil -> []
        end

      true ->
        named(bare, ref, doc)
    end
  end

  defp named(text, ref, doc) do
    case subsections(text, ref) do
      [] -> Enum.uniq(RefList.parse(text, ref) ++ Parts.parts(text, doc, ref))
      subs -> subs
    end
  end

  # "Subsections (4) to (8A)", "Sub-paragraph (3)", "Paragraph (1)": the
  # provision's own
  defp subsections(text, ref) do
    base = String.replace(ref, ~r/\(.*$/, "")

    for [_, list] <-
          Regex.scan(
            ~r/^\s*(?:Sub-?sections?|Sub-?paragraphs?|Paragraphs?)\s+((?:\(\w+\)(?:\s*(?:,|and|to|or)\s*)?)+)(?!\s*of\b)/iu,
            text
          ),
        n <- numbers(list),
        do: "#{base}(#{n})"
  end

  defp numbers(list) do
    # ("(4) to (8A)": 4 to 8, and 8A)
    case Regex.run(~r/^\((\d+)\)\s*to\s*\((\d+)([A-Z]*)\)\s*$/u, String.trim(list)) do
      [_, a, b, suffix] ->
        Enum.map(String.to_integer(a)..String.to_integer(b), &to_string/1) ++
          if(suffix != "", do: [b <> suffix], else: [])

      nil ->
        for [_, n] <- Regex.scan(~r/\((\w+)\)/u, list), do: n
    end
  end

  # a Schedule (or a Part of one) whose paragraphs are units of their own
  defp container?(doc, id) do
    id =~ ~r/^schedule-[^-]+(?:-part-[^-]+)?$/ and
      Enum.any?(doc.ids, &String.starts_with?(&1, id <> "-paragraph-"))
  end
end
