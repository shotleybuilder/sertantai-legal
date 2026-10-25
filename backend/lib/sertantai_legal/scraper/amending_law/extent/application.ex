defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Application do
  @moduledoc """
  An amending law's own application clause, as a code (CV-07; decomposed
  from `AmendingLaw.Extent`, run time 2026-10-25): "These Regulations …
  apply in relation to England only" → "E" — where the changes it makes
  apply. Read from the law's own words only (`Units.own_words/2`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Units
  alias SertantaiLegal.Scraper.ApplicationClause
  alias SertantaiLegal.Scraper.Commencement.Order

  # the law's whole-instrument application clause ("These Regulations …
  # apply in relation to England only"; `ApplicationClause`), as a code:
  # where the changes it makes apply (CV-07)
  # Read from the law's own words only: never the words an amending
  # instruction inserts into another law ("After regulation 1 insert— …
  # These Regulations apply to Northern Ireland": a BlockAmendment), nor
  # words inserted into this law later (an Addition or Substitution: SI
  # 2008/2852 reg.1A, inserted 2020, never confines the changes it made in
  # 2008) — CV-S05 N1, N2
  @not_own ~w(BlockAmendment Addition Substitution)

  @doc "The law's whole-instrument application as a code (\"E\"); nil when it states none. `extent` its default."
  @spec application(Doc.t(), String.t() | nil) :: String.t() | nil
  def application(doc, extent) do
    clauses =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil,
          not String.contains?(ref, "("),
          text =
            doc |> Doc.element(id) |> Units.own_words(@not_own) |> Doc.lines() |> Enum.join(" "),
          # (never "… revoked to the extent that they apply in Northern
          # Ireland": other laws' application, nisr 2018/17 — CV-S05 round 3 B)
          c =
            text
            |> String.replace(
              ~r/\b(?:to\s+the\s+extent\s+that|so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as)\s+(?:it|they)\s+appl(?:y|ies)\b[^.;]*/iu,
              ""
            )
            |> ApplicationClause.parse(),
          c != nil,
          do: c

    extent_regions = extent && String.split(extent, "+")

    case ApplicationClause.resolve(clauses, extent_regions) do
      nil -> nil
      regions -> Enum.join(regions, "+")
    end
  end
end
