defmodule SertantaiLegal.Scraper.AmendingLaw.LocatorTest do
  @moduledoc "A pointer's provision ref → the amending law's held element ids (LR-08; CV-06a)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator}

  defp doc(ids),
    do: %Doc{law_name: "UK_uksi_1976_2004", type: "uksi", elements: Map.new(ids, &{&1, nil})}

  test "a numbered Schedule and its paragraph" do
    d = doc(["schedule-3", "schedule-3-paragraph-2"])
    assert Locator.ids(d, {:schedule, "3", nil, nil, []}) == ["schedule-3"]
    assert Locator.ids(d, {:schedule, "3", nil, "2", []}) == ["schedule-3-paragraph-2"]
  end

  test "a law's only Schedule, unnumbered (\"S.I. 1976/2004, Sch.\")" do
    d = doc(["schedule", "schedule-paragraph-8"])
    assert Locator.ids(d, {:schedule, nil, nil, nil, []}) == ["schedule"]
    assert Locator.ids(d, {:schedule, nil, nil, "8", []}) == ["schedule-paragraph-8"]
    assert Locator.ids(doc(["schedule-1"]), {:schedule, nil, nil, nil, []}) == []
  end
end
