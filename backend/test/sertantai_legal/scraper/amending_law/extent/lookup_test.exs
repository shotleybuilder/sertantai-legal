defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.LookupTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Lookup

  test "lists apply in a fixed order: only sets, also widens, not narrows (HSWA s.84)" do
    e = %Extent{default: "E+W+S", lists: [{:not, "S", ["s.77"]}, {:also, "NI", ["s.77"]}]}
    assert Lookup.of(e, "s.77") == "E+W+NI"
    assert Lookup.of(e, "s.15") == "E+W+S"
  end

  test "a list naming its own extent beats one deferring to the enactment (SI 2013/602)" do
    e = %Extent{default: "E+W", lists: [{:same, nil, ["sch.2"]}, {:only, "S", ["sch.2.para.65"]}]}
    assert Lookup.of(e, "sch.2.para.65") == "S"
    assert Lookup.of(e, "sch.2.para.1") == :same
  end

  test "a Schedule not named extends as its introducing section" do
    e = %Extent{
      default: "E+W",
      lists: [{:also, "S", ["s.111"]}],
      introduced_by: %{"sch.7" => "s.111"}
    }

    assert Lookup.of(e, "sch.7.para.27(2)") == "E+W+S"
  end

  test "stating none: powers, else competence" do
    assert Lookup.of(%Extent{powers: "E+W"}, "reg.1") == "E+W"
    assert Lookup.of(%Extent{competence: "NI"}, "reg.1") == "NI"
    assert Lookup.competence("UK_nisr_2020_1") == "NI"
    assert Lookup.competence("UK_uksi_2020_1") == nil
    assert Lookup.competence_only?(%Extent{competence: "S"})
    refute Lookup.competence_only?(%Extent{default: "S", competence: "S"})
  end

  test "an SI's extent from its enabling powers: the union, or nil when any is unread" do
    parents = %{"UK_ukpga_1974_37" => %Extent{default: "E+W+S"}}

    assert Lookup.from_powers([%{"law" => "UK_ukpga_1974_37", "sections" => ["15"]}], parents) ==
             "E+W+S"

    assert Lookup.from_powers([%{"law" => "UK_ukpga_1990_43", "sections" => ["2"]}], parents) ==
             nil

    assert Lookup.from_powers([], parents) == nil
  end

  test "a change's territory: a repeals schedule follows the provision it corresponds to" do
    e = %Extent{default: "E+W", corresponds: true, lists: [{:same, nil, ["sch.17"]}]}
    assert Lookup.of_change(e, ["sch.7.para.27(2)", "sch.17.pt.2"]) == "E+W"
    assert Lookup.of_change(e, ["sch.17.pt.2"]) == :same
  end
end
