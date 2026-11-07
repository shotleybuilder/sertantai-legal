defmodule SertantaiLegal.Scraper.Checks.StoreScan.Forms.BracketedContainer do
  @moduledoc """
  A Part, Chapter, Title or cross-heading named beside a provision, where
  no provision the effect names lies under it (Maritime Safety:
  Switch-over, 2026-11-06; RULES `bracketed-part-is-a-locator`): classed
  `bracketed` when the effect's text puts a container in brackets ("s.
  100A-100K (Pt. 5A)"), else `unbracketed` ("s. 13 Pt. 4"). Refs are the
  feed's own (`Ref`), never `FoundRef` (Decision 2, #192).
  """
  @behaviour SertantaiLegal.Scraper.Checks.StoreScan.Form

  @container ~r/^(part|chapter|title|crossheading)-/
  @bracketed ~r/\((?:Pt|Ch|Title|Sub-Pt|Section)\.?\s*[^)]*\)/

  @impl true
  def name, do: "bracketed_container"

  @impl true
  def match(effect) do
    {containers, provisions} =
      Enum.split_with(effect.affected_refs, &Regex.match?(@container, &1))

    standing =
      for c <- containers,
          not Enum.any?(provisions, &String.starts_with?(&1, c <> "-")),
          do: c

    cond do
      containers == [] or provisions == [] or standing == [] -> nil
      Regex.match?(@bracketed, effect.affected_provisions || "") -> "bracketed"
      true -> "unbracketed"
    end
  end
end
