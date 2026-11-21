defmodule SertantaiLegal.Scraper.Commencement.ReachGroupsTest do
  @moduledoc """
  A catalogue's findings grouped by shape and ranked by reach, held apart
  from what a statement leaves over (the Commencement reader's speed
  fixes: `Leftovers` was two concepts); `Leftovers`' old names delegate
  here for other steps' checks.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, ReachGroups}

  defp found(words), do: Enum.map(words, &%{kind: :date, words: &1})

  test "groups by shape, each law's reach once, up to three examples from different laws, widest first" do
    groups =
      %{}
      |> ReachGroups.add("a", "UK_x", "s.1", found(["1st May"]), 100)
      |> ReachGroups.add("a", "UK_x", "s.2", found(["2nd May"]), 100)
      |> ReachGroups.add("b", "UK_y", "s.1", found(["3rd May"]), 500)
      |> ReachGroups.add("b", "UK_z", "s.1", [], 900)

    assert [{"b", 500, %{count: 1}}, {"a", 100, %{count: 2, examples: [_]}}] =
             ReachGroups.ranked(groups)

    assert ReachGroups.to_json(groups)["a"] |> Map.take(["reach", "count", "laws"]) ==
             %{"reach" => 100, "count" => 2, "laws" => 1}
  end

  test "Leftovers' names are the same functions" do
    groups = ReachGroups.add(%{}, "a", "UK_x", "s.1", found(["1st May"]), 100)
    assert Leftovers.add(%{}, "a", "UK_x", "s.1", found(["1st May"]), 100) == groups
    assert Leftovers.ranked(groups) == ReachGroups.ranked(groups)
  end
end
