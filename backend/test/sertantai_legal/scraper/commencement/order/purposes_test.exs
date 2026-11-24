defmodule SertantaiLegal.Scraper.Commencement.Order.PurposesTest do
  @moduledoc "How far an order's item comes in: fully, for purposes, or with exceptions (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Purposes

  test "partial?/1: a purpose or extent is partial; \"so far as not already in force\" completes" do
    assert Purposes.partial?("so far as it relates to Wales")
    refute Purposes.partial?("so far as it is not already in force")
  end

  test "purposes/1: making secondary legislation" do
    assert Purposes.purposes("for the purpose of making regulations") ==
             :for_making_secondary_legislation
  end

  test "except_subsections/2: the section, but for the subsections excepted" do
    assert is_list(
             Purposes.except_subsections("Section 33 (except subsection (1)(a) and (b))", ["s.33"])
           )

    assert Purposes.except_subsections("Section 33", ["s.33"]) == nil
  end
end
