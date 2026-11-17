defmodule SertantaiLegal.Scraper.ChangeVocabulary.RoundsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.Rounds

  @register [
    "💙 FIRE",
    "💙 FIRE: Dangerous and Explosive Substances",
    "💙 OH&S: Gas & Electrical Safety",
    "💙 OH&S: Mines & Quarries",
    "💙 OH&S: Offshore Safety",
    "💙 OH&S: Occupational / Personal Safety",
    "💚 ENVIRONMENTAL PROTECTION"
  ]

  test "the Fire and OH&S round is its five families, by exact name" do
    assert "Fire and OH&S" in Rounds.names()
    assert Rounds.round?("Fire and OH&S")

    fams = Rounds.families("Fire and OH&S")
    assert length(fams) == 5
    assert "FIRE" in fams and "OH&S: Offshore Safety" in fams
    refute "OH&S: Occupational / Personal Safety" in fams
    refute Enum.any?(fams, &String.contains?(&1, "Occupational"))
  end

  test "the Waste, Water and Climate round is its six families, not EP" do
    fams = Rounds.families("Waste, Water and Climate")
    assert length(fams) == 6
    assert "WASTE" in fams and "NOISE" in fams and "WATER & WASTEWATER" in fams
    refute "ENVIRONMENTAL PROTECTION" in fams
    refute Rounds.switched?("Waste, Water and Climate", ["WASTE"])
  end

  test "a plain family is no round" do
    assert Rounds.families("ENVIRONMENTAL PROTECTION") == nil
    refute Rounds.round?("OH&S")
  end

  describe "Rounds.resolve/2 (a --family name to the families it means)" do
    test "a round is exactly its families" do
      assert Rounds.resolve("Fire and OH&S", @register) ==
               {:ok, Rounds.families("Fire and OH&S")}
    end

    test "an exact name, the marker dropped, is that family alone" do
      assert Rounds.resolve("FIRE", @register) == {:ok, ["FIRE"]}
      assert Rounds.resolve("💙 FIRE", @register) == {:ok, ["FIRE"]}
    end

    test "a name inside exactly one family is that family" do
      assert Rounds.resolve("OH&S: Occupational", @register) ==
               {:ok, ["OH&S: Occupational / Personal Safety"]}
    end

    test "a name inside more than one family is refused, naming them" do
      assert {:error, msg} = Rounds.resolve("OH&S", @register)
      assert msg =~ "4 families"
      assert msg =~ "OH&S: Mines & Quarries"
    end

    test "a name inside no family is refused" do
      assert {:error, msg} = Rounds.resolve("NO SUCH", @register)
      assert msg =~ "no family"
    end
  end

  describe "PatternSource.family_filter/3" do
    test "a round matches its families exactly, the marker dropped" do
      {sql, [names]} = PatternSource.family_filter("r.family", "Fire and OH&S", @register)
      assert sql == "regexp_replace(r.family, '^[^[:alnum:]]+', '') = ANY($1)"
      assert names == Rounds.families("Fire and OH&S")
    end

    test "a plain family matches exactly, never as a substring" do
      assert PatternSource.family_filter("family", "FIRE", @register) ==
               {"regexp_replace(family, '^[^[:alnum:]]+', '') = ANY($1)", [["FIRE"]]}
    end

    test "an ambiguous name raises" do
      assert_raise ArgumentError, ~r/4 families/, fn ->
        PatternSource.family_filter("family", "OH&S", @register)
      end
    end
  end

  # Fire and OH&S: Switch-over (2026-11-17): a round is applied in one run
  test "a --family name is switched when it is a switched family, or a round all of whose families are" do
    round = Rounds.families("Fire and OH&S")
    fams = ["ENVIRONMENTAL PROTECTION" | round]

    assert Rounds.switched?("Fire and OH&S", fams)
    assert Rounds.switched?("💙 OH&S: Offshore Safety", fams)
    assert Rounds.switched?("ENVIRONMENTAL PROTECTION", fams)
    refute Rounds.switched?("Fire and OH&S", ["ENVIRONMENTAL PROTECTION" | tl(round)])
    refute Rounds.switched?("Fire and OH&S", ["ENVIRONMENTAL PROTECTION"])
    refute Rounds.switched?("TRANSPORT: Maritime Safety", fams)
    refute Rounds.switched?("OH&S: Offshore", fams)
  end
end
