defmodule SertantaiLegal.Scraper.ChangeStalenessTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeStaleness

  @inputs %{
    lat_rows: "r1",
    law_text: "t1",
    feed: "f1",
    amendment_rules: "2026-10-30T16:00:01",
    commencement_rules: "2026-10-30T15:48:57",
    extent_rules: nil
  }
  @current %{code_version: "v2", inputs: @inputs}

  defp built(changes \\ []), do: Enum.into(changes, %{code_version: "v2", inputs: @inputs})

  test "a law with no build" do
    assert ChangeStaleness.reasons(nil, @current) == [:no_build]
  end

  test "built by the current code from the current inputs is fresh" do
    assert ChangeStaleness.reasons(built(), @current) == []
  end

  test "built by other code" do
    assert ChangeStaleness.reasons(built(code_version: "v1"), @current) == [:code_version]
  end

  test "each input that moved since the build is a reason, in a fixed order" do
    moved = %{@inputs | feed: "f2", lat_rows: "r2", extent_rules: "2026-10-31T09:00:00"}

    assert ChangeStaleness.reasons(built(inputs: moved), @current) == [
             :lat_rows,
             :feed,
             :extent_rules
           ]
  end

  test "an input the build didn't record counts as moved (built before it was recorded)" do
    old = Map.drop(@inputs, [:lat_rows, :law_text])
    assert ChangeStaleness.reasons(built(inputs: old), @current) == [:lat_rows, :law_text]
  end

  test "an input absent both then and now (nil) hasn't moved" do
    assert ChangeStaleness.reasons(built(), @current) == []
    assert @inputs.extent_rules == nil
  end

  test "the inputs compared" do
    assert ChangeStaleness.inputs() ==
             [:lat_rows, :law_text, :feed, :amendment_rules, :commencement_rules, :extent_rules]

    assert ChangeStaleness.inputs() == SertantaiLegal.Scraper.ChangeVocabulary.Store.Inputs.keys()
  end
end
