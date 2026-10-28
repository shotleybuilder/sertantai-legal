defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedUrisTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedUris

  # effect ids built here: never written whole in the repo
  defp id(c), do: "key-" <> String.duplicate(c, 32)

  test "a re-keyed effect's URI id maps to its EffectId; one keeping its id doesn't" do
    page = """
    <feed><entry><ukm:Effect EffectId="#{id("a")}" URI="http://www.legislation.gov.uk/id/effect/#{id("b")}" Type="words substituted"/></entry>
    <entry><ukm:Effect URI="http://www.legislation.gov.uk/id/effect/#{id("c")}" EffectId="#{id("c")}" Type="inserted"/></entry></feed>
    """

    assert FeedUris.from_pages([page]) == %{id("b") => id("a")}
  end
end
