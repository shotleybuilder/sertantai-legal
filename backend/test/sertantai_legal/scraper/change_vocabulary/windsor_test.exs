defmodule SertantaiLegal.Scraper.ChangeVocabulary.WindsorTest do
  @moduledoc "C8 from a held Windsor Framework Annex 2 list (Jason 2026-10-30)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence, Windsor}

  defp change(by, date, territory \\ nil),
    do: %Change{
      key: "k",
      target: "art.Article 140",
      resolved: %Evidence.Resolved{
        operation: :repealed,
        level: :provision,
        territory: territory,
        date: date,
        by: by,
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }

  test "REACH and CLP are listed, each with its Annex 2 citation" do
    assert Windsor.listed?("UK_eur_2006_1907")
    assert Windsor.listed?("UK_eur_2008_1272")
    refute Windsor.listed?("UK_eudr_1989_391")
    assert Windsor.annex2()["UK_eur_2008_1272"].citation =~ "Annex 2"
  end

  test "a UK change from IP completion day reaches GB only; the EU's own and earlier changes are untouched" do
    [uk, eu, before] =
      Windsor.confine(
        [
          change("UK_uksi_2019_758", ~D[2020-12-31]),
          change("UK_eur_2020_878", ~D[2021-01-01]),
          change("UK_uksi_2019_758", ~D[2019-01-01])
        ],
        "UK_eur_2006_1907"
      )

    assert uk.resolved.territory == "E+W+S"
    assert eu.resolved.territory == nil
    assert before.resolved.territory == nil
  end

  test "an unlisted law is left as it is" do
    c = change("UK_uksi_2019_758", ~D[2020-12-31])
    assert Windsor.confine([c], "UK_eudr_1989_391") == [c]
  end
end
