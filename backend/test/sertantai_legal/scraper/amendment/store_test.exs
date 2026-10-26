defmodule SertantaiLegal.Scraper.Amendment.StoreTest do
  @moduledoc "AR-01: the ruleset's table — a source's rules replaced together, a law's rules read back."
  use SertantaiLegal.DataCase, async: false

  alias SertantaiLegal.Scraper.Amendment.{Rule, Store}

  defp rule(amends, source_law, targets),
    do:
      Rule.new(
        amends: amends,
        targets: targets,
        operation: :inserted,
        level: :provision,
        source: %{law: source_law, ref: "s.4(1)", text: "After section 171 insert—"},
        treatment: :instruction
      )

  test "write/2 replaces a source's rules; for_law/1 reads the rules amending a law" do
    a = rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171A"])
    b = rule("UK_ukpga_1990_8", "UK_ukpga_2004_5", ["s.171B"])

    assert {:ok, 1} = Store.write("UK_ukpga_1991_34", [a])
    assert {:ok, 1} = Store.write("UK_ukpga_2004_5", [b])
    assert MapSet.new(Store.for_law("UK_ukpga_1990_8")) == MapSet.new([a, b])

    # a re-read of a source replaces only its own rules
    a2 = rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171C"])
    assert {:ok, 1} = Store.write("UK_ukpga_1991_34", [a2])
    assert MapSet.new(Store.for_law("UK_ukpga_1990_8")) == MapSet.new([a2, b])
  end

  test "write_changed/3 writes only when the reading differs from the rules stored (run time 2026-10-26)" do
    a = rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171A"])
    assert {:ok, 1, :written} = Store.write_changed("UK_ukpga_1991_34", [a], [])
    stored = Store.for_source("UK_ukpga_1991_34")
    assert {:ok, 1, :unchanged} = Store.write_changed("UK_ukpga_1991_34", [a], stored)

    a2 = rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171C"])
    assert {:ok, 1, :written} = Store.write_changed("UK_ukpga_1991_34", [a2], stored)
    assert Store.for_source("UK_ukpga_1991_34") == [a2]
  end

  test "write/2 refuses a rule from another source" do
    assert_raise ArgumentError, fn ->
      Store.write("UK_ukpga_2004_5", [rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171A"])])
    end
  end

  test "mix lat.amending prints a law's rules grouped by amending law" do
    a = rule("UK_ukpga_1990_8", "UK_ukpga_1991_34", ["s.171A"])

    assert Mix.Tasks.Lat.Amending.print([a], "UK_ukpga_1990_8") == [
             "UK_ukpga_1990_8: 1 rule(s)",
             "",
             "  from UK_ukpga_1991_34",
             "    UK_ukpga_1990_8 s.171A — inserted — instruction — UK_ukpga_1991_34 s.4(1): “After section 171 insert—”"
           ]

    assert Mix.Tasks.Lat.Amending.print([], "UK_x") == [
             "UK_x: no amendment rules (the readers write them: AR-03)"
           ]
  end
end
