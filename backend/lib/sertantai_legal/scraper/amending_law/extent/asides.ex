defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Asides do
  @moduledoc """
  The provisions a list item's qualified aside names, withheld (moved from
  `Extent.ListItems`, CV-S05 round 13):

  - "(and section 55 so far as relating to those paragraphs)" → s.55;
    "(including Schedule 13 so far as it relates to Part 6)" → sch.13
    (ukpga 2022/30 s.169, 2023/55 s.254: round 13 S4, found by the CV-S05d
    census; they were dropped, so took the default);
  - "section 113 (together with such of the other provisions of Part 7 as
    relate to …)": the rest of Part 7 (ukpga 2008/4 s.152, round 12).

  Never another law's provisions. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Parts

  @qualifier ~r/\b(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent)\b/iu
  @other_law ~r/\b(?:of|to),?\s+the\s+[A-Z][\w()',\s-]*?\s+(?:Act|Order|Regulations)\s+\d{4}/u

  @doc "The provisions an item's qualified asides name: withheld."
  @spec asides(String.t(), String.t() | nil, Doc.t()) :: [String.t()]
  def asides(text, clause_ref, doc) do
    for [aside] <- Regex.scan(~r/\((?:and|including|together\s+with|with)\b[^()]*\)/iu, text),
        aside =~ @qualifier,
        inner = aside |> String.trim_leading("(") |> String.trim_trailing(")"),
        inner = Regex.replace(~r/^\s*(?:and|including|together\s+with|with)\s+/iu, inner, ""),
        subject = inner |> String.split(@qualifier, parts: 2) |> hd(),
        not (subject =~ @other_law),
        ref <- provisions(subject, clause_ref, doc),
        uniq: true,
        do: ref
  end

  @doc """
  An item without its "(together with such of … as relate …)" aside, and
  the provisions the aside names (withheld).
  """
  @spec together_with_such(String.t(), String.t() | nil, Doc.t()) :: {String.t(), [String.t()]}
  def together_with_such(item, clause_ref, doc) do
    case Regex.run(
           ~r/\s*\(\s*together\s+with\s+such\s+of\s+(?<what>[^()]*?)\s+as\s+relates?\b[^()]*\)/iu,
           item,
           capture: :all
         ) do
      [whole, what] -> {String.replace(item, whole, " "), provisions(what, clause_ref, doc)}
      nil -> {item, []}
    end
  end

  defp provisions(text, clause_ref, doc),
    do: Enum.uniq(RefList.parse(text, clause_ref) ++ Parts.parts(text, doc, clause_ref))
end
