defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Units do
  @moduledoc """
  The words an extent clause is read from (CV-S05; decomposed from
  `AmendingLaw.Extent`, run time 2026-10-25): the law's own words (never
  the words it inserts elsewhere), a top-level provision's units (its
  subsections, each whole), and the statements inside a sentence (lettered
  items under a lead-in, a compound's clauses). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
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
    children = Doc.children(doc, id)

    for el_id <- if(children == [], do: [id], else: children),
        text = doc |> Doc.element(el_id) |> own_words() |> Doc.lines() |> Enum.join(" "),
        do: String.replace(text, ~r/^\s*\d+[A-Z]*\s*(?=[A-Z(])/u, "")
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

  @provision_word "(?:sections?|paragraphs?|Schedules?|Parts?|regulations?|articles?|rules?)\\s+[\\dIVXL]"

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
            "[—–;]\\s*(?:and\\s+)?\\(?[a-z]{1,2}\\)?\\s+(?=#{@provision_word})",
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

  @doc "Repealed words' dots (\". . .\") taken out: they are no sentence's end."
  @spec no_dots(String.t()) :: String.t()
  def no_dots(text), do: String.replace(text, ~r/(?:\.\s*){2,}/u, " ")
end
