defmodule SertantaiLegal.Scraper.Commencement.Order.BracketsTest do
  @moduledoc "An order item's bracketed asides (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Brackets

  test "bracket_of/1: an item's own qualifier, its last bracket with words" do
    assert Brackets.bracket_of("section 3 (so far as it relates to Wales)") ==
             "so far as it relates to Wales"

    assert Brackets.bracket_of("section 3(1)") == nil
  end

  test "without_qualifiers/1: the item with its worded brackets taken out" do
    assert Brackets.without_qualifiers("section 3 (so far as it relates to Wales)") == "section 3"
    assert Brackets.without_qualifiers("section 3(1)") == "section 3(1)"
  end
end
