defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.DefaultTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Default

  test "what one sentence states: a default, a list heading, a Part not extending, nothing" do
    assert Default.statement(
             "Subject to the following provisions, this Act extends to England and Wales only."
           ) ==
             {:default, "E+W"}

    assert Default.statement("The following extend also to Scotland— sections 1 to 54;") ==
             {:list, :also, "S"}

    assert Default.statement(
             "Part III, except section 75 and Schedule 7, does not extend to Scotland."
           ) ==
             {:part_not, "S"}

    assert Default.statement(
             "Before exercising the power in relation to an enactment which extends to Scotland, the Secretary of State must consult."
           ) == nil
  end

  test "an Act of the UK Parliament extending to Northern Ireland extends to Great Britain too" do
    assert Default.statement("This Act extends to Northern Ireland.", "ukpga") ==
             {:default, "E+W+S+NI"}

    assert Default.statement("This Act extends to Northern Ireland only.", "ukpga") ==
             {:default, "NI"}

    assert Default.statement("This Order extends to Northern Ireland.", "nisr") ==
             {:default, "NI"}
  end

  test "a clause's default: \"does not extend\" is the rest of the UK" do
    assert Default.default("This Act does not extend to Northern Ireland.") == "E+W+S"
    assert Default.default("Words.") == nil
  end
end
