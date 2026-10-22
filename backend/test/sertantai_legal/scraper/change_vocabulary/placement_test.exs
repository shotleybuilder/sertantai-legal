defmodule SertantaiLegal.Scraper.ChangeVocabulary.PlacementTest do
  @moduledoc """
  Every feed effect accounted for (CV-S02, agreed 2026-10-22): placed on
  provisions we hold, or unplaced with a reason from a fixed set; our
  faults told apart from known limits and from what the feed itself says.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Placement

  # what we hold of a law: its LAT rows, the provisions in its CLML
  @held %{
    rows: MapSet.new(["reg.1", "reg.3", "reg.3(1)", "s.23[E+W]", "s.23[S]"]),
    clml: MapSet.new(["reg.1", "reg.3", "reg.3(1)", "reg.4", "s.23", "sch.3", "sch.3.para.1"]),
    schedules?: false
  }

  defp effect(text, refs \\ ["x"]), do: %{affected_provisions: text, affected_refs: refs}

  test "placed: a row we hold, or its territorial versions" do
    assert Placement.classify(effect("reg. 3(1)"), ["reg.3(1)"], @held) == :placed
    assert Placement.classify(effect("s. 23"), ["s.23"], @held) == :placed_versions
  end

  test "whole law" do
    assert Placement.classify(effect("Regulations", []), ["*"], @held) == :whole_law
  end

  test "a schedule we don't parse: the known v0.1 limit" do
    assert Placement.classify(effect("Sch. 3 para. 1"), ["sch.3", "sch.3.para.1"], @held) ==
             {:unplaced, :schedule_not_parsed}
  end

  test "the feed names no provision: not a provision (its own words)" do
    assert Placement.classify(effect("specified amended provision(s)", []), ["?"], @held) ==
             {:unplaced, :not_a_provision}
  end

  test "refs given but not converted: our fault" do
    assert Placement.classify(effect("Annex 17", ["annex-XVII"]), ["?"], @held) ==
             {:unplaced, :refs_not_converted}
  end

  test "gone from the current text; in the text but not our rows" do
    assert Placement.classify(effect("reg. 5A"), ["reg.5A"], @held) == {:unplaced, :not_in_text}
    assert Placement.classify(effect("reg. 4"), ["reg.4"], @held) == {:unplaced, :not_in_rows}
  end

  test "which reasons are faults of ours, which known limits, which the feed's own" do
    assert Placement.fault?(:refs_not_converted)
    assert Placement.fault?(:not_in_rows)
    refute Placement.fault?(:schedule_not_parsed)
    refute Placement.fault?(:not_in_text)
    refute Placement.fault?(:not_a_provision)
  end

  test "an EU annex is converted, and unparsed like a schedule: the same known limit (REACH Annex XVII)" do
    alias SertantaiLegal.Scraper.ChangeVocabulary.Ref
    assert Ref.from_clml("annex-XVII", "UK_eur_2006_1907") == "annex.XVII"
    assert Ref.from_clml("annex-I-part-2", "UK_eur_2008_1272") == "annex.I"

    assert Placement.classify(
             effect("Annex 17 Table entry 57", ["annex-XVII"]),
             ["annex.XVII"],
             @held
           ) ==
             {:unplaced, :schedule_not_parsed}
  end
end
