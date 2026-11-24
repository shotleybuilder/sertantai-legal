defmodule SertantaiLegal.Scraper.LawStart.Provisions.RefListsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.RefLists

  test "a list of Parts, with ranges in figures or roman numerals" do
    assert RefLists.part_list("1, 3 and 5") == ~w(1 3 5)
    assert RefLists.part_list("1 to 3") == ~w(1 2 3)
    assert RefLists.part_list("II to IV") == ~w(2 3 4)
  end

  test "the same Part, by figure or numeral" do
    assert RefLists.same_part?("2", "II")
    assert RefLists.same_part?("II", "2")
    refute RefLists.same_part?(nil, "2")
  end

  test "words squashed" do
    assert RefLists.squash("  a \n b ") == "a b"
    assert RefLists.squash(nil) == nil
  end
end
