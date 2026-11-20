defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.FirstProvisionList do
  @moduledoc """
  The amending pieces of a note's plural citation whose only operative
  mark sits on the cited instrument's first provision.

  legislation.gov.uk marks one piece of a plural citation operative, the
  first. In "S.I. 1988/1729, regs. 1(1), 12(1)(a)" (Mines and Quarries Act
  1954 ss.22-25) that piece is regulation 1, the instrument's citation and
  commencement, and the amending regulation 12(1)(a) is left unmarked. An
  instrument's regulation, article or rule 1 never amends, so the pieces
  listed with it (joined by commas, "and" or nothing) are the amending
  ones. The list ends at its first other words ("(with reg. 7)":
  `ListEnd`). A mark
  on any other provision, an Act's section 1 included, is read as given
  ("ss. 57(4), 147(3)", Environment Act 2021: the unmarked piece is the
  commencement).

  A listed piece may be written as words with no markup of its own, in
  braces or bare: "arts. 1(1) {8}" (SSI 2006/367 on the Fire (Scotland)
  Act 2005 s.24A), "art. 1(1), {Sch. 1 Pt. 5 Group 19}", "regs. 1(1), 6".
  It is read from the words (`AmendingLaw.Pointer`), a bare number
  continuing the mark's kind, and named as a SectionRef. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Pointer
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.ListEnd

  @first ~r/^(?:regulation|article|rule)-1(?:-|$)/
  @kinds %{"regulation" => "reg", "article" => "art", "rule" => "rule"}

  @doc """
  The SectionRefs listed with the marked first provision of the citation
  `citation_id` in a `Commentary` element, in order; nil when the note is
  not of the form (so its marks are read as given).
  """
  @spec pieces(tuple(), String.t()) :: [String.t()] | nil
  def pieces(_commentary, ""), do: nil

  def pieces(commentary, citation_id) do
    tokens = ListEnd.tokens(commentary, citation_id)
    marked = for {:piece, ref, true} <- tokens, do: ref

    if marked != [] and Enum.all?(marked, &first?/1),
      do: tokens |> from_mark() |> listed(),
      else: nil
  end

  defp first?(ref), do: ref =~ @first

  defp from_mark(tokens), do: Enum.drop_while(tokens, &(not match?({:piece, _, true}, &1)))

  # the pieces joined to the mark, the first provision's own left out
  # ("regs. 1(1)(a)(b)")
  defp listed([{:piece, mark, true} | rest]) do
    [kind | _] = String.split(mark, "-")
    refs = rest |> joined(@kinds[kind]) |> Enum.reject(&first?/1)

    if refs == [], do: nil, else: refs
  end

  # the list runs through marked-up pieces and list words, and ends at its
  # first other words or another citation's piece
  defp joined([{:piece, ref, _marked} | rest], kind), do: [ref | joined(rest, kind)]

  defp joined([{:text, text} | rest], kind) do
    run = ListEnd.run(text)
    written = written(run, kind)

    if run == text, do: written ++ joined(rest, kind), else: written
  end

  defp joined(_tokens, _kind), do: []

  # the pieces a run of list words names, after the mark's own kind
  # ("{8}" after "arts. 1(1)" → article-8), each as a SectionRef
  defp written(run, kind) do
    "#{kind}. 1, #{String.replace(run, ~r/[{}]|\band\b/, ",")}"
    |> Pointer.refs_in()
    |> Enum.drop(1)
    |> Enum.map(&section_ref/1)
  end

  @doc """
  A provision read from a note's words (`AmendingLaw.Pointer`), named as a
  `SectionRef`: `{:schedule, "8", nil, "18", ["3", "b"]}` →
  `"schedule-8-paragraph-18-3-b"`.
  """
  @spec section_ref(tuple()) :: String.t()
  def section_ref({:schedule, number, part, paragraph, subs}) do
    ["schedule", number, part && "part-#{part}", paragraph && "paragraph-#{paragraph}" | subs]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("-")
  end

  def section_ref({kind, number, subs}), do: Enum.join([kind, number | subs], "-")
end
