defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.StepBugsTest do
  @moduledoc """
  The step report's bugs by owner (Jason 2026-11-19, after Waste, Water and
  Climate: Feed reader): the step session's bugs sorted into fixed here,
  left open here, passed to other steps, and the close's failures that
  belong to other steps (inherited).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.{Step, StepBugs}

  defp bug(category, step, status, affected \\ "1"),
    do: %{"category" => category, "step" => step, "status" => status, "affected" => affected}

  defp bugs do
    [
      bug("affecting-plural-list", "Feed reader", "fixed", "about 430 effects"),
      bug("table-row-target", "Feed reader", "open", "20 effects in 8 laws"),
      bug("range-later-rows", "Markup reader", "open", "3 seen"),
      bug("chapter-id-without-number", "LAT parser", "open"),
      bug("law-identity-two-types", "Feed reader", "moved")
    ]
  end

  test "sorts a step session's bugs by owner" do
    b = StepBugs.buckets(bugs(), "Feed reader", [])

    assert Enum.map(b.fixed, & &1.category) == ["affecting-plural-list", "law-identity-two-types"]
    assert [%{category: "table-row-target", affected: "20 effects in 8 laws"}] = b.left_open

    assert Enum.map(b.passed_on, &{&1.step, &1.category}) == [
             {"LAT parser", "chapter-id-without-number"},
             {"Markup reader", "range-later-rows"}
           ]

    assert b.inherited == []
  end

  test "a failing close check owned by another step is inherited; this step's own is not" do
    results = [
      Step.new("Feed reader", true),
      Step.new("Sources", false, 3),
      Step.new("Stale laws", false, 224, owner: "fix by the reasons above")
    ]

    b = StepBugs.buckets([], "Feed reader", results)
    assert Enum.map(b.inherited, & &1.check) == ["Sources", "Stale laws"]
    assert [%{failing: 3}, %{failing: 224}] = b.inherited

    own = StepBugs.buckets([], "Feed reader", [Step.new("Feed reader", false, 2)])
    assert own.inherited == []
  end

  test "prints one table, every bucket named even when empty" do
    lines = bugs() |> StepBugs.buckets("Feed reader", []) |> StepBugs.lines()

    assert "Bugs by owner:" in lines
    assert Enum.any?(lines, &(&1 =~ ~r/^  This step, fixed \(2\)/))
    assert Enum.any?(lines, &(&1 =~ "table-row-target (20 effects in 8 laws)"))
    assert Enum.any?(lines, &(&1 =~ "Markup reader: range-later-rows"))
    assert Enum.any?(lines, &(&1 =~ ~r/^  Inherited from other steps \(0\): none/))
  end

  test "a session with no bugs block gives empty buckets" do
    b = StepBugs.buckets(nil, "Merge", [])
    assert b.fixed == [] and b.left_open == [] and b.passed_on == []
  end
end
