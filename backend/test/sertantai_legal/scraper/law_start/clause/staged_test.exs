defmodule SertantaiLegal.Scraper.LawStart.Clause.StagedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Clause.Staged

  test "by order" do
    assert Staged.by_order?("on such day as the Secretary of State may by order appoint")
    assert Staged.by_order?("in accordance with regulations made by the Secretary of State.")
    refute Staged.by_order?("on 17th April 1995")
  end

  test "tied to another law's provision, named or through a defined term" do
    assert {"Health and Care Act 2022", "s.162"} =
             Staged.tied_ref(
               "These Regulations come into force immediately after section 162 of the Health and Care Act 2022 comes into force.",
               []
             )

    rows = [
      %{
        section_id: "UK_x:reg.2",
        text:
          "In these Regulations— “the 2022 Act” means the Building Safety Act 2022; “AP” means accountable person;"
      }
    ]

    assert {"Building Safety Act 2022", "s.83"} =
             Staged.tied_ref(
               "These Regulations come into force at the same time as section 83 of the 2022 Act comes into force.",
               rows
             )

    assert Staged.tied_ref(nil, []) == nil
  end

  test "a row's provision" do
    assert Staged.provision("UK_x:reg.1(2)(a)") == "UK_x:reg.1"
  end
end
