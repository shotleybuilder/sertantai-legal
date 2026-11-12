defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.StepTest do
  @moduledoc """
  Every step's gate re-run after a build (Maritime Safety: Store and
  build): a rebuild can move an earlier step's gate, so the build's check
  passes only when every step's does.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  test "it passes only when every step passes" do
    assert %{pass?: true, failing: []} =
             Step.summary([Step.new("Sources", true), Step.new("Merge", true, 0)])

    assert %{pass?: false, failing: ["Extent reader"]} =
             Step.summary([Step.new("Sources", true), Step.new("Extent reader", false, 4)])
  end

  test "a step that returned no result fails, by its name" do
    assert %{pass?: false, failing: ["Label fold"]} =
             Step.summary([Step.new("Sources", true), {"Label fold", :ok}])
  end

  test "each step prints one line, a failure with its count and the step that owns it" do
    %{lines: lines} =
      Step.summary([
        Step.new("Sources", true),
        Step.new("Amending-law reader", false, 1),
        {"Label fold", nil}
      ])

    assert lines == [
             "PASS  Sources",
             "FAIL  Amending-law reader (1 failing; owned by the Amending-law reader step)",
             "FAIL  Label fold (no gate result returned)"
           ]
  end

  test "a step's close fails on a moved gate, a changed checked row or a stale law, each by who takes it (Tooling: step-close check)" do
    owner = "parked with the step whose change moved them"

    for failed <- [
          Step.new("Extent reader", false, 2),
          Step.new("Checked rows", false, 22, owner: owner),
          Step.new("Stale laws", false, 59, owner: "rebuild (Store and build)")
        ] do
      assert %{pass?: false, failing: [name]} =
               Step.summary([Step.new("Sources", true), failed, Step.new("Merge", true)])

      assert name == failed.step
    end

    %{lines: [line]} = Step.summary([Step.new("Checked rows", false, 22, owner: owner)])
    assert line == "FAIL  Checked rows (22 failing; #{owner})"
  end
end
