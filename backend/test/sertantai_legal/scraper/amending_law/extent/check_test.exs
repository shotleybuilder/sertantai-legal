defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.CheckTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Check

  describe "basis/2: where a law's extent comes from" do
    test "its own default clause first" do
      assert Check.basis(%Extent{default: "E+W"}, "UK_ukpga_1974_37") == {"clause", nil}
    end

    test "with no clause, an Act is no_clause and an SI no_powers" do
      assert Check.basis(%Extent{}, "UK_ukpga_1974_37") == {"none", "no_clause"}
      assert Check.basis(%Extent{}, "UK_uksi_2008_1597") == {"none", "no_powers"}
    end
  end

  test "key/1 names a law row's basis, with why when none" do
    assert Check.key(%{basis: "none", why: "not_held"}) == "none: not_held"
    assert Check.key(%{basis: "clause"}) == "clause"
  end

  test "unread_law/2 is a law with no basis, no fault and nothing unread" do
    assert %{basis: "none", why: "type_not_read", fault: nil, unread: %{}, uncaught: []} =
             Check.unread_law("UK_eur_2006_1907", "type_not_read")
  end

  describe "change_row/2: where a text change's territory comes from" do
    test "the law's own territory before its extent, then the feed, then the markup" do
      change = fn claims -> %{claims: claims, by: "X", affecting: []} end

      assert Check.change_row(change.(["feed:territory=E", "law_text:territory=GB"]), %{}).outcome ==
               "territory:law"

      assert Check.change_row(change.(["law_text:extent=E+W"]), %{}).outcome == "bound:law"
      assert Check.change_row(change.(["markup:territory=E"]), %{}).outcome == "territory:markup"
    end

    test "with no claim, why from the amending law's row" do
      c = %{claims: [], by: "X", affecting: []}
      assert Check.change_row(%{c | by: nil}, %{}).outcome == "none:no_amending_law"
      assert Check.change_row(c, %{}).outcome == "none:no_amending_law"

      assert Check.change_row(c, %{"X" => %{basis: "none", why: "not_held"}}).outcome ==
               "none:law_not_held"

      assert Check.change_row(c, %{"X" => %{basis: "competence"}}).outcome ==
               "none:competence_only"
    end
  end

  describe "change_row/2: an unread statement withholds only what it covers (2026-11-05)" do
    @c %{claims: [], by: "X", affecting: ["sch.1.para.37"]}

    test "a statement on another provision leaves the law's own cause: an SI with no powers read (SI 2009/1941)" do
      e = %Extent{lists: [{:unread, nil, ["sch.1.para.84"]}]}
      row = %{basis: "lists", extent: e, law: "UK_uksi_2009_1941"}
      assert Check.change_row(@c, %{"X" => row}).outcome == "none:law_no_powers"
    end

    test "a statement on the change's own provision withholds it" do
      e = %Extent{default: "E+W", lists: [{:unread, nil, ["sch.1"]}]}
      row = %{basis: "clause", extent: e, law: "UK_ukpga_2000_1"}
      assert Check.change_row(@c, %{"X" => row}).outcome == "none:unread_statement"
    end

    test "with no amending provision known, any unread statement may withhold it" do
      e = %Extent{default: "E+W", lists: [{:unread, nil, ["s.9"]}]}
      row = %{basis: "clause", extent: e, law: "UK_ukpga_2000_1"}

      assert Check.change_row(%{@c | affecting: []}, %{"X" => row}).outcome ==
               "none:unread_statement"
    end
  end

  test "tallies/2 counts bases, faults and the text changes' outcomes" do
    rows = [
      %{law: "A", basis: "clause", fault: nil, unread: %{"unread:list" => 2}, uncaught: []},
      %{law: "B", basis: "none", why: "not_held", fault: "stale", unread: %{}, uncaught: []}
    ]

    t = Check.tallies(rows, [%{outcome: "territory:law"}, %{outcome: "territory:law"}])
    assert {"clause", 1} in t.bases
    assert [%{law: "B"}] = t.faults
    assert t.fault_kinds == %{"stale" => 1}
    assert t.unread == [{"unread:list", 2}]
    assert t.with_unread == 1
    assert t.outcomes == [{"territory:law", 2}]
  end
end
