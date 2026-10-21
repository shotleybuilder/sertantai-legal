defmodule SertantaiLegal.Scraper.ChangeVocabulary.EvidenceTest do
  @moduledoc """
  The evidence table's authority (Jason 2026-10-21): "The actual legal text
  is primary. These other sources are derived and secondary."
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}

  defp change(claims),
    do: %Change{
      key: "key-x",
      target: "s.1",
      claims: Enum.flat_map(claims, fn {s, a, v} -> Claim.new(s, a, v, "ref") end)
    }

  test "the legal text wins over the markup and the feed; the disagreement is a reported conflict" do
    c =
      change([
        {:law_text, :operation, :substituted},
        {:markup, :operation, :repealed},
        {:feed, :operation, :repealed},
        {:law_text, :territory, "W"},
        {:feed, :territory, "E+W"}
      ])
      |> Evidence.resolve("E+W")

    assert c.resolved.operation == :substituted
    assert c.resolved.territory == "W"
    assert c.resolved.tiers.operation == :primary
    assert {:operation, {:law_text, :substituted}, {:markup, :repealed}} in c.resolved.conflicts
    assert {:territory, {:law_text, "W"}, {:feed, "E+W"}} in c.resolved.conflicts
  end

  test "derived sources fill what the legal text doesn't say, marked derived" do
    c =
      change([{:feed, :operation, :repealed}, {:feed, :date, ~D[2020-01-01]}])
      |> Evidence.resolve(nil)

    assert c.resolved.operation == :repealed
    assert c.resolved.tiers.operation == :derived
    assert c.resolved.tiers.date == :derived
    assert c.resolved.conflicts == []
  end

  test "a commencement read from the law dates the change over the feed" do
    c =
      change([{:commencement, :date, ~D[2020-02-01]}, {:feed, :date, ~D[2020-01-01]}])
      |> Evidence.resolve(nil)

    assert c.resolved.date == ~D[2020-02-01]
    assert c.resolved.tiers.date == :primary
  end
end
