defmodule SertantaiLegal.Scraper.Commencement.Order.AppointedForTest do
  @moduledoc "\"The day appointed for the purpose of section N\" (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.AppointedFor
  alias SertantaiLegal.Scraper.Commencement.Rule

  test "resolve_appointed_for/2: dropped where the Act holds no appointed-day rule" do
    r =
      Rule.new(
        commences: "UK_ukpga_1995_45",
        scope: ["appointed_for:s.18(2)"],
        when: {:date, ~D[1996-03-01]},
        source: %{law: "UK_uksi_1996_218", ref: "art.2", text: "x"},
        treatment: :order_date
      )

    assert AppointedFor.resolve_appointed_for([r], []) == []
  end
end
