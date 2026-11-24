defmodule SertantaiLegal.Scraper.Commencement.Order.HeadTerritoryTest do
  @moduledoc "A statement's own place reaches its items; a table row's is its own (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Territory
  alias SertantaiLegal.Scraper.Commencement.Rule

  defp rule(treatment, text),
    do:
      Rule.new(
        commences: "UK_ukpga_1990_43",
        scope: ["s.1"],
        when: {:date, ~D[1991-04-01]},
        source: %{law: "UK_uksi_1991_1", ref: "art.2", text: text},
        treatment: treatment
      )

  test "head_territory/1: a statement's head place; never a table row's" do
    assert Territory.head_territory(
             rule(:order_date, "Section 1 comes into force in relation to England … section 1")
           ) == "E"

    assert Territory.head_territory(rule(:order_schedule, "in relation to England")) == nil
  end
end
