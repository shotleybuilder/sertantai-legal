defmodule Mix.Tasks.Lat.CommencementEffectsScopeTest do
  @moduledoc """
  Fire and OH&S: Commencement reader (Decision 5 a). `mix lat.commencement
  --effects --law A,B` reads only those Acts' feeds, from the local store
  alone (never a fetch), and replaces only the feed rules commencing them,
  a law at a time; without `--law` it reads the change register's amending
  Acts (`Commencement.AmendingPicks`) the same way.
  """
  use ExUnit.Case, async: true

  alias Mix.Tasks.Lat.Commencement
  alias SertantaiLegal.Scraper.Commencement.Rule

  defp rule(commences),
    do:
      Rule.new(
        commences: commences,
        scope: ["s.1"],
        when: {:date, ~D[2004-10-01]},
        source: %{law: "UK_uksi_2004_2304", ref: "feed", text: "coming into force"},
        treatment: :feed_commencement
      )

  test "--law names the Acts, reads the store only, and writes a law at a time" do
    assert Commencement.effects_scope(law: "UK_ukpga_2004_21,UK_ukpga_2005_14") ==
             {["UK_ukpga_2004_21", "UK_ukpga_2005_14"], :only, :per_law}
  end

  # (Commencement reader decouple, 2026-11-23: the change register's
  # amending Acts, from the store alone — fetching is the Sources step's —
  # and a law at a time, so an Act left out keeps its rules)
  test "without --law the change register's amending Acts are read, from the store only, a law at a time" do
    assert Commencement.effects_scope([]) == {:amending_acts, :only, :per_law}
  end

  test "a law at a time: one write per law commenced, each scoped to it" do
    a = rule("UK_ukpga_2004_21")
    b = rule("UK_ukpga_2005_14")

    assert Enum.sort(Commencement.effects_writes([a, b, a], :per_law)) == [
             {[commences: "UK_ukpga_2004_21"], [a, a]},
             {[commences: "UK_ukpga_2005_14"], [b]}
           ]
  end

  test "unscoped: the order's rules in one write" do
    assert Commencement.effects_writes([rule("UK_ukpga_2004_21")], []) ==
             [{[], [rule("UK_ukpga_2004_21")]}]
  end

  test "a preview compares a write with the stored rules it replaces: all the order's, or one law's" do
    a = rule("UK_ukpga_2004_21")
    b = rule("UK_ukpga_2005_14")

    assert Commencement.effects_scoped([a, b], []) == [a, b]
    assert Commencement.effects_scoped([a, b], commences: "UK_ukpga_2005_14") == [b]
  end
end
