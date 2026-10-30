defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeSharedTest do
  @moduledoc "CV-S09 round 6: one words effect's places share the law-text claims read on their provision (HSWA s.16, SI 2008/960 art.8)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.Shared

  defp c(key, target, claims),
    do: %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "r"})
    }

  test "a place under the provision gets its law-text and commencement claims; others are untouched" do
    key = "key-" <> String.duplicate("e", 32)

    parent =
      c(key, "s.16", [
        {:law_text, :operation, :substituted},
        {:law_text, :level, :words},
        {:law_text, :by, "UK_uksi_2008_960"},
        {:commencement, :date, ~D[2008-04-01]}
      ])

    place = c(key, "s.16(2)", [{:feed, :by, "UK_uksi_2008_960"}, {:markup, :level, :words}])
    other = c("key-" <> String.duplicate("f", 32), "s.16(3)", [{:feed, :by, "UK_uksi_2008_960"}])

    out = Shared.spread([parent, place, other])
    got = Enum.find(out, &(&1.key == key and &1.target == "s.16(2)"))

    assert Change.value(got, :law_text, :by) == "UK_uksi_2008_960"
    assert Change.value(got, :commencement, :date) == ~D[2008-04-01]
    assert Enum.find(out, &(&1.target == "s.16(3)")).claims == other.claims
  end
end
