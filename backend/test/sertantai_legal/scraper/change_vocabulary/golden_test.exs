defmodule SertantaiLegal.Scraper.ChangeVocabulary.GoldenTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Conflicts, Golden}

  @period %{
    valid_from: ~D[1975-01-01],
    valid_to: nil,
    status: :in_force,
    in_force_from: ~D[1975-01-01],
    changed_by: nil,
    territory: "E+W+S"
  }

  describe "scoring a golden case" do
    test "a label passes when its periods, tiers aside, are the expected ones" do
      c = %{periods: [@period]}
      assert Golden.pass?(c, [Map.put(@period, :tiers, %{status: :primary})])
      refute Golden.pass?(c, [%{@period | territory: "UK"}])
      refute Golden.pass?(c, nil)
      assert Golden.passed([{c, [@period]}, {c, nil}]) == 1
    end

    test "the golden set's cases come from the fixture, each with its law" do
      cases = Golden.cases([])
      assert length(cases) == 27
      assert "UK_uksi_2010_404" in Golden.laws([])
    end
  end

  describe "printing a period" do
    test "line/1 gives its dates, status, start, law and territory" do
      assert Golden.line(@period) == "1975-01-01 → …  in_force  from 1975-01-01  by nil  E+W+S"

      assert Golden.line(Map.put(@period, :commenced_by, ["UK_uksi_1974_1439"])) =~
               "commenced by [\"UK_uksi_1974_1439\"]"
    end

    test "tier_line/1 marks each field primary (P), derived (D) or none" do
      assert Golden.tier_line(nil) == ""

      assert Golden.tier_line(%{status: :primary, territory: :derived, changed_by: nil}) ==
               "changed_by:- status:P territory:D"
    end
  end

  test "Conflicts.counts/2 counts by kind, most first; with detail by sources, sorted" do
    report = [
      %{kind: :value, attribute: :date, primary: {:law_text, nil}, derived: {:feed, nil}},
      %{kind: :value, attribute: :date, primary: {:law_text, nil}, derived: {:markup, nil}},
      %{kind: :uncovered, missing: :derived}
    ]

    assert Conflicts.counts(report) == [{{:value, :date}, 2}, {{:uncovered, :derived}, 1}]

    assert Conflicts.counts(report, detail: true) == [
             {{:uncovered, :derived}, 1},
             {{:value, :date, :law_text, :feed}, 1},
             {{:value, :date, :law_text, :markup}, 1}
           ]
  end

  test "older: the golden laws not built by the current code alone (none stored counts)" do
    versions = %{"A" => ["v2"], "B" => ["v1", "v2"], "C" => ["v1"], "D" => []}

    assert Golden.older(["A", "B", "C", "D", "E"], versions, "v2") == ["B", "C", "D", "E"]
  end
end
