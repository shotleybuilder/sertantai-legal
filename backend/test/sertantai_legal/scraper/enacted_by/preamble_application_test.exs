defmodule SertantaiLegal.Scraper.EnactedBy.PreambleApplicationTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EnactedBy.PreambleApplication

  test "makers 'as respects' each nation (T&CP (Trees) Regs 1999)" do
    text =
      "The Secretary of State for the Environment, Transport and the Regions, as respects England, and the Secretary of State for Wales, as respects Wales, in exercise of the powers conferred by sections 199(2) … hereby make the following Regulations:"

    assert PreambleApplication.parse(text) == ["E", "W"]
  end

  test "three nations (Waste Management (Miscellaneous Provisions) Regs 1997)" do
    text =
      "The Secretary of State for the Environment as respects England, the Secretary of State for Wales as respects Wales and the Secretary of State for Scotland as respects Scotland, in exercise of the powers conferred on them by section 2(2) …"

    assert PreambleApplication.parse(text) == ["E", "W", "S"]
  end

  test "'in relation to' only counts with a nation directly after it" do
    assert PreambleApplication.parse(
             "The Secretary of State, in relation to England, in exercise of the powers conferred by section 12 …"
           ) == ["E"]

    assert PreambleApplication.parse(
             "The Secretary of State, being the designated Minister for the purpose of section 2(2) of the European Communities Act 1972 in relation to the regulation and control of classification, in exercise of the powers conferred …"
           ) == nil
  end

  test "no territorial phrase in the maker clause: nil; later text is not the maker clause" do
    assert PreambleApplication.parse(
             "The Secretary of State, in exercise of the powers conferred by section 15 …"
           ) == nil

    assert PreambleApplication.parse(
             "The Secretary of State, in exercise of the powers conferred by section 15 of the Act as respects England …"
           ) == nil

    assert PreambleApplication.parse(nil) == nil
  end
end
