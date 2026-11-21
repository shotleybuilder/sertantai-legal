defmodule SertantaiLegal.Scraper.Commencement.OwnClauseHasEffectFromTest do
  @moduledoc """
  A provision's own words stating its start as "has effect from" (LAT
  Change Pipeline, step Commencement reader; the Waste, Water and Climate
  round): "This section has effect in relation to a joint authority from
  the day on which it is established" (Local Government Act 1985 s.84(3))
  starts that section on a day no date states, never with the Act.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause

  @lga_1985 [
    %{section_id: "UK_x:s.84", text: "", part: "IX", chapter: nil},
    %{
      section_id: "UK_x:s.84(1)",
      text:
        "The principal Act shall have effect with the amendments specified in Part I of Schedule 14 to this Act.",
      part: "IX",
      chapter: nil
    },
    %{
      section_id: "UK_x:s.84(3)",
      text:
        "This section has effect in relation to a joint authority from the day on which it is established.",
      part: "IX",
      chapter: nil
    },
    %{section_id: "UK_x:s.85", text: "", part: "IX", chapter: nil}
  ]

  test "\"This section has effect … from the day on which it is established\" is that section's own start, undated" do
    rules =
      OwnClause.rules("UK_x", %{type_code: "ukpga", rows: @lga_1985, made: ~D[1985-07-16]})

    assert [rule] = Enum.filter(rules, &(&1.source.ref == "s.84(3)"))
    assert {rule.scope, rule.when, rule.treatment} == {["s.84"], :unread, :provision_unread}
  end
end
