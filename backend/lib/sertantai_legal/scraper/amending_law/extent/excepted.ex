defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Excepted do
  @moduledoc """
  Provisions excepted from an extent or application subsection (CV-S05
  round 7, from the recall sweep's `read:exception`): "Subsection (1) does
  not apply to section 59(3), 90, 91, 100, … 106 or 109" (Courts Act 2003
  s.111(2)); "But subsection (3) does not apply to the amendments made … by
  paragraphs 30 and 35 of Schedule 3" (ukpga 2016/19 s.95(4)); "Subsection
  (3) does not apply to— (a) Part 5 of Schedule 13 …; (b) section 26(2)".

  The subsection excepted from is the extent clause's, so where the
  provisions excepted extend isn't stated here: `{:unread, nil, refs}`,
  their bound withheld — a list naming them explicitly elsewhere (only,
  named) still decides (`Lookup`). Read only where the subsection named
  speaks of extent or application; an item qualified ("which makes
  provision as to its extent") names none. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Parts
  alias SertantaiLegal.Scraper.Commencement.Order

  @form ~r/^\s*(?:But\s+)?(?:Sub-?section|Sub-?paragraph|Paragraph)\s+\((?<n>\w+)\)\s+(?:does|do|shall)\s+not\s+apply\s+to\s*(?:the\s+following\s*)?(?:[—–:]\s*)?(?<list>.+?)\.?\s*$/iu

  @doc "The provisions excepted from the law's extent subsections: `{:unread, nil, refs}` each."
  @spec excepted([{String.t(), String.t()}], Doc.t()) :: [{:unread, nil, [String.t()]}]
  def excepted(unit_sentences, %Doc{} = doc) do
    for {ref, s} <- unit_sentences,
        refs = refs(s, ref, doc),
        refs != [],
        uniq: true,
        do: {:unread, nil, refs}
  end

  @doc "The provisions a sentence of the provision `ref` excepts from an extent subsection; [] when none."
  @spec refs(String.t(), String.t(), Doc.t()) :: [String.t()]
  def refs(s, ref, %Doc{} = doc) do
    with %{"n" => n, "list" => list} <- Regex.named_captures(@form, s),
         true <- extent_subsection?(doc, ref, n),
         false <- list =~ ~r/^\s*regulations\s+which\b/iu do
      # ("… 106 or 109": RefList joins with "and")
      list = String.replace(list, ~r/\s+or\s+(?=\d)/u, " and ")

      # (a description in brackets out first: "(for the extent of which, see
      # …)" is no qualified item — ukpga 2016/19 s.95(4))
      for item <- String.split(list, ~r/;|[—–,]\s*(?:and\s*|or\s*)?\(?[a-z]\)?\s+|,\s*or\s+/u),
          item = String.replace(item, ~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, " "),
          not (item =~ ~r/\bwhich\b/iu),
          r <- RefList.parse(item, ref) ++ Parts.parts(item, doc, ref),
          uniq: true,
          do: r
    else
      _ -> []
    end
  end

  @doc """
  Whether a sentence excepts provisions from a subsection that isn't an
  extent or application statement ("Subsection (3) does not apply to— (a)
  Part 5 of Schedule 13 …" where (3) is a commencement: ukpga 2013/22 s.61)
  — no extent words at all (the recall sweep's).
  """
  @spec other_exception?(String.t(), String.t(), Doc.t()) :: boolean()
  def other_exception?(s, ref, %Doc{} = doc) do
    case Regex.named_captures(@form, s) do
      %{"n" => n} -> not extent_subsection?(doc, ref, n)
      nil -> false
    end
  end

  # the subsection excepted from says where provisions extend or apply
  defp extent_subsection?(doc, ref, n) do
    Enum.any?(doc.ids, fn id ->
      Order.ref(id) == ref and
        case Doc.element(doc, "#{id}-#{n}") do
          nil ->
            false

          el ->
            el |> Doc.lines() |> Enum.join(" ") =~
              ~r/\b(?:extends?|extend|same\s+extent|appl(?:y|ies)\s+(?:only\s+)?(?:in\s+relation\s+to|to|in)\s+(?:England|Wales|Scotland|Northern\s+Ireland|Great\s+Britain|the\s+United\s+Kingdom))\b/iu
        end
    end)
  end
end
