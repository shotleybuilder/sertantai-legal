defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Sweep do
  @moduledoc """
  The extent recall sweep (CV-S05a, Jason 2026-10-26: "are we using the
  agents to randomly find unmatched variation … rather than systematically
  seeding the patterns"): every sentence of a law's own words that may say
  where its provisions extend or apply, which the catalogue
  (`Patterns.classes/2`) doesn't class — the wordings outside the reader's
  vocabulary, counted rather than found by sampling.

  Two nets over each top-level provision's units (`Units.units/2`, the
  law's own words, quotes aside):

  - **A, the clause's neighbourhood:** a sentence in a section, regulation
    or article holding a classed extent or application statement, that
    speaks of application, extent or exceptions and names a place or a
    provision ("Subsection (1) does not apply to section 59(3), 90, …":
    Courts Act 2003 s.111(2));
  - **B, strong signals anywhere:** "extend(s) to <a place>", "throughout",
    "there", "as follows"; "the extent of any amendment …" ("… is the same
    as that of the provision amended": ukpga 2007/28 s.244(3)); "the same
    extent/application as"; a provision or the law that applies or has
    effect in, to or in relation to a place ("This paragraph applies in
    relation to England only").

  Never an idiom ("to the extent that", "the extent to which", "revoked to
  the extent specified", "extend the period", "as it applies in England").
  A sentence the catalogue classes (whole, or holding or held by one) is
  caught. `shape/1` clusters what remains; `AmendingLaw.SweepForm` names
  each one's form (kept apart: the labels never change the reading). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Units
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @places "England|Wales|Scotland|Northern Ireland|Great Britain|United Kingdom"

  @where "(?:the\\s+whole\\s+of\\s+)?(?:the\\s+)?(?:#{@places})|any\\s+part\\s+of\\s+the\\s+United\\s+Kingdom|the\\s+(?:same\\s+)?part\\s+or\\s+parts|that\\s+part"

  # the subject of an application: the law, a provision, its amendments
  @subject "(?:this|these|the\\s+following|the\\s+other|th(?:at|ose)|any|each|an?)\\s+(?:provisions?|Act|Regulations|Order|Rules|Part|Chapter|Schedule|section|subsection|regulation|article|paragraph|sub-paragraph|amendments?|repeals?|revocations?|modifications?)|(?:sections?|subsections?|regulations?|articles?|paragraphs?|Parts?|Chapters?|Schedules?)\\s+[\\dIVXLC(]"

  @strong Regex.compile!(
            "\\bextends?\\s+(?:(?:only|also|so)\\s+)?(?:to\\s+(?:#{@where})|throughout\\s+(?:#{@where})|there\\b|as\\s+follows|accordingly)" <>
              "|\\bextend\\s+(?:(?:only|also|so)\\s+)?(?:to\\s+(?:#{@where})|throughout|there\\b)" <>
              "|\\bthe\\s+extent\\s+of\\s+(?:any|this|these|the|an?|each)\\s+(?:amendments?|repeals?|revocations?|modifications?|provisions?|Act|Regulations|Order|Part|section|Schedule)" <>
              "|\\bsame\\s+(?:territorial\\s+)?(?:extent|application)\\s+(?:within\\s+the\\s+United\\s+Kingdom\\s+)?as\\b" <>
              "|(?:#{@subject})[^.;—–]{0,80}?\\b(?:appl(?:y|ies)|ha(?:ve|s)\\s+effect)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|to|in|as\\s+respects|throughout)\\s+(?:the\\s+whole\\s+of\\s+)?(?:the\\s+)?(?:#{@places})\\b",
            "iu"
          )

  @idiom ~r/\bas\s+(?:it|they)\s+appl(?:y|ies)\b|\b(?:to\s+the\s+extent|extent\s+to\s+which|any\s+extent|such\s+(?:an\s+)?extent|(?:revoked|repealed)\s+to\s+the\s+extent|extend\s+the\s+period)\b/iu

  @near_words ~r/\b(?:appl(?:y|ies)|extent|extends?|extend|subject\s+to|except|save)\b/iu
  @near_names Regex.compile!(
                "\\b(?:#{@places})\\b|\\b(?:sections?|subsections?|regulations?|articles?|paragraphs?|Parts?|Chapters?|Schedules?)\\s+[\\dIVXLC(]",
                "u"
              )

  # the catalogue's classes of a law's extent or application clause (a
  # provision's own, or one outside the clause, are no neighbourhood)
  @clause_class ~r/^(?:default|list|part_not|corresponds|applies|unread:(?:in_clause|another_default|list|part_not|application))/

  @doc """
  The sentences of the law (`doc`) the nets catch and the catalogue
  (`classes`: `Patterns.classes/2`'s `{ref, sentence, class}`) doesn't:
  `{ref, sentence, net}`, in document order.
  """
  @spec uncaught(Doc.t(), [{String.t(), String.t(), String.t()}]) :: [
          {String.t(), String.t(), String.t()}
        ]
  def uncaught(%Doc{} = doc, classes) do
    caught = for {_ref, s, _c} <- classes, do: squash(s)

    clause_refs =
      for {ref, _s, c} <- classes,
          not String.starts_with?(ref, "sch."),
          c =~ @clause_class,
          into: MapSet.new(),
          do: ref

    for id <- doc.ids,
        ref = Order.ref(id),
        ref != nil,
        not String.contains?(ref, "("),
        not container?(doc, id),
        unit <- Units.units(doc, id),
        s <- Clause.sentences(unit),
        net = net(s, ref, clause_refs),
        net != nil,
        sq = squash(s),
        not Enum.any?(caught, &(String.contains?(&1, sq) or String.contains?(sq, &1))),
        uniq: true,
        do: {ref, s, net}
  end

  @doc "Which net catches a sentence of the provision `ref`: \"B\", \"A\", or nil."
  @spec net(String.t(), String.t(), MapSet.t()) :: String.t() | nil
  def net(s, ref, clause_refs) do
    bare = String.replace(s, ~r/“[^”]*”|"[^"]*"/u, "")

    cond do
      Regex.match?(@idiom, bare) and not Regex.match?(~r/\bsame\s+extent\b/iu, bare) -> nil
      Regex.match?(@strong, bare) -> "B"
      MapSet.member?(clause_refs, ref) and near?(bare) -> "A"
      true -> nil
    end
  end

  defp near?(bare), do: Regex.match?(@near_words, bare) and Regex.match?(@near_names, bare)

  @doc """
  A sentence's shape, the key it is clustered by: quotes, titles, places
  and provision numbers stood in for, brackets of a letter or number
  dropped, its first 14 words.
  """
  @spec shape(String.t()) :: String.t()
  def shape(s) do
    s
    |> String.replace(~r/“[^”]*”|"[^"]*"/u, "Q")
    |> String.replace(
      ~r/\b[A-Z][\w(),'’ -]*? (?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4}\b/u,
      "TITLE"
    )
    |> String.replace(
      Regex.compile!(
        "\\b(?:the\\s+)?(?:#{@places})\\b(?:(?:\\s*,\\s*|\\s+and\\s+|\\s+or\\s+)(?:the\\s+)?(?:#{@places}))*",
        "u"
      ),
      "PLACE"
    )
    |> String.replace(
      ~r/\b(sections?|subsections?|regulations?|articles?|paragraphs?|sub-paragraphs?|Parts?|Chapters?|Schedules?|rules?)\s+(?:[\dIVXLC]+[A-Z]*|\(\w+\))(?:\([^)]*\))*(?:(?:\s*,\s*|\s+and\s+|\s+to\s+|\s+or\s+)[\dIVXLC]*[A-Z]*(?:\([^)]*\))*)*/iu,
      "\\1 N"
    )
    |> String.replace(~r/\(\w{1,4}\)/u, "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
    |> String.split(" ")
    |> Enum.take(14)
    |> Enum.join(" ")
  end

  # a Schedule (or a Part of one) whose paragraphs are units of their own
  defp container?(doc, id) do
    id =~ ~r/^schedule-[^-]+(?:-part-[^-]+)?$/ and
      Enum.any?(doc.ids, &String.starts_with?(&1, id <> "-paragraph-"))
  end

  defp squash(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()
end
