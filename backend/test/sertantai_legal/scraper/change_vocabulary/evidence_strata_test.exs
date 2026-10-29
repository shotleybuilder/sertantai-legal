defmodule SertantaiLegal.Scraper.ChangeVocabulary.EvidenceStrataTest do
  @moduledoc """
  The evidence check's strata (CV-S08): value conflicts (V, the law's text
  against legislation.gov.uk), markup–feed disagreements with no primary
  claim (D: the table's order alone chooses), and agreeing changes several
  sources state (A).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, EvidenceSample}
  alias SertantaiLegal.Scraper.ChangeVocabulary.EvidenceStrata

  @law "UK_uksi_2019_696"

  defp change(claims) do
    %Change{
      key: "k",
      target: "reg.21",
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "k"})
    }
    |> Evidence.resolve(nil)
  end

  defp stratum(claims), do: claims |> change() |> List.wrap() |> EvidenceStrata.classify()

  test "the law's text against legislation.gov.uk is a value conflict" do
    assert [{_, :V}] =
             stratum([
               {:law_text, :operation, :repealed},
               {:law_text, :by, @law},
               {:feed, :operation, :inserted},
               {:feed, :by, @law}
             ])
  end

  test "the markup against the feed with no primary claim is a derived disagreement" do
    c =
      change([
        {:markup, :operation, :inserted},
        {:markup, :cited, @law},
        {:feed, :operation, :substituted},
        {:feed, :by, @law}
      ])

    assert [{_, :D}] = EvidenceStrata.classify([c])
    assert EvidenceStrata.disagreements(c) == [{:operation, [:inserted], [:substituted]}]
    assert EvidenceSample.pattern(c) == "operation inserted/substituted substituted"
  end

  test "a primary claim settles a markup–feed difference: no derived disagreement" do
    c =
      change([
        {:law_text, :operation, :substituted},
        {:markup, :operation, :inserted},
        {:feed, :operation, :substituted}
      ])

    assert EvidenceStrata.disagreements(c) == []
  end

  test "the note's cited law against the feed's affecting law is a disagreement on by" do
    c = change([{:markup, :cited, "UK_uksi_2019_758"}, {:feed, :by, "UK_uksi_2019_1144"}])
    assert [{:by, _, _}] = EvidenceStrata.disagreements(c)
  end

  test "sources that agree are A; one source alone is no stratum" do
    assert [{_, :A}] =
             stratum([
               {:markup, :operation, :substituted},
               {:feed, :operation, :substituted},
               {:feed, :by, @law}
             ])

    assert [] = stratum([{:feed, :operation, :substituted}, {:feed, :by, @law}])
  end

  test "a feed listing one value twice beside the markup's same value agrees" do
    c =
      change([
        {:markup, :level, :words},
        {:feed, :level, :words},
        {:feed, :level, :provision}
      ])

    assert EvidenceStrata.disagreements(c) == []
  end
end
