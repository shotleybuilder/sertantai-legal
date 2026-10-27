defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.PartLead do
  @moduledoc """
  A Part named only by its lead-in, made plain (CV-S05 round 12): "In Part 5
  (planning, land and buildings)— (a) an amendment or repeal has the same
  extent as the provision to which it relates, …" (Infrastructure Act 2015
  s.56(6); Environment Act 2021 s.147(4), (5)) → "(a) an amendment or repeal
  made by Part 5 has the same extent …": the amendments that Part makes,
  never every amendment the law makes. Pure.
  """

  @lead ~r/^\s*(?:\d+[A-Z]*\s*)?In\s+Part\s+([\dIVXLC]+[A-Z]*)\b(?:\s+of\s+this\s+(?:Act|Order|Regulations))?(?:\s*\((?:[^()]|\([^()]*\))*\))?\s*[—–]/u

  @doc "The text with a Part lead-in's bare \"an amendment or repeal has …\" made that Part's."
  @spec resolve(String.t()) :: String.t()
  def resolve(text) do
    case Regex.run(@lead, text) do
      [_, n] ->
        Regex.replace(
          ~r/\b((?:an?|any)\s+(?:amendments?|repeals?|revocations?)(?:\s+or\s+(?:amendments?|repeals?|revocations?))*)\s+(ha(?:s|ve)\s+the\s+same\s+extent)\b/u,
          text,
          "\\1 made by Part #{n} \\2"
        )

      nil ->
        text
    end
  end
end
