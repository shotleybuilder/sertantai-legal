defmodule SertantaiLegal.Scraper.Commencement.FamilyLeftoversTest do
  @moduledoc """
  The family gate (Decision 1 (c), Jason 2026-11-05): a family's
  Commencement reader step passes only when every leftover reaching it sits
  in a group reviewed `known:` — a `fix:` or `check:` group, or a shape
  with no status, fails it (`Leftovers.gate/1`, pure).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Leftovers

  defp item(status, reach \\ 10),
    do:
      Leftovers.item(
        :own,
        "UK_x",
        "UK_x:reg.1",
        "shape #{status}",
        [%{kind: :date, words: "1st May 2000"}],
        reach,
        status
      )

  test "no leftovers: passes" do
    assert %{pass?: true, failing: [], counts: %{}} = Leftovers.gate([])
  end

  test "every leftover in a known group: passes" do
    assert %{pass?: true, failing: []} = Leftovers.gate([item("known: a laid-relative day")])
  end

  test "a fix or check group, or no status: fails, widest reach first" do
    gate =
      Leftovers.gate([
        item("known: x"),
        item("fix: reads nothing", 5),
        item("check: open", 50),
        item(nil, 20)
      ])

    refute gate.pass?
    assert Enum.map(gate.failing, & &1.status) == ["check: open", nil, "fix: reads nothing"]
    assert gate.counts == %{known: 1, fix: 1, check: 1, unreviewed: 1}
  end

  test "a statement named apart from its group: its own status first (a laid-relative day in a group with real misses)" do
    reviewed = %{
      "shape" => "fix: half-read",
      "shape @ UK_uksi_2018_1221:reg.2" => "known: laid-relative (C)"
    }

    assert Leftovers.status("shape", reviewed, "UK_uksi_2018_1221:reg.2") ==
             "known: laid-relative (C)"

    assert Leftovers.status("shape", reviewed, "UK_uksi_2019_145:reg.1(2)") == "fix: half-read"
  end
end
