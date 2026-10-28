defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedUris do
  @moduledoc """
  The feed effects whose `URI` names another id than their `EffectId`
  (CV-S07 round 2, `docs/CHANGE-IDENTITY-DESIGN.md`): legislation.gov.uk
  re-keys an effect when it corrects it and keeps the first id in `URI`
  (33,894 of 251,692 stored effects); the change markup carries that one
  (NISR 2004/222 reg.2(1): `EffectId …c4575c`, `URI …abb9d4`). The merge
  maps a markup key equal to a `URI` id onto the effect's id.

  Read from the raw page, not `ChangesFeed`, so the parser's version
  (`ParserVersion`, which hashes `ChangesFeed`) is not touched by a field
  only the merge uses. Pure.
  """

  @effect ~r/<ukm:Effect\b[^>]*>/u
  @effect_id ~r/\bEffectId="([^"]+)"/u
  @uri ~r/\bURI="[^"]*\/effect\/([^"\/]+)"/u

  @doc "From the feed pages' XML: each differing `URI` id → its `EffectId`."
  @spec from_pages([String.t()]) :: %{String.t() => String.t()}
  def from_pages(pages) do
    for page <- pages,
        [tag] <- Regex.scan(@effect, page),
        [_, id] <- [Regex.run(@effect_id, tag)],
        [_, uri] <- [Regex.run(@uri, tag)],
        uri != id,
        into: %{},
        do: {uri, id}
  end
end
