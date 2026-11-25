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

  # a provision tied to another law (RULES
  # `feed-differences-are-patterns-by-feed-coverage`, Decision 2): its
  # provisions, or the whole law
  test "tied_refs/2: the other law and its provisions, or the whole law" do
    assert Staged.tied_refs(
             "Regulation 15 shall come into force on the date on which section 7(3) of the Water Act 2003 comes into force, and all other provisions of these Regulations shall come into force on 1st April 2006.",
             []
           ) == {"Water Act 2003", ["s.7(3)"]}

    assert Staged.tied_refs(
             "Regulations 7(2) and 13(1) come into force immediately after the coming into force of regulations 4 and 17 of the Aviation Safety (Amendment) Regulations 2024.",
             []
           ) == {"Aviation Safety (Amendment) Regulations 2024", ["reg.4", "reg.17"]}

    assert Staged.tied_refs(
             "Regulations 13 and 15, and this regulation, come into force immediately before the coming into force of the Environment and Rural Affairs (Amendment) (EU Exit) Regulations 2019.",
             []
           ) == {"Environment and Rural Affairs (Amendment) (EU Exit) Regulations 2019", []}

    # the law's own provision, a day or an agreement: no other law
    for text <- [
          "Section 3 comes into force at the same time as section 1 comes fully into force in relation to premises in England.",
          "These Regulations come into force immediately before IP completion day.",
          "It shall come into operation on the date on which the Headquarters Agreement enters into force."
        ] do
      assert Staged.tied_refs(text, []) == nil, text
    end
  end

  test "a row's provision" do
    assert Staged.provision("UK_x:reg.1(2)(a)") == "UK_x:reg.1"
  end
end
