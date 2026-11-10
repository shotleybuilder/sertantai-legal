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

  test "a parent Act stating no extent: its enabling provision's stated extent (Decision 2, 2026-11-05)" do
    eca = %{"UK_ukpga_1972_68" => %Extent{}}
    stated = %{{"UK_ukpga_1972_68", "s.2"} => "E+W+S+NI"}
    powers = [%{"law" => "UK_ukpga_1972_68", "sections" => ["2"]}]

    assert Lookup.from_powers(powers, eca, stated) == "E+W+S+NI"
    assert Lookup.from_powers(powers, eca) == nil

    # a parent with a clause keeps it; one not read gets nothing
    msa = %{"UK_ukpga_1972_68" => %Extent{default: "E+W"}}
    assert Lookup.from_powers(powers, msa, stated) == "E+W"
    assert Lookup.from_powers(powers, %{}, stated) == nil

    # a parent with lists but no default: its own words only (an unread
    # statement withholds)
    listed = %{"UK_ukpga_1972_68" => %Extent{lists: [{:unread, nil, ["s.2"]}]}}
    assert Lookup.from_powers(powers, listed, stated) == nil

    # all or nothing still: a provision with neither
    two = powers ++ [%{"law" => "UK_ukpga_1972_68", "sections" => ["3"]}]
    assert Lookup.from_powers(two, eca, stated) == nil
  end

  test "a parent with lists and no default naming the provision nowhere: its stated extent (Environmental Protection, Decision 2, 2026-11-09)" do
    # the Government of Wales Act 2006: lists only, none naming s.150
    gowa = %{
      "UK_ukpga_2006_32" => %Extent{
        lists: [{:same, nil, ["*"]}, {:unread, nil, ["s.36(7)", "s.39"]}]
      }
    }

    stated = %{{"UK_ukpga_2006_32", "s.150"} => "E+W"}
    powers = [%{"law" => "UK_ukpga_2006_32", "sections" => ["150"]}]
    assert Lookup.from_powers(powers, gowa, stated) == "E+W"

    # a list naming it decides (the Finance Act 2001: sch.5 para.15 only NI)
    fa = %{"UK_ukpga_2001_9" => %Extent{lists: [{:only, "NI", ["s.24"]}]}}
    s24 = [%{"law" => "UK_ukpga_2001_9", "sections" => ["24"]}]
    assert Lookup.from_powers(s24, fa, %{{"UK_ukpga_2001_9", "s.24"} => "UK"}) == "NI"

    # an unread statement over the whole Act withholds (Finance Act 1973 s.59(5))
    fa73 = %{"UK_ukpga_1973_51" => %Extent{lists: [{:unread, nil, ["*"]}]}}
    s56 = [%{"law" => "UK_ukpga_1973_51", "sections" => ["56"]}]
    assert Lookup.from_powers(s56, fa73, %{{"UK_ukpga_1973_51", "s.56"} => "E+W+S+NI"}) == nil
  end

  test "a same list naming the provision outranks a whole sentence's unread naming it too (NERC Act 2006 s.108(7): its (a) qualified, its (b) read)" do
    e = %Extent{
      default: "E+W",
      lists: [
        {:same, nil, ["sch.11", "sch.12"]},
        {:unread, nil, ["s.105", "s.108", "sch.11", "sch.12"]}
      ]
    }

    assert Lookup.of(e, "sch.12") == :same
    assert Lookup.of(e, "sch.11.para.140") == :same
    assert Lookup.of(e, "s.105") == nil
  end

  test "an Act stating no clause: its whole-Act stated extent, after powers, before competence (Decision 3)" do
    assert Lookup.of(%Extent{stated: "E+W+S+NI"}, "s.3") == "E+W+S+NI"
    assert Lookup.of(%Extent{powers: "E+W", stated: "E+W+S+NI"}, "s.3") == "E+W"
    refute Lookup.competence_only?(%Extent{stated: "S", competence: "S"})
  end

  test "a change's territory: a repeals schedule follows the provision it corresponds to" do
    e = %Extent{default: "E+W", corresponds: true, lists: [{:same, nil, ["sch.17"]}]}
    assert Lookup.of_change(e, ["sch.7.para.27(2)", "sch.17.pt.2"]) == "E+W"
    assert Lookup.of_change(e, ["sch.17.pt.2"]) == :same
  end

  describe "of_change/3: a change's own target (CV-S05f)" do
    defp target(kind, place, scope, law, refs),
      do: %{kind: kind, place: place, scope: scope, law: law, refs: refs}

    @arbitration %Extent{default: "E+W+NI"}

    test "a law named applies where the change's law has that title" do
      e = %{@arbitration | targets: [target(:only, "E+W", "*", "Arbitration Act 1975", ["*"])]}
      change = %{law: "UK_ukpga_1975_3", title: "Arbitration Act 1975", target: "s.1"}
      assert Lookup.of_change(e, ["sch.4"], change) == "E+W"
      # (another law's change: the provision's bound)
      other = %{law: "UK_ukpga_1950_27", title: "Arbitration Act 1950", target: "s.1"}
      assert Lookup.of_change(e, ["sch.4"], other) == "E+W+NI"
    end

    test "a register title has no year: the law's own year (\"Arbitration Act\", 1975)" do
      e = %{@arbitration | targets: [target(:only, "E+W", "*", "Arbitration Act 1975", ["*"])]}

      assert Lookup.of_change(e, ["sch.4"], %{
               law: "UK_ukpga_1975_3",
               title: "Arbitration Act",
               target: "s.1"
             }) == "E+W"

      assert Lookup.of_change(e, ["sch.4"], %{
               law: "UK_ukpga_1950_27",
               title: "Arbitration Act",
               target: "s.1"
             }) == "E+W+NI"
    end

    test "a title not known: unknown, never a bound the statement may narrow" do
      e = %{@arbitration | targets: [target(:only, "E+W", "*", "Arbitration Act 1975", ["*"])]}

      assert Lookup.of_change(e, ["sch.4"], %{law: "UK_ukpga_1975_3", title: nil, target: "s.1"}) ==
               nil
    end

    test "a title matched as written: \"the\", case and a trailing chapter aside" do
      e = %{@arbitration | targets: [target(:not, "NI", "*", "Arbitration Act 1975", ["*"])]}
      change = %{law: "UK_ukpga_1975_3", title: "The ARBITRATION Act 1975 (c. 3)", target: "s.1"}
      assert Lookup.of_change(e, ["sch.4"], change) == "E+W"
    end

    test "out of scope, or another target: no effect" do
      e = %Extent{
        default: "E+W",
        targets: [target(:also, "S", "sch.7.para.27", nil, ["s.4(8)"])]
      }

      rta = &%{law: "UK_ukpga_1988_52", title: "Road Traffic Act 1988", target: &1}
      assert Lookup.of_change(e, ["sch.7.para.28"], rta.("s.4(8)")) == "E+W"
      assert Lookup.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(8)(a)")) == "E+W+S"
      assert Lookup.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(7)")) == "E+W"
      assert Lookup.of_change(e, ["sch.7.para.27(2)"], nil) == "E+W"
    end

    test "a widening of an unknown bound stays unknown; only and named set it" do
      e = %Extent{
        default: "E+W",
        lists: [{:unread, nil, ["sch.7"]}],
        targets: [
          target(:also, "S", "sch.7.para.27", nil, ["s.4(8)"]),
          target(:only, "S", "sch.7.para.27", nil, ["s.4(9)"])
        ]
      }

      rta = &%{law: "UK_ukpga_1988_52", title: "Road Traffic Act 1988", target: &1}
      assert Lookup.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(8)")) == nil
      assert Lookup.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(9)")) == "S"
    end
  end
end
