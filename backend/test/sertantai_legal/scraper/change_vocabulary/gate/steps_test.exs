defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.StepsTest do
  @moduledoc """
  The gate map (Tooling: step-close check): the 14 steps in order, and
  the gates a step closes on, its own and every earlier step's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Steps

  test "the 14 steps, in the pipeline's order" do
    assert Steps.names() == [
             "Making laws",
             "Sources",
             "Feed reader",
             "Markup reader",
             "Commencement reader",
             "Extent reader",
             "Amending-law reader",
             "Merge",
             "Evidence",
             "Label fold",
             "Measures",
             "Store and build",
             "Labels side by side",
             "Switch-over"
           ]
  end

  test "a step closes on its own gate and every earlier step's" do
    assert Steps.through("Making laws") == []
    assert [{"Sources", "lat.sources", []}] = Steps.through("Sources")

    assert Enum.map(Steps.through("Amending-law reader"), &elem(&1, 0)) ==
             ~w(Sources) ++
               ["Feed reader", "Markup reader", "Commencement reader", "Extent reader"] ++
               ["Amending-law reader"]

    assert {"Amending-law reader", "lat.amending_check", ["--gate"]} in Steps.through("Merge")
  end

  test "a step with no gate of its own closes on all the gates before it" do
    assert Steps.through("Switch-over") == Steps.gates()
    assert Steps.through("Measures") == Steps.gates()
    assert length(Steps.gates()) == 9
  end

  test "a name that is no step raises, listing the steps" do
    assert_raise ArgumentError, ~r/no step "Merger".*Sources/, fn -> Steps.through("Merger") end
  end

  test "each gate's check task exists" do
    for {_, task, _} <- Steps.gates(), do: assert(Mix.Task.get(task), "no task #{task}")
  end
end
