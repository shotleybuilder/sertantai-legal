defmodule SertantaiLegal.Scraper.Commencement.Order.SectionHeadsTest do
  @moduledoc "A commencement order's \"in section N—\" heading over its items (SI 2004/2528 art.2(q))."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.SectionHeads

  test "read/1: the heading reads as nothing, the lines under it as its section's subsections" do
    assert SectionHeads.read([
             "section 80 (Crown application)",
             "in section 86 (contaminated land: pollution of controlled waters)",
             "in subsection (2), paragraph (f)",
             "subsection (1) in so far as it relates to that paragraph",
             "section 87 (transfer of discharge consents)"
           ]) == [
             {"section 80 (Crown application)", "section 80 (Crown application)"},
             {"in section 86 (contaminated land: pollution of controlled waters)", ""},
             {"in subsection (2), paragraph (f)", "subsections (2)(f) of section 86 "},
             {"subsection (1) in so far as it relates to that paragraph",
              "subsections (1) of section 86 in so far as it relates to that paragraph"},
             {"section 87 (transfer of discharge consents)",
              "section 87 (transfer of discharge consents)"}
           ]
  end

  test "read/1: an item naming its section on its own line is no heading; a subsection under none stays" do
    lines = ["in section 61, subsection (6)", "subsection (1)"]
    assert SectionHeads.read(lines) == Enum.map(lines, &{&1, &1})
  end
end
