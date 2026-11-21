defmodule SertantaiLegal.Scraper.Commencement.OwnClauseEuAppliesFromTest do
  @moduledoc """
  EU law's own commencing words (LAT Change Pipeline, step Commencement
  reader; Jason 2026-11-21: "The commencement reader works to extract info
  from commencing text"). An EU regulation "shall enter into force" on one
  day and "shall apply from" another: it binds from the day it applies
  (`eu-applies-from-is-the-start`), and "Articles N shall apply from …"
  stages those articles. `LawStart.EuWords` gives the domestic readers EU
  law's words in their form; the entry-into-force sentence stays as written.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.OwnCommencement
  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.EuWords

  defp rows(specs) do
    for {sid, text} <- specs,
        do: %{
          section_id: "UK_eur_2016_879:" <> sid,
          text: EuWords.domestic(text),
          part: nil,
          chapter: nil
        }
  end

  defp read(specs),
    do: OwnClause.read("UK_eur_2016_879", %{type_code: "eur", rows: rows(specs), made: nil})

  defp full_from(specs, id) do
    {outcome, result} =
      OwnCommencement.outcome(
        read(specs).rules,
        "UK_eur_2016_879",
        id,
        OwnClause.context(rows(specs))
      )

    {outcome, result && result.full_from}
  end

  describe "EuWords.domestic/1" do
    test "the day a regulation applies from is its day in force; its entry into force stays as written (EUR 2009/1005 art.31)" do
      out =
        EuWords.domestic(
          "This Regulation shall enter into force on the 20th day following its publication in the Official Journal of the European Union. It shall apply from 1 January 2010."
        )

      assert out =~ "This Regulation shall enter into force on the 20th day"
      assert out =~ "This Regulation shall come into force on 1 January 2010."
    end

    test "articles applying from a day come into force on it (EUR 2016/879 art.5)" do
      out =
        EuWords.domestic(
          "This Regulation shall enter into force on the twentieth day following that of its publication in the Official Journal of the European Union. However, Articles 1 and 2 shall apply from 1 January 2017 and Articles 3 and 4 shall apply from 1 January 2018."
        )

      assert out =~ "Articles 1 and 2 shall come into force on 1 January 2017"
      assert out =~ "Articles 3 and 4 shall come into force on 1 January 2018"
    end

    test "quoted words another law inserts are never this law's (EUR 2008/1272)" do
      s =
        "In Article 10, the following paragraph shall be added: «(10.) Where substances are classified in accordance with Regulation (EC) No 1272/2008 during the period, that classification shall apply from 1 December 2010.»"

      assert EuWords.domestic(s) == s
    end

    test "domestic words and other EU sentences are untouched" do
      s = "These Regulations come into force on 1st April 2020."
      assert EuWords.domestic(s) == s
      assert EuWords.domestic(nil) == nil
    end
  end

  describe "the reading" do
    test "the whole regulation dated by its apply-from day (EUR 2014/517 art.27)" do
      specs = [
        {"art.Article 1", "This Regulation lays down rules."},
        {"art.Article 27",
         "This Regulation shall enter into force on the 20th day following that of its publication in the Official Journal of the European Union. It shall apply from 1 January 2015."}
      ]

      assert full_from(specs, "art.Article 1") == {:dated, ~D[2015-01-01]}
    end

    test "articles staged by apply-from days (EUR 2016/879 art.5)" do
      specs = [
        {"art.Article 1", "Definitions."},
        {"art.Article 3", "Obligations."},
        {"art.Article 5",
         "This Regulation shall enter into force on the twentieth day following that of its publication in the Official Journal of the European Union. However, Articles 1 and 2 shall apply from 1 January 2017 and Articles 3 and 4 shall apply from 1 January 2018."}
      ]

      assert full_from(specs, "art.Article 1") == {:dated, ~D[2017-01-01]}
      assert full_from(specs, "art.Article 3") == {:dated, ~D[2018-01-01]}
      # the entry-into-force article itself, counted from publication
      assert full_from(specs, "art.Article 5") == {:eu_publication_relative, nil}
    end

    test "staged articles, the rest by the whole regulation's day (EUR 2018/2066 art.78)" do
      specs = [
        {"art.Article 1", "This Regulation lays down rules."},
        {"art.Article 76", "Transitional rules."},
        {"art.Article 78",
         "This Regulation shall enter into force on the day following that of its publication in the Official Journal of the European Union. It shall apply from 1 January 2021. However, Article 76 shall apply from 1 January 2019 or the date of entry into force of this Regulation, whichever is the later."}
      ]

      assert full_from(specs, "art.Article 1") == {:dated, ~D[2021-01-01]}
    end
  end
end
