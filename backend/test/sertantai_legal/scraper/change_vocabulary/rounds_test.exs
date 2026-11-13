defmodule SertantaiLegal.Scraper.ChangeVocabulary.RoundsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.Rounds

  test "the Fire and OH&S round is its five families, by exact name" do
    assert "Fire and OH&S" in Rounds.names()
    assert Rounds.round?("Fire and OH&S")

    fams = Rounds.families("Fire and OH&S")
    assert length(fams) == 5
    assert "FIRE" in fams and "OH&S: Offshore Safety" in fams
    refute "OH&S: Occupational / Personal Safety" in fams
    refute Enum.any?(fams, &String.contains?(&1, "Occupational"))
  end

  test "a plain family is no round" do
    assert Rounds.families("ENVIRONMENTAL PROTECTION") == nil
    refute Rounds.round?("OH&S")
  end

  describe "PatternSource.family_filter/2" do
    test "a round matches its families exactly, the marker dropped" do
      {sql, [names]} = PatternSource.family_filter("r.family", "Fire and OH&S")
      assert sql =~ "regexp_replace(r.family"
      assert sql =~ "= ANY($1)"
      assert names == Rounds.families("Fire and OH&S")
    end

    test "a plain family still matches as a substring" do
      assert PatternSource.family_filter("family", "ENVIRONMENTAL PROTECTION") ==
               {"family LIKE '%' || $1 || '%'", ["ENVIRONMENTAL PROTECTION"]}
    end
  end
end
