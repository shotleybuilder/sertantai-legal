defmodule SertantaiLegal.Scraper.ChangeVocabulary.CanonicalTest do
  @moduledoc """
  #182 (Jason 2026-10-22: "Can we make the reader more accommodating?"):
  the parse names some EU articles with a non-breaking space ("Article 2"),
  the readers name them from the CLML with an ordinary one. The vocabulary
  reads LAT's names in one spelling, so they agree without a re-parse.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary
  alias SertantaiLegal.Scraper.ChangeVocabulary.Ref

  @nbsp "art.Article 2"

  @xml ~S"""
  <Legislation RestrictExtent="E+W+S+N.I."><EURetained><EUBody>
  <P1group><P1 id="article-1"><P1para><Text>From 1st January 2021 these Regulations apply in Northern Ireland only.</Text></P1para></P1></P1group>
  <P1group><P1 id="article-2"><P1para><Text>In this Regulation “emissions” means the release of greenhouse gases.</Text></P1para></P1></P1group>
  </EUBody></EURetained><Commentaries/></Legislation>
  """

  test "any Unicode space is an ordinary one" do
    assert Ref.canonical(@nbsp) == "art.Article 2"
    assert Ref.canonical("pt.PART 4") == "pt.PART 4"
    assert Ref.canonical("s.23(1)[E+W]") == "s.23(1)[E+W]"
  end

  test "a row named with a non-breaking space meets the readers' name" do
    labels =
      ChangeVocabulary.labels("UK_eur_2012_1", @xml, [], %{
        @nbsp => %{extent: "E+W+S+NI", start: ~D[2012-12-28]}
      })

    assert Map.keys(labels) == ["art.Article 2"]
    assert Enum.map(labels["art.Article 2"], & &1.territory) == ["E+W+S+NI", "NI"]
  end
end
