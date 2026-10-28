defmodule SertantaiLegal.Scraper.Amendment.Reader.Scope do
  @moduledoc """
  Which of the laws offered an amending instruction is read for (CV-S06;
  decomposed from `Amendment.Reader`): none where it changes a Schedule's
  or an Annex's paragraphs (no rules while Schedules are not read as
  targets), no EU Articles under an Annex heading, and none where it lists
  many laws' provisions (each law's items are not told apart). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.{Clauses, LawNamed}

  # a provision of the amended law named by number (CV-S06: unicode, so a
  # non-breaking space counts; never a title's year, "Regulations 1997"
  # once "(Northern Ireland)" goes with the captions)
  @provision_number ~r/\b(?:sections?|regulations?|articles?|rules?)\s+(?!(?:18|19|20)\d{2}\b(?!\())\d/iu
  # the amending law's own Schedule: where the change is set out, not where
  # it is made ("The provisions set out in Part I of Schedule 4 shall be
  # substituted for Part VIII of …": EReA 1999 s.7; "Schedule 2 to this Act";
  # "If … Part 2 of this Schedule is not in force, in subsection (6)—")
  @own_schedule ~r/\bset\s+out\s+in\s+(?:Part\s+\w+\s+of\s+)?(?:the\s+)?Schedule(?:\s+[\dA-Z]+)?\b|\b(?:the\s+)?Schedule(?:\s+[\dA-Z]+)?\s+to\s+th(?:is|ese)\s+(?:Act|Regulations|Order|Rules|Measure)\b|\b(?:Part\s+\w+\s+of\s+)?this\s+Schedule\b/iu
  # a place in a Schedule or Annex: "Schedule 2", "Annex 17", "the Schedule"
  @schedule_place ~r/\b(?:Schedule|Annex)\s+(?-i:[\dIVXLC]+[A-Z]*)\b|\b(?:in|of|for|to|omit)\s+the\s+Schedule\b/iu

  # an instruction under "Schedule 1 (…) is amended as follows" (its
  # provision's first words), where neither it nor a provision holding it
  # names a section, regulation or article (captions and quotes aside),
  # changes that Schedule's paragraphs: no rules while Schedules are not
  # read as targets (2009/20 Sch. 4 para 10 "For paragraph 1 substitute—"
  # had read as s.1; captions' "section 2(4)" as s.2; a later "In section
  # 90 …—" list is that section's: 2013/22 s.25(8)); or under a provision
  # "In Schedule 6 (…)—" (SI 2015/664 Sch. 2 para 12(3)); run time 2026-10-26.
  # So too where the instruction itself or a holding provision places it
  # in a Schedule or Annex ("In Schedule 2, for paragraph 10 substitute—"
  # had read as reg.10; "Omit Schedule 5"; "In paragraph 1 of Part 3 of
  # Schedule 6—"; "in Schedule 1 –" with a non-breaking space: CV-S06 B1)
  defp in_schedule(laws, %Text{context: context, instruction: i, parents: parents}) do
    own =
      Enum.map(
        [i | parents],
        &(&1
          |> Clauses.unquote_words()
          |> Clauses.no_captions()
          |> String.replace(@own_schedule, ""))
      )

    names_provision? = Enum.any?(own, &(&1 =~ @provision_number))

    # (its caption aside: "Schedule 2 (constitution etc. of the Health
    # and Safety Executive) is amended as follows", 2013 c.32 Sch.12 —
    # the caption's "etc." had ended the sentence)
    schedule? =
      Enum.any?(own, &(&1 =~ @schedule_place)) or
        (match?([first | _] when is_binary(first), context) and
           context |> hd() |> Clauses.no_captions() =~
             ~r/^\s*(?:(?:Part|Paragraph)\s+\w+\s+of\s+)?Schedule\s+\d+[A-Z]*\b[^.]*?\bis\s+amended\b/iu)

    if schedule? and not names_provision?,
      do: [],
      else: laws
  end

  # an instruction under a heading amending an EU law's Annexes or
  # Appendices numbers that Annex's paragraphs, never its Articles ("8.1.1.1",
  # "4" in "Amendment of the Annexes and Appendices to the REACH
  # Regulation": SI 2019/758 Sch. 3): no Article rules until Annex targets
  # are read (run time, 2026-10-25)
  defp articles_only(laws, doc, id) do
    if Enum.any?(Doc.headings(doc, id), &(&1 =~ ~r/\b(?:Annex(?:es)?|Appendi(?:x|ces))\b/)),
      do: Enum.reject(laws, &(&1.kind == :article)),
      else: laws
  end

  # the distinct laws an instruction names outside its quotes, by year (a
  # title and its chapter, "Factories Act 1961 (c. 34)", are one law)
  defp laws_listed(instruction, terms) do
    instruction
    |> Clauses.unquote_words()
    |> LawNamed.law_spans(terms)
    |> Enum.map(fn {_, _, ref} ->
      case ref do
        %{chapter: {y, _}} -> y
        %{law: l} when is_binary(l) -> l |> String.split("_") |> Enum.at(2)
        %{eu: {_, y, _}} -> y
        %{title: t} when is_binary(t) -> t |> String.slice(-4, 4)
        _ -> nil
      end
    end)
    |> Enum.uniq()
    |> length()
  end

  @doc "The laws of `laws` the instruction `text` (`id` in `doc`, its defined `terms`) is read for."
  @spec laws(Doc.t(), String.t(), Text.t(), map(), [Reader.law_ref()]) :: [Reader.law_ref()]
  def laws(doc, id, text, terms, laws) do
    # a list of many laws' provisions ("In the following provisions, for
    # … substitute …— s.1A(8) of the 1953 Act; …; paragraph 2(2) of
    # Schedule 3A to the 1974 Act; …": Sentencing Act 2020 Sch. 24; "The
    # enactments are— …, section 60; …": 2022/31 Sch. 1) is no law's
    # instruction alone: its items were read as each law's targets (CV-S06 B2)
    if laws_listed(text.instruction, terms) >= 3,
      do: [],
      else: laws |> articles_only(doc, id) |> in_schedule(text)
  end
end
